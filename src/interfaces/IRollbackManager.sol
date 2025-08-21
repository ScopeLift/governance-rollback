// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Libraries
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

/// @notice Struct to store rollback data.
/// @param queueExpiresAt The timestamp before which the rollback must be queued for execution.
/// @param executableAt The timestamp after which the rollback can be executed.
/// @param executed Whether the rollback has been executed.
/// @param canceled Whether the rollback has been canceled.
/// @dev executed and canceled are mutually exclusive - both cannot be true
///      queueExpiresAt must be > block.timestamp when rollback is proposed
///      executableAt must be > block.timestamp when rollback is queued
struct Rollback {
  uint48 queueExpiresAt;
  uint48 executableAt;
  bool executed;
  bool canceled;
}

/// @title Rollback Manager Interface
/// @notice Interface for managing the lifecycle of rollback proposals, allowing the admin to propose, and the guardian
/// to queue, cancel, or execute rollback transactions.
interface IRollbackManager {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  /// @notice Target for timelocked execution of rollback transactions.
  function TARGET_TIMELOCK() external view returns (address);

  /// @notice Address that manages this contract.
  function admin() external view returns (address);

  /// @notice Address that can execute rollback transactions.
  function guardian() external view returns (address);

  /// @notice The duration after a rollback is proposed during which it remains eligible to be queued for execution (in
  /// seconds).
  function rollbackQueueableDuration() external view returns (uint256);

  /// @notice Get rollback data by ID.
  /// @param _rollbackId The rollback ID.
  /// @return The rollback data.
  function getRollback(uint256 _rollbackId) external view returns (Rollback memory);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

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
  ) external returns (uint256 _rollbackId);

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
  ) external returns (uint256 _rollbackId);

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
  ) external returns (uint256 _rollbackId);

  /// @notice Executes a previously queued rollback by the guardian, forwarding the call to each target contract.
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
  ) external payable returns (uint256 _rollbackId);

  /// @notice Sets the guardian.
  /// @param _newGuardian The new guardian.
  /// @dev Can only be called by the admin.
  function setGuardian(address _newGuardian) external;

  /// @notice Sets the rollback queueable duration.
  /// @param _newRollbackQueueableDuration The new rollback queueable duration in seconds.
  /// @dev Can only be called by the admin.
  function setRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) external;

  /// @notice Sets the admin.
  /// @param _newAdmin The new admin.
  /// @dev Can only be called by the admin.
  function setAdmin(address _newAdmin) external;

  /// @notice Returns the current state of a proposed rollback.
  /// @param _rollbackId The rollback id to check.
  /// @return The current state of the rollback (Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired,
  /// Executed).
  function state(uint256 _rollbackId) external view returns (IGovernor.ProposalState);

  /// @notice Returns whether a rollback is executable.
  /// @param _rollbackId The rollback id to check.
  /// @return True if the rollback is in Queued state and the execution time has arrived, false otherwise.
  function isRollbackExecutable(uint256 _rollbackId) external view returns (bool);

  /*///////////////////////////////////////////////////////////////
                     Public Functions 
  //////////////////////////////////////////////////////////////*/

  /// @notice Calculates the rollback id for a given set of parameters.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return _rollbackId The rollback ID.
  /// @dev This rollback id can be produced from the rollback data which is part of the {RollbackProposed} event.
  ///      It can even be computed in advance, before the rollback is proposed.
  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view returns (uint256 _rollbackId);
}
