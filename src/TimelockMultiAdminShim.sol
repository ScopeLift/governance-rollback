// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Internal Imports
import {ITimelockMultiAdminShim} from "interfaces/ITimelockMultiAdminShim.sol";

/// @title TimelockMultiAdminShim
/// @author [ScopeLift](https://scopelift.co)
/// @notice A shim contract that wraps a Compound Timelock and adds support for multiple executors and a mutable admin.
/// @dev Security Model:
///      - Only the admin can queue transactions targeting this shim contract (e.g., configuration changes).
///      - The admin and any authorized executor can queue transactions targeting external contracts.
/// @custom:security-contact https://immunefi.com/bug-bounty/compoundfinance/information/
contract TimelockMultiAdminShim is ITimelockMultiAdminShim, ReentrancyGuard {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when an unauthorized caller attempts perform an action.
  error TimelockMultiAdminShim__Unauthorized();

  /// @notice Thrown when an invalid admin address is provided.
  error TimelockMultiAdminShim__InvalidAdmin();

  /// @notice Thrown when an invalid timelock address is provided.
  error TimelockMultiAdminShim__InvalidTimelock();

  /// @notice Thrown when an invalid executor address is provided.
  error TimelockMultiAdminShim__InvalidExecutor();

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a new executor is added.
  /// @param executor The address of the new executor.
  event ExecutorAdded(address indexed executor);

  /// @notice Emitted when an executor is removed.
  /// @param executor The address of the removed executor.
  event ExecutorRemoved(address indexed executor);

  /// @notice Emitted when a new admin is set.
  /// @param previousAdmin The address of the previous admin.
  /// @param newAdmin The address of the new admin.
  event AdminSet(address indexed previousAdmin, address indexed newAdmin);

  /// @notice Emitted when the timelock is updated.
  /// @param timelock The address of the timelock.
  event TimelockSet(address indexed timelock);

  /*///////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The timelock contract.
  ICompoundTimelock public immutable TIMELOCK;

  /// @notice The address of the admin.
  address public admin;

  /// @notice Tracks which addresses are authorized to execute queue and execute transactions.
  mapping(address executor => bool isAuthorized) public isExecutor;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructor for the TimelockMultiAdminShim contract.
  /// @param _admin The address of the Admin contract.
  /// @param _timelock The address of the Compound Timelock contract.
  /// @param _executors The initial list of addresses that will be whitelisted as executors immediately upon deployment.
  constructor(address _admin, ICompoundTimelock _timelock, address[] memory _executors) {
    if (address(_timelock) == address(0)) {
      revert TimelockMultiAdminShim__InvalidTimelock();
    }
    TIMELOCK = _timelock;
    emit TimelockSet(address(_timelock));

    _setAdmin(_admin);

    for (uint256 _i = 0; _i < _executors.length; _i++) {
      _addExecutor(_executors[_i]);
    }
  }

  /*///////////////////////////////////////////////////////////////
                      External Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ITimelockMultiAdminShim
  function addExecutor(address _newExecutor) external {
    _revertIfNotTimelock();
    _addExecutor(_newExecutor);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function removeExecutor(address _executor) external {
    _revertIfNotTimelock();
    _revertIfInvalidExecutor(_executor);
    isExecutor[_executor] = false;
    emit ExecutorRemoved(_executor);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function setAdmin(address _newAdmin) external {
    _revertIfNotTimelock();
    _setAdmin(_newAdmin);
  }

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ITimelockMultiAdminShim
  function GRACE_PERIOD() external view returns (uint256) {
    return TIMELOCK.GRACE_PERIOD();
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function MINIMUM_DELAY() external view returns (uint256) {
    return TIMELOCK.MINIMUM_DELAY();
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function MAXIMUM_DELAY() external view returns (uint256) {
    return TIMELOCK.MAXIMUM_DELAY();
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function queueTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta)
    public
    nonReentrant
    returns (bytes32)
  {
    _revertIfCannotModifyShim(_target);
    return TIMELOCK.queueTransaction(_target, _value, _signature, _data, _eta);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function cancelTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) public nonReentrant {
    _revertIfCannotModifyShim(_target);
    TIMELOCK.cancelTransaction(_target, _value, _signature, _data, _eta);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) public payable nonReentrant returns (bytes memory) {
    _revertIfNotAdminOrExecutor();
    return TIMELOCK.executeTransaction{value: msg.value}(_target, _value, _signature, _data, _eta);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function delay() external view returns (uint256) {
    return TIMELOCK.delay();
  }

  /// @notice Returns whether a transaction is queued on the timelock.
  /// @param _txHash The hash of the transaction.
  /// @return Whether the transaction is queued on the timelock.
  function queuedTransactions(bytes32 _txHash) external view returns (bool) {
    return TIMELOCK.queuedTransactions(_txHash);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function acceptAdmin() external {
    TIMELOCK.acceptAdmin();
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Validates authorization for modifying transactions targeting this shim.
  /// @param _target The address of the contract that the function call targets.
  /// @dev Reverts with TimelockMultiAdminShim__Unauthorized if:
  ///      - The target is this contract and the caller is not the admin.
  ///      - The target is an external contract and the caller is not the admin or an authorized executor.
  function _revertIfCannotModifyShim(address _target) internal view {
    if (_target == address(this)) {
      _revertIfNotAdmin();
    }
    _revertIfNotAdminOrExecutor();
  }

  /// @notice Reverts if the caller is not the admin or an executor.
  function _revertIfNotAdminOrExecutor() internal view {
    if (msg.sender != admin && !isExecutor[msg.sender]) {
      revert TimelockMultiAdminShim__Unauthorized();
    }
  }

  /// @notice Reverts if the caller is not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) {
      revert TimelockMultiAdminShim__Unauthorized();
    }
  }

  /// @notice Reverts if the caller is not the timelock.
  function _revertIfNotTimelock() internal view {
    if (msg.sender != address(TIMELOCK)) {
      revert TimelockMultiAdminShim__Unauthorized();
    }
  }

  /// @notice Reverts if the executor is invalid.
  /// @param _executor The address of the executor.
  function _revertIfInvalidExecutor(address _executor) internal pure {
    if (_executor == address(0)) {
      revert TimelockMultiAdminShim__InvalidExecutor();
    }
  }

  /// @notice Utility function to set the admin.
  /// @param _newAdmin The new admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) {
      revert TimelockMultiAdminShim__InvalidAdmin();
    }

    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Utility function to add an executor.
  /// @param _newExecutor The address of the new executor.
  function _addExecutor(address _newExecutor) internal {
    _revertIfInvalidExecutor(_newExecutor);
    isExecutor[_newExecutor] = true;
    emit ExecutorAdded(_newExecutor);
  }

  /// @notice Receive function to accept native transfers from the Governor
  /// @dev This is required because the Governor sends native to the timelock when executing proposals
  ///      via Address.sendValue(payable($._timelock), msg.value). Without this receive function, such
  ///      transfers would revert, preventing proposal execution.
  receive() external payable {}
}
