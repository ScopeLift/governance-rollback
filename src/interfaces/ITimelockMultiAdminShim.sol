// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

/// @title Timelock Multi Admin Shim Interface
/// @notice Interface for a shim contract that wraps a Compound Timelock and adds support for multiple executors and a
/// mutable admin.
/// @dev Security Model:
///      - Only the admin can queue transactions targeting this shim contract (e.g., configuration changes).
///      - The admin and any authorized executor can queue transactions targeting external contracts.
interface ITimelockMultiAdminShim {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  /// @notice The timelock contract.
  function TIMELOCK() external view returns (ICompoundTimelock);

  /// @notice The address of the admin.
  function admin() external view returns (address);

  /// @notice Tracks which addresses are authorized to execute queue and execute transactions.
  /// @param _executor The address to check.
  /// @return True if the address is an authorized executor, false otherwise.
  function isExecutor(address _executor) external view returns (bool);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  /// @notice Adds an executor to the timelock.
  /// @param _newExecutor The address of the new executor.
  /// @dev Can only be called by the timelock contract.
  function addExecutor(address _newExecutor) external;

  /// @notice Removes an executor from the timelock.
  /// @param _executor The address of the executor to remove.
  /// @dev Can only be called by the timelock contract.
  function removeExecutor(address _executor) external;

  /// @notice Sets the admin.
  /// @param _newAdmin The address of the new admin.
  /// @dev Can only be called by the timelock contract.
  function setAdmin(address _newAdmin) external;

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the grace period of the timelock.
  /// @return The grace period of the timelock in seconds.
  function GRACE_PERIOD() external view returns (uint256);

  /// @notice Returns the minimum delay of the timelock.
  /// @return The minimum delay of the timelock in seconds.
  function MINIMUM_DELAY() external view returns (uint256);

  /// @notice Returns the maximum delay of the timelock.
  /// @return The maximum delay of the timelock in seconds.
  function MAXIMUM_DELAY() external view returns (uint256);

  /// @notice Queues a transaction to the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  /// @return The hash of the queued transaction.
  /// @dev Can only be called by the admin or an authorized executor.
  ///      If the target is this shim contract, only the admin can queue the transaction.
  function queueTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta)
    external
    returns (bytes32);

  /// @notice Cancels a transaction on the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  /// @dev Can only be called by the admin or an authorized executor.
  function cancelTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external;

  /// @notice Executes a transaction on the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  /// @return The data returned by the transaction.
  /// @dev Can only be called by the admin or an authorized executor.
  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external payable returns (bytes memory);

  /// @notice Returns the delay of the timelock.
  /// @return The delay of the timelock in seconds.
  function delay() external view returns (uint256);

  /// @notice Accepts the admin role from the timelock contract.
  /// @dev Can only be called by the timelock contract.
  function acceptAdmin() external;
}
