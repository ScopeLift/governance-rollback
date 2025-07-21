// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ITimelockTargetCompound
/// @author [ScopeLift](https://scopelift.co)
/// @notice Minimal interface for interacting with a Compound timelock-compatible target used by Rollback Manager.
/// @dev This interface represents a simplified subset of the
///      [ICompoundTimelock](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/6079eb3f01d5a37ae23e7e72d6909852566bc2e3/contracts/vendor/compound/ICompoundTimelock.sol)
///      contract, tailored for use by Rollback Manager.
interface ITimelockTargetCompound {
  /// @notice Queues a transaction on the timelock.
  /// @param target The address of the contract to call.
  /// @param value The value to send with the transaction.
  /// @param signature The function signature to call.
  /// @param data The data to send with the transaction.
  /// @param eta The eta of the transaction.
  /// @return The tx hash of the queued transaction.
  function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    returns (bytes32);

  /// @notice Cancels a transaction on the timelock.
  /// @param target The address of the contract to call.
  /// @param value The value to send with the transaction.
  /// @param signature The function signature to call.
  /// @param data The data to send with the transaction.
  /// @param eta The eta of the transaction.
  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external;

  /// @notice Executes a transaction on the timelock.
  /// @param target The address of the contract to call.
  /// @param value The value to send with the transaction.
  /// @param signature The function signature to call.
  /// @param data The data to send with the transaction.
  /// @param eta The eta of the transaction.
  /// @return The data returned by the transaction.
  function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    payable
    returns (bytes memory);

  /// @notice Returns the delay of the timelock.
  /// @return The delay of the timelock.
  function delay() external view returns (uint256);
}
