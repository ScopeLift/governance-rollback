// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {TimelockMultiAdminShim} from "./TimelockMultiAdminShim.sol";

/// @title CouncilExecutor
/// @author [ScopeLift](https://scopelift.co)
/// @notice Executor for the Council Veto Governor that bridges OZ Governor and Compound Timelock interfaces.
/// @dev This contract extends OpenZeppelin's TimelockController to provide an OZ-compatible interface
///      for the Council Veto Governor, while forwarding all actual timelock operations to the
///      TimelockMultiAdminShim, which in turn wraps the Compound Timelock (ICompoundTimelock).
///
///      Architecture flow:
///      - Council Veto Governor → (OZ TimelockController interface) → CouncilExecutor
///      - CouncilExecutor → (translates OZ operations to Compound format) → TimelockMultiAdminShim
///      - TimelockMultiAdminShim → (forwards to) → Compound Timelock (ICompoundTimelock)
///
///      This allows the veto governor to use OpenZeppelin's standard governor-timelock integration
///      while ultimately queuing and executing transactions on the existing Compound Timelock.
contract CouncilExecutor is TimelockController {
  /*///////////////////////////////////////////////////////////////
                            Errors
  //////////////////////////////////////////////////////////////*/

  error CouncilExecutor__OnlyCouncilVetoGovernor();

  error CouncilExecutor__AlreadyScheduled();

  error CouncilExecutor__TransactionAlreadyQueued();

  error CouncilExecutor__DelayMismatch();

  error CouncilExecutor__OperationNotScheduled();

  error CouncilExecutor__TransactionNotReady();

  error CouncilExecutor__TransactionExpired();

  error CouncilExecutor__InsufficientValue();

  error CouncilExecutor__TransactionAlreadyExecuted();

  /*///////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The address of the Council Veto Governor.
  /// TODO: Discuss if we should evaluate multiple council veto governors.
  address public immutable COUNCIL_VETO_GOVERNOR;

  /// @notice The address of the TimelockMultiAdminShim.
  TimelockMultiAdminShim public immutable SHIM;

  /// @notice Maps OZ operation ID to array of Compound transaction hashes
  mapping(bytes32 operationId => bytes32[] txHashes) private ozOperationTxHashes;

  /// @notice Maps OZ operation ID to ETA timestamp (all transactions in batch share same ETA)
  mapping(bytes32 operationId => uint256 eta) private ozOperationEta;

  /// @notice Maps Compound transaction hash to executed status
  mapping(bytes32 txHash => bool executed) private compoundTxExecuted;

  /*///////////////////////////////////////////////////////////////
                            Modifiers
  //////////////////////////////////////////////////////////////*/

  modifier onlyCouncilVetoGovernor() {
    if (msg.sender != COUNCIL_VETO_GOVERNOR) {
      revert CouncilExecutor__OnlyCouncilVetoGovernor();
    }
    _;
  }

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  constructor(address _councilVetoGovernor, TimelockMultiAdminShim _shim)
    TimelockController(0, new address[](0), new address[](0), address(0))
  {
    COUNCIL_VETO_GOVERNOR = _councilVetoGovernor;
    SHIM = _shim;
  }

  /*///////////////////////////////////////////////////////////////
                        TimelockController Overrides
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the minimum delay from the shim.
  /// @dev Overrides TimelockController to return shim's delay instead of internal _minDelay.
  function getMinDelay() public view virtual override returns (uint256) {
    return SHIM.delay();
  }

  /// @notice Schedules a batch of operations to be executed.
  /// @dev Overrides TimelockController to schedule Compound timelock transactions.
  /// @param _targets Array of target addresses for the operations.
  /// @param _values Array of ETH values for each operation.
  /// @param _payloads Array of calldata for each operation.
  /// @param _salt Salt for operation ID computation.
  function scheduleBatch(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _payloads,
    bytes32 /*_predecessor*/,
    bytes32 _salt,
    uint256 /*_delay*/
  ) public virtual override onlyCouncilVetoGovernor {
    // Validate lengths
    if (_targets.length != _values.length || _targets.length != _payloads.length) {
      revert TimelockInvalidOperationLength(_targets.length, _payloads.length, _values.length);
    }

    _scheduleBatch(_targets, _values, _payloads, _salt);
  }

  /// @notice Executes a batch of operations that have been queued.
  /// @dev Overrides TimelockController to forward to TimelockMultiAdminShim.
  /// @param _targets Array of target addresses for the operations.
  /// @param _values Array of ETH values for each operation.
  /// @param _payloads Array of calldata for each operation.
  /// @param _salt Salt for operation ID computation.
  function executeBatch(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _payloads,
    bytes32 /*_predecessor*/,
    bytes32 _salt
  ) public payable virtual override onlyCouncilVetoGovernor {
    // Validate lengths
    if (_targets.length != _values.length || _targets.length != _payloads.length) {
      revert TimelockInvalidOperationLength(_targets.length, _payloads.length, _values.length);
    }

    _executeBatch(_targets, _values, _payloads, _salt);
  }

  /*///////////////////////////////////////////////////////////////
                Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Internal helper to schedule batch and avoid stack too deep
  function _scheduleBatch(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _payloads,
    bytes32 _salt
  ) internal {
    // Compute operation ID (same as TimelockController)
    bytes32 _operationId = hashOperationBatch(_targets, _values, _payloads, bytes32(0), _salt);

    // Check if operation already scheduled
    if (ozOperationTxHashes[_operationId].length > 0) {
      revert CouncilExecutor__AlreadyScheduled();
    }

    // Compute and store ETA (all transactions in batch share same ETA)
    uint256 _eta = block.timestamp + SHIM.delay();
    ozOperationEta[_operationId] = _eta;

    // Process each transaction in the batch
    bytes32[] storage compoundTxHashes = ozOperationTxHashes[_operationId];

    for (uint256 _i = 0; _i < _targets.length; ++_i) {
      // Extract function selector from payload (first 4 bytes)
      bytes4 _selector = bytes4(_payloads[_i]);

      _checkAccess(_targets[_i], _selector);

      // Compute Compound timelock transaction hash
      // Compound uses: keccak256(abi.encode(target, value, signature, data, eta))
      // where signature is empty string ""
      bytes32 _compoundTxHash = keccak256(abi.encode(_targets[_i], _values[_i], "", _payloads[_i], _eta));

      // Check if transaction already queued on shim
      if (SHIM.queuedTransactions(_compoundTxHash)) {
        revert CouncilExecutor__TransactionAlreadyQueued();
      }

      // Queue transaction via shim
      SHIM.queueTransaction(_targets[_i], _values[_i], "", _payloads[_i], _eta);

      // Track transaction
      compoundTxHashes.push(_compoundTxHash);
    }
  }

  /// @notice Internal helper to execute batch and avoid stack too deep
  function _executeBatch(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _payloads,
    bytes32 _salt
  ) internal {
    // Compute operation ID
    bytes32 _operationId = hashOperationBatch(_targets, _values, _payloads, bytes32(0), _salt);

    // Get stored transaction hashes and ETA
    bytes32[] memory _compoundTxHashes = ozOperationTxHashes[_operationId];
    uint256 _eta = ozOperationEta[_operationId];

    if (_eta == 0 || _compoundTxHashes.length == 0) {
      revert CouncilExecutor__OperationNotScheduled();
    }

    // Validate operation is ready
    if (block.timestamp < _eta) {
      revert CouncilExecutor__TransactionNotReady();
    }

    // Validate operation not expired
    if (block.timestamp > _eta + SHIM.GRACE_PERIOD()) {
      revert CouncilExecutor__TransactionExpired();
    }

    // Calculate total ETH value needed
    uint256 _totalValue = 0;
    for (uint256 _i = 0; _i < _values.length; ++_i) {
      _totalValue += _values[_i];
    }

    // Validate sufficient ETH sent
    if (msg.value < _totalValue) {
      revert CouncilExecutor__InsufficientValue();
    }

    // Execute each transaction
    _executeTransactions(_targets, _values, _payloads, _compoundTxHashes, _eta, _operationId);

    // Refund excess ETH
    if (msg.value > _totalValue) {
      payable(msg.sender).transfer(msg.value - _totalValue);
    }
  }

  /// @notice Internal helper to execute individual transactions
  function _executeTransactions(
    address[] calldata _targets,
    uint256[] calldata _values,
    bytes[] calldata _payloads,
    bytes32[] memory _compoundTxHashes,
    uint256 _eta,
    bytes32 _operationId
  ) internal {
    for (uint256 _i = 0; _i < _targets.length; ++_i) {
      bytes32 _compoundTxHash = _compoundTxHashes[_i];

      // Check if already executed
      if (compoundTxExecuted[_compoundTxHash]) {
        revert CouncilExecutor__TransactionAlreadyExecuted();
      }

      _checkAccess(_targets[_i], bytes4(_payloads[_i]));

      // Execute via shim (send only the value for this transaction)
      SHIM.executeTransaction{value: _values[_i]}(_targets[_i], _values[_i], "", _payloads[_i], _eta);

      // Mark as executed
      compoundTxExecuted[_compoundTxHash] = true;

      // Emit event (matching TimelockController interface)
      emit CallExecuted(_operationId, _i, _targets[_i], _values[_i], _payloads[_i]);
    }
  }

  function _checkAccess(address _target, bytes4 _selector) internal view {
    // TODO: Implement access control check here
  }
}
