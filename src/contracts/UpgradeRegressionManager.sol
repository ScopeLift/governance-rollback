// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Libraries
import {ITimelockTarget} from "interfaces/ITimelockTarget.sol";
import {IUpgradeRegressionManager} from "interfaces/IUpgradeRegressionManager.sol";

/// @title Upgrade Regression Manager
/// @author [ScopeLift](https://scopelift.co)
/// @notice Manages the lifecycle of rollback proposals, allowing the admin to propose, and the guardian to queue,
/// cancel, or execute rollback transactions.
/// @dev This contract coordinates a multi-phase rollback process:
///      - Admin proposes rollback transactions.
///      - Guardian queues them for execution within a specified window
///      - Guardian later executes or cancels the queued rollback.
///      - On queuing / cancelling / executing, the transactions are sent to TimelockTarget.
contract UpgradeRegressionManager is IUpgradeRegressionManager {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when an unauthorized caller attempts perform an action.
  error UpgradeRegressionManager__Unauthorized();

  /// @notice Thrown when an invalid address is provided.
  error UpgradeRegressionManager__InvalidAddress();

  /// @notice Thrown when an invalid rollback queue window is provided.
  error UpgradeRegressionManager__InvalidRollbackQueueWindow();

  /// @notice Thrown when the lengths of the parameters do not match.
  error UpgradeRegressionManager__MismatchedParameters();

  /// @notice Thrown when a rollback is not proposed or already queued.
  error UpgradeRegressionManager__NotQueueable(uint256 rollbackId);

  /// @notice Thrown when a rollback is not queued for execution.
  error UpgradeRegressionManager__NotQueued(uint256 rollbackId);

  /// @notice Thrown when a rollback queue has expired.
  error UpgradeRegressionManager__Expired(uint256 rollbackId);

  /// @notice Thrown when a rollback's execution time has not yet arrived.
  error UpgradeRegressionManager__ExecutionTooEarly(uint256 rollbackId);

  /// @notice Thrown when a rollback already exists.
  error UpgradeRegressionManager__AlreadyExists(uint256 rollbackId);

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a rollback is proposed.
  /// @param rollbackId The ID of the rollback.
  /// @param expiresAt Timestamp before which the rollback must be queued for execution.
  /// @param targets The targets of the transactions.
  /// @param values The values of the transactions.
  /// @param calldatas The calldatas of the transactions.
  /// @param description The description of the rollback.
  event RollbackProposed(
    uint256 indexed rollbackId,
    uint256 expiresAt,
    address[] targets,
    uint256[] values,
    bytes[] calldatas,
    string description
  );

  /// @notice Emitted when a rollback is queued.
  /// @param rollbackId The ID of the rollback.
  /// @param eta Timestamp after which the rollback can be executed.
  event RollbackQueued(uint256 indexed rollbackId, uint256 eta);

  /// @notice Emitted when a rollback is canceled.
  /// @param rollbackId The ID of the rollback.
  event RollbackCanceled(uint256 indexed rollbackId);

  /// @notice Emitted when a rollback is executed.
  /// @param rollbackId The ID of the rollback.
  event RollbackExecuted(uint256 indexed rollbackId);

  /// @notice Emitted when a new guardian is set.
  /// @param oldGuardian The old guardian.
  /// @param newGuardian The new guardian.
  event GuardianSet(address indexed oldGuardian, address indexed newGuardian);

  /// @notice Emitted when the rollback queue window is set.
  /// @param oldRollbackQueueWindow The old rollback queue window.
  /// @param newRollbackQueueWindow The new rollback queue window.
  event RollbackQueueWindowSet(uint256 oldRollbackQueueWindow, uint256 newRollbackQueueWindow);

  /// @notice Emitted when the admin is set.
  /// @param oldAdmin The old admin.
  /// @param newAdmin The new admin.
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Target for timelocked execution of rollback transactions.
  ITimelockTarget public immutable TARGET;

  /// @notice Address that manages this contract.
  address public admin;

  /// @notice Address that can execute rollback transactions.
  address public guardian;

  /// @notice Time window after a rollback is proposed during which it can be queued for execution.
  uint256 public rollbackQueueWindow;

  /// @notice Timestamp after which rollback queueing is no longer allowed.
  mapping(uint256 rollbackId => uint256 deadline) public rollbackQueueExpiresAt;

  /// @notice Time after which the rollback can be executed.
  mapping(uint256 rollbackId => uint256 eta) public rollbackExecutableAt;

  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the UpgradeRegressionManager.
  /// @param _target The target for timelocked execution of rollback transactions.
  /// @param _admin The address that manages this contract.
  /// @param _guardian The address that can execute rollback transactions.
  /// @param _rollbackQueueWindow The time window after a rollback is proposed during which it can be queued for
  /// execution.
  constructor(ITimelockTarget _target, address _admin, address _guardian, uint256 _rollbackQueueWindow) {
    if (address(_target) == address(0)) {
      revert UpgradeRegressionManager__InvalidAddress();
    }

    TARGET = _target;

    _setAdmin(_admin);
    _setRollbackQueueWindow(_rollbackQueueWindow);
    _setGuardian(_guardian);
  }

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Checks if a rollback is eligible to be queued.
  /// @param _rollbackId The ID of the rollback.
  /// @return True if the rollback is ready to be queued, false otherwise.
  function isRollbackEligibleToQueue(uint256 _rollbackId) external view returns (bool) {
    return rollbackQueueExpiresAt[_rollbackId] != 0 && block.timestamp < rollbackQueueExpiresAt[_rollbackId];
  }

  /// @notice Checks if a rollback is ready to be executed.
  /// @param _rollbackId The ID of the rollback.
  /// @return True if the rollback is ready to be executed, false otherwise.
  function isRollbackReadyToExecute(uint256 _rollbackId) external view returns (bool) {
    return rollbackExecutableAt[_rollbackId] != 0 && block.timestamp >= rollbackExecutableAt[_rollbackId];
  }

  /// @notice Proposes a rollback which can be queued for execution.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the admin.
  ///      Proposes a rollback by submitting the target transactions and their metadata.
  ///      Does not queue or execute the rollback — it simply stages it for guardian review.
  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId) {
    _revertIfNotAdmin();
    _revertIfMismatchedParameters(_targets, _values, _calldatas);

    _rollbackId = getRollbackId(_targets, _values, _calldatas, _description);

    // Revert if the rollback already exists.
    if (rollbackQueueExpiresAt[_rollbackId] != 0 || rollbackExecutableAt[_rollbackId] != 0) {
      revert UpgradeRegressionManager__AlreadyExists(_rollbackId);
    }

    // Set the time before which the rollback can be queued for execution.
    uint256 _expiresAt = block.timestamp + rollbackQueueWindow;
    rollbackQueueExpiresAt[_rollbackId] = _expiresAt;

    emit RollbackProposed(_rollbackId, _expiresAt, _targets, _values, _calldatas, _description);
  }

  /// @notice Queues a rollback for execution.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the guardian.
  ///      Must be called before the rollback queue window expires (`rollbackQueueExpiresAt`).
  ///      Queues the rollback transactions to enable optional execution during the allowed window.
  function queue(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId) {
    _revertIfNotGuardian();
    _revertIfMismatchedParameters(_targets, _values, _calldatas);

    _rollbackId = getRollbackId(_targets, _values, _calldatas, _description);

    // Revert if the rollback not proposed or already queued.
    if (rollbackQueueExpiresAt[_rollbackId] == 0) {
      revert UpgradeRegressionManager__NotQueueable(_rollbackId);
    }

    // Revert if the rollback queue has expired.
    if (block.timestamp >= rollbackQueueExpiresAt[_rollbackId]) {
      revert UpgradeRegressionManager__Expired(_rollbackId);
    }

    // Set the time after which the queued rollback can be executed.
    uint256 _eta = block.timestamp + TARGET.delay();
    rollbackExecutableAt[_rollbackId] = _eta;

    // Remove the rollback from the waiting queue since it has now been queued for execution.
    delete rollbackQueueExpiresAt[_rollbackId];

    // Queue the rollback transactions.
    for (uint256 _i = 0; _i < _targets.length; _i++) {
      TARGET.queueTransaction(_targets[_i], _values[_i], "", _calldatas[_i], 0);
    }

    emit RollbackQueued(_rollbackId, _eta);
  }

  /// @notice Cancels a previously queued rollback operation.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the guardian.
  ///      Removes the rollback record, making it no longer executable.
  ///      Intended for cases where a previously queued rollback is determined to be unnecessary or invalid.
  function cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId) {
    _revertIfNotGuardian();
    _revertIfMismatchedParameters(_targets, _values, _calldatas);

    _rollbackId = getRollbackId(_targets, _values, _calldatas, _description);

    // Revert if the rollback is not queued for execution.
    if (rollbackExecutableAt[_rollbackId] == 0) {
      revert UpgradeRegressionManager__NotQueued(_rollbackId);
    }

    // Remove the rollback from execution queue
    delete rollbackExecutableAt[_rollbackId];

    // Cancel the rollback transactions.
    for (uint256 _i = 0; _i < _targets.length; _i++) {
      TARGET.cancelTransaction(_targets[_i], _values[_i], "", _calldatas[_i], 0);
    }

    emit RollbackCanceled(_rollbackId);
  }

  ///  @notice Executes a previously queued rollback by the guardian, forwarding the call to each target contract.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the guardian.
  ///      Executes the queued rollback transactions after the execution window has begun (`rollbackExecutableAt`).
  ///      Each transaction is forwarded to its target contract and executed sequentially.
  function execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId) {
    _revertIfNotGuardian();
    _revertIfMismatchedParameters(_targets, _values, _calldatas);

    _rollbackId = getRollbackId(_targets, _values, _calldatas, _description);

    if (rollbackExecutableAt[_rollbackId] == 0) {
      revert UpgradeRegressionManager__NotQueued(_rollbackId);
    }

    if (block.timestamp < rollbackExecutableAt[_rollbackId]) {
      revert UpgradeRegressionManager__ExecutionTooEarly(_rollbackId);
    }

    // Remove the rollback from the execution queue.
    delete rollbackExecutableAt[_rollbackId];

    // Execute the rollback.
    for (uint256 _i = 0; _i < _targets.length; _i++) {
      TARGET.executeTransaction(_targets[_i], _values[_i], "", _calldatas[_i], 0);
    }

    emit RollbackExecuted(_rollbackId);
  }

  /// @notice Sets the guardian.
  /// @param _newGuardian The new guardian.
  /// @dev Can only be called by the admin.
  function setGuardian(address _newGuardian) external {
    _revertIfNotAdmin();
    _setGuardian(_newGuardian);
  }

  /// @notice Sets the rollback queue window.
  /// @param _newRollbackQueueWindow The new rollback queue window.
  /// @dev Can only be called by the admin.
  function setRollbackQueueWindow(uint256 _newRollbackQueueWindow) external {
    _revertIfNotAdmin();
    _setRollbackQueueWindow(_newRollbackQueueWindow);
  }

  /// @notice Sets the admin.
  /// @param _newAdmin The new admin.
  /// @dev Can only be called by the admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /*///////////////////////////////////////////////////////////////
                          Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Calculates the rollback ID for a given set of parameters.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The rollback ID.
  /// @dev This rollback id can be produced from the rollback data which is part of the {RollbackCreated} event.
  ///      It can even be computed in advance, before the rollback is proposed.
  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public pure returns (uint256) {
    return uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description)));
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Reverts if the caller is not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) {
      revert UpgradeRegressionManager__Unauthorized();
    }
  }

  /// @notice Reverts if the caller is not the guardian.
  function _revertIfNotGuardian() internal view {
    if (msg.sender != guardian) {
      revert UpgradeRegressionManager__Unauthorized();
    }
  }

  /// @notice Reverts if the lengths of the parameters do not match.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  function _revertIfMismatchedParameters(address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas)
    internal
    pure
  {
    if (_targets.length != _values.length || _targets.length != _calldatas.length) {
      revert UpgradeRegressionManager__MismatchedParameters();
    }
  }

  /// @notice Utility function to set the guardian.
  /// @param _newGuardian The new guardian.
  function _setGuardian(address _newGuardian) internal {
    if (_newGuardian == address(0)) {
      revert UpgradeRegressionManager__InvalidAddress();
    }

    emit GuardianSet(guardian, _newGuardian);
    guardian = _newGuardian;
  }

  /// @notice Utility function to set the rollback queue window.
  /// @param _newRollbackQueueWindow The new rollback queue window.
  function _setRollbackQueueWindow(uint256 _newRollbackQueueWindow) internal {
    if (_newRollbackQueueWindow == 0) {
      revert UpgradeRegressionManager__InvalidRollbackQueueWindow();
    }

    emit RollbackQueueWindowSet(rollbackQueueWindow, _newRollbackQueueWindow);
    rollbackQueueWindow = _newRollbackQueueWindow;
  }

  /// @notice Utility function to set the admin.
  /// @param _newAdmin The new admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) {
      revert UpgradeRegressionManager__InvalidAddress();
    }

    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }
}
