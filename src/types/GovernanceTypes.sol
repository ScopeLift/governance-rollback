// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/*///////////////////////////////////////////////////////////////
                        Structs
//////////////////////////////////////////////////////////////*/

/// @notice Struct to store rollback data.
/// @param queueExpiresAt The timestamp before which the rollback must be queued for execution.
/// @param executableAt The timestamp after which the rollback can be executed.
/// @param executed Whether the rollback has been executed.
/// @param canceled Whether the rollback has been canceled.
/// @dev executed and canceled are mutually exclusive - both cannot be true
///      queueExpiresAt must be > block.timestamp when rollback is proposed
///      executableAt must be > block.timestamp when rollback is queued
struct Rollback {
  uint256 queueExpiresAt;
  uint256 executableAt;
  bool executed;
  bool canceled;
}

/*///////////////////////////////////////////////////////////////
                        Enums
//////////////////////////////////////////////////////////////*/

/// @notice Represents the lifecycle state of a rollback.
/// @dev Reuses the `IGovernor.ProposalState` enum for compatibility, with minor extensions.
/// - `Defeated` and `Succeeded` are retained for compatibility but are unused in this context.
/// - `Unknown` is added to indicate that the rollback has not been proposed.
enum ProposalState {
  Pending,
  Active,
  Canceled,
  Defeated, // Unused
  Succeeded, // Unused
  Queued,
  Expired,
  Executed,
  Unknown // Represents a rollback which has not been proposed (i.e., does not exist)

}
