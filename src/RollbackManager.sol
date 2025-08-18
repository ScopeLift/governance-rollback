// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Libraries
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Internal Libraries
import {IRollbackManager, Rollback} from "interfaces/IRollbackManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @title Rollback Manager Core
/// @author [ScopeLift](https://scopelift.co)
/// @notice Manages the lifecycle of rollback proposals, allowing the admin to propose, and the guardian to queue,
/// cancel, or execute rollback transactions.
/// @dev This contract coordinates a multi-phase rollback process:
///      - Admin proposes rollback transactions.
///      - Guardian queues them for execution within a specified window
///      - Guardian later executes or cancels the queued rollback.
///      - On queuing / cancelling / executing, the transactions are sent to TARGET_TIMELOCK.
abstract contract RollbackManager is IRollbackManager {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Thrown when an unauthorized caller attempts perform an action.
  error RollbackManager__Unauthorized();

  /// @notice Thrown when an invalid address is provided.
  error RollbackManager__InvalidAddress();

  /// @notice Thrown when a rollback does not exist.
  error RollbackManager__NonExistentRollback(uint256 rollbackId);

  /// @notice Thrown when an invalid rollback queueable duration is provided.
  error RollbackManager__InvalidRollbackQueueableDuration();

  /// @notice Thrown when the lengths of the parameters do not match.
  error RollbackManager__MismatchedParameters();

  /// @notice Thrown when a rollback is not proposed or already queued.
  error RollbackManager__NotQueueable(uint256 rollbackId);

  /// @notice Thrown when a rollback is not queued for execution.
  error RollbackManager__NotQueued(uint256 rollbackId);

  /// @notice Thrown when a rollback queue has expired.
  error RollbackManager__Expired(uint256 rollbackId);

  /// @notice Thrown when a rollback's execution time has not yet arrived.
  error RollbackManager__ExecutionTooEarly(uint256 rollbackId);

  /// @notice Thrown when a rollback already exists.
  error RollbackManager__AlreadyExists(uint256 rollbackId);

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

  /// @notice Emitted when the rollback queueable duration is set.
  /// @param oldRollbackQueueableDuration The old rollback queueable duration.
  /// @param newRollbackQueueableDuration The new rollback queueable duration.
  event RollbackQueueableDurationSet(uint256 oldRollbackQueueableDuration, uint256 newRollbackQueueableDuration);

  /// @notice Emitted when the admin is set.
  /// @param oldAdmin The old admin.
  /// @param newAdmin The new admin.
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  /*///////////////////////////////////////////////////////////////
                          State Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice Target for timelocked execution of rollback transactions.
  address public immutable TARGET_TIMELOCK;

  /// @notice The lower bound enforced for the rollbackQueueableDuration setting.
  uint256 public immutable MIN_ROLLBACK_QUEUEABLE_DURATION;

  /// @notice Address that manages this contract.
  address public admin;

  /// @notice Address that can execute rollback transactions.
  address public guardian;

  /// @notice The duration after a rollback is proposed during which it remains eligible to be queued for execution (in
  /// seconds).
  uint256 public rollbackQueueableDuration;

  /// @notice Rollback id to rollback data.
  mapping(uint256 rollbackId => Rollback) internal rollbacks;

  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Initializes the RollbackManager.
  /// @param _targetTimelock The target for timelocked execution of rollback transactions.
  /// @param _admin The address that manages this contract.
  /// @param _guardian The address that can execute rollback transactions.
  /// @param _rollbackQueueableDuration The duration within which a proposed rollback remains eligible to be queued for
  /// execution (in seconds).
  /// @param _minRollbackQueueableDuration The lower bound enforced for the rollbackQueueableDuration setting (in
  /// seconds).
  constructor(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) {
    if (_minRollbackQueueableDuration == 0) {
      revert RollbackManager__InvalidRollbackQueueableDuration();
    }

    if (address(_targetTimelock) == address(0)) {
      revert RollbackManager__InvalidAddress();
    }

    TARGET_TIMELOCK = _targetTimelock;
    MIN_ROLLBACK_QUEUEABLE_DURATION = _minRollbackQueueableDuration;

    _setAdmin(_admin);
    _setRollbackQueueableDuration(_rollbackQueueableDuration);
    _setGuardian(_guardian);
  }

  /*///////////////////////////////////////////////////////////////
                          External Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Get rollback data by ID.
  /// @param _rollbackId The rollback ID.
  /// @return The rollback data.
  function getRollback(uint256 _rollbackId) external view returns (Rollback memory) {
    return rollbacks[_rollbackId];
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

    Rollback storage rollback = rollbacks[_rollbackId];

    // Revert if the rollback already exists.
    if (rollback.queueExpiresAt != 0) {
      revert RollbackManager__AlreadyExists(_rollbackId);
    }

    // Set the time before which the rollback can be queued for execution.
    uint256 _expiresAt = block.timestamp + rollbackQueueableDuration;
    rollback.queueExpiresAt = SafeCast.toUint48(_expiresAt);

    emit RollbackProposed(_rollbackId, _expiresAt, _targets, _values, _calldatas, _description);
  }

  /// @notice Queues a rollback for execution.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the guardian.
  ///      Must be called before the rollback queue window expires (`Rollback.queueExpiresAt`).
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

    Rollback storage rollback = rollbacks[_rollbackId];

    IGovernor.ProposalState _state = _getState(_rollbackId);

    // Revert if the rollback is not pending.
    if (_state != IGovernor.ProposalState.Pending) {
      // Custom revert if the rollback queue has expired.
      if (_state == IGovernor.ProposalState.Expired) {
        revert RollbackManager__Expired(_rollbackId);
      }
      revert RollbackManager__NotQueueable(_rollbackId);
    }

    // Set the time after which the queued rollback can be executed.
    uint256 _eta = block.timestamp + _delay();
    rollback.executableAt = SafeCast.toUint48(_eta);

    // Queue the rollback to the timelock target.
    _queue(_targets, _values, _calldatas, _description);

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

    Rollback storage rollback = rollbacks[_rollbackId];
    IGovernor.ProposalState _state = _getState(_rollbackId);

    // Revert if the rollback has been queued
    if (_state != IGovernor.ProposalState.Queued) {
      revert RollbackManager__NotQueued(_rollbackId);
    }

    rollback.canceled = true;

    // Cancel the rollback transactions on the timelock target.
    _cancel(_targets, _values, _calldatas, _description);

    emit RollbackCanceled(_rollbackId);
  }

  ///  @notice Executes a previously queued rollback by the guardian, forwarding the call to each target contract.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev Can only be called by the guardian.
  ///      Executes the queued rollback transactions after the execution window has begun (`Rollback.executableAt`).
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

    Rollback storage rollback = rollbacks[_rollbackId];
    IGovernor.ProposalState _state = _getState(_rollbackId);

    // Revert if the rollback is not queued.
    if (_state != IGovernor.ProposalState.Queued) {
      revert RollbackManager__NotQueued(_rollbackId);
    }

    // Revert if the rollback's execution time has not arrived.
    if (block.timestamp < rollback.executableAt) {
      revert RollbackManager__ExecutionTooEarly(_rollbackId);
    }

    rollback.executed = true;

    // Execute the rollback on the timelock target.
    _execute(_targets, _values, _calldatas, _description);

    emit RollbackExecuted(_rollbackId);
  }

  /// @notice Sets the guardian.
  /// @param _newGuardian The new guardian.
  /// @dev Can only be called by the admin.
  function setGuardian(address _newGuardian) external {
    _revertIfNotAdmin();
    _setGuardian(_newGuardian);
  }

  /// @notice Sets the rollback queueable duration.
  /// @param _newRollbackQueueableDuration The new rollback queueable duration in seconds.
  /// @dev Can only be called by the admin.
  function setRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) external {
    _revertIfNotAdmin();
    _setRollbackQueueableDuration(_newRollbackQueueableDuration);
  }

  /// @notice Sets the admin.
  /// @param _newAdmin The new admin.
  /// @dev Can only be called by the admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Returns the current state of a proposed rollback.
  /// @param _rollbackId The rollback id to check.
  function state(uint256 _rollbackId) external view returns (IGovernor.ProposalState) {
    return _getState(_rollbackId);
  }

  /// @notice Returns whether a rollback is executable.
  /// @param _rollbackId The rollback id to check.
  function isRollbackExecutable(uint256 _rollbackId) external view returns (bool) {
    if (_getState(_rollbackId) != IGovernor.ProposalState.Queued) {
      return false;
    }
    return block.timestamp >= rollbacks[_rollbackId].executableAt;
  }

  /*///////////////////////////////////////////////////////////////
                          Public Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Calculates the rollback id for a given set of parameters.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The rollback ID.
  /// @dev This rollback id can be produced from the rollback data which is part of the {RollbackProposed} event.
  ///      It can even be computed in advance, before the rollback is proposed.
  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public view virtual returns (uint256);

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Reverts if the caller is not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) {
      revert RollbackManager__Unauthorized();
    }
  }

  /// @notice Reverts if the caller is not the guardian.
  function _revertIfNotGuardian() internal view {
    if (msg.sender != guardian) {
      revert RollbackManager__Unauthorized();
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
      revert RollbackManager__MismatchedParameters();
    }
  }

  /// @notice Utility function to set the guardian.
  /// @param _newGuardian The new guardian.
  function _setGuardian(address _newGuardian) internal {
    if (_newGuardian == address(0)) {
      revert RollbackManager__InvalidAddress();
    }

    emit GuardianSet(guardian, _newGuardian);
    guardian = _newGuardian;
  }

  /// @notice Utility function to set the rollback queueable duration.
  /// @param _newRollbackQueueableDuration The new rollback queueable duration (in seconds).
  function _setRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) internal {
    if (_newRollbackQueueableDuration < MIN_ROLLBACK_QUEUEABLE_DURATION) {
      revert RollbackManager__InvalidRollbackQueueableDuration();
    }

    emit RollbackQueueableDurationSet(rollbackQueueableDuration, _newRollbackQueueableDuration);
    rollbackQueueableDuration = _newRollbackQueueableDuration;
  }

  /// @notice Utility function to set the admin.
  /// @param _newAdmin The new admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) {
      revert RollbackManager__InvalidAddress();
    }

    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Returns the current state of a proposed rollback.
  /// @param _rollbackId The rollback ID.
  /// @return The current IGovernor.ProposalState of the rollback, which can be:
  /// - `Pending`: proposed but not yet queued and not expired.
  /// - `Expired`: proposed but not queued before expiration.
  /// - `Queued`: queued for execution, but delay not elapsed.
  /// - `Executed`: rollback has already been executed (terminal state).
  /// - `Canceled`: rollback was canceled before execution (terminal state).
  /// @dev This function determines the rollback's lifecycle state based on timestamps and flags.
  function _getState(uint256 _rollbackId) internal view returns (IGovernor.ProposalState) {
    Rollback memory _rollback = rollbacks[_rollbackId];

    // Revert if the rollback was not proposed (i.e., does not exist).
    if (_rollback.queueExpiresAt == 0) {
      revert RollbackManager__NonExistentRollback(_rollbackId);
    }

    // Check if the rollback has been executed.
    if (_rollback.executed) {
      return IGovernor.ProposalState.Executed;
    }

    // Check if the rollback has been canceled.
    if (_rollback.canceled) {
      return IGovernor.ProposalState.Canceled;
    }

    // Check if the rollback has been queued for execution.
    if (_rollback.executableAt != 0) {
      return IGovernor.ProposalState.Queued;
    }

    if (block.timestamp >= _rollback.queueExpiresAt) {
      // Rollback is proposed but it's queue window has expired.
      return IGovernor.ProposalState.Expired;
    }

    // Rollback is proposed but not queued for execution.
    return IGovernor.ProposalState.Pending;
  }

  /*///////////////////////////////////////////////////////////////
                      Abstract Target Methods
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the minimum delay required by the timelock target before a queued rollback can be executed.
  /// @return The delay in seconds that must elapse between queueing and executing a rollback.
  function _delay() internal view virtual returns (uint256);

  /// @notice Queues a rollback to the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  function _queue(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal virtual;

  /// @notice Cancels a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal virtual;

  /// @notice Executes a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  function _execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal virtual;
}
