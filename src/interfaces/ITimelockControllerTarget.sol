// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ITimelockControllerTarget
/// @author [ScopeLift](https://scopelift.co)
/// @notice Minimal interface for interacting with a timelock-compatible target used by URM.
/// @dev This interface represents a simplified subset of the
///      [TimelockController](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/TimelockController.sol)
///      contract, tailored for use by URM.
interface ITimelockControllerTarget {
  /// @notice Schedules a batch of transactions for execution.
  /// @param targets The targets of the transactions.
  /// @param values The values of the transactions.
  /// @param calldatas The calldatas of the transactions.
  /// @param predecessor The predecessor of the transactions.
  /// @param salt The salt of the transactions.
  /// @param delay The delay of the transactions.
  function scheduleBatch(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 predecessor,
    bytes32 salt,
    uint256 delay
  ) external;

  /// @notice Cancels a rollback.
  /// @param rollbackId The rollback ID.
  function cancel(bytes32 rollbackId) external;

  /// @notice Executes a batch of transactions.
  /// @param targets The targets of the transactions.
  /// @param values The values of the transactions.
  /// @param calldatas The calldatas of the transactions.
  /// @param predecessor The predecessor of the transactions.
  /// @param salt The salt of the transactions.
  function executeBatch(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 predecessor,
    bytes32 salt
  ) external payable;

  /// @notice Returns the minimum delay of the timelock.
  /// @return The minimum delay of the timelock.
  function getMinDelay() external view returns (uint256);

  /// @notice Returns the hash of the batch operation.
  /// @param targets The targets of the transactions.
  /// @param values The values of the transactions.
  /// @param payloads The payloads of the transactions.
  /// @param predecessor The predecessor of the transactions.
  /// @param salt The salt of the transactions.
  /// @return The hash of the batch operation.
  function hashOperationBatch(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata payloads,
    bytes32 predecessor,
    bytes32 salt
  ) external view returns (bytes32);
}
