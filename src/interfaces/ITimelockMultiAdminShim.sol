// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

/**
 * @title ITimelockMultiAdminShim
 * @author [ScopeLift](https://scopelift.co)
 * @notice Interface for a Timelock shim that supports multiple executors and a mutable admin.
 * @dev This interface defines functions and events for managing a timelock with multiple authorized executors,
 *      a changeable admin, and secure queuing, cancelling, and execution of transactions via a timelock.
 *
 *      Security Model:
 *      - Anyone can queue transactions targeting external contracts
 *      - Only the admin or an executor can queue transactions targeting this shim
 *      - All shim configuration changes must go through the timelock (with delay)
 *      - The timelock is the only entity that can execute changes to the shim
 *      - This creates a two-step process: admin queues → timelock executes after delay
 */
interface ITimelockMultiAdminShim {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when an unauthorized caller attempts to queue a transaction.
  error TimelockMultiAdminShim__Unauthorized();

  /// @notice Emitted when an invalid admin address is provided.
  error TimelockMultiAdminShim__InvalidAdmin();

  /// @notice Emitted when an invalid timelock address is provided.
  error TimelockMultiAdminShim__InvalidTimelock();

  /*///////////////////////////////////////////////////////////////
                          Events
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Emitted when a new executor is added.
   * @param executor The address of the new executor.
   */
  event ExecutorAdded(address indexed executor);

  /**
   * @notice Emitted when an executor is removed.
   * @param executor The address of the removed executor.
   */
  event ExecutorRemoved(address indexed executor);

  /**
   * @notice Emitted when the admin is updated.
   * @param admin The address of the new admin.
   */
  event AdminUpdated(address indexed admin);

  /*///////////////////////////////////////////////////////////////
                      Public Storage Variables
  //////////////////////////////////////////////////////////////*/

  /// @notice The address of the admin.
  function admin() external view returns (address);

  /// @notice The timelock contract.
  function TIMELOCK() external view returns (ICompoundTimelock);

  /**
   * @notice Whether an address is an executor.
   * @param executor The address to check.
   * @return Whether the address is an executor.
   */
  function isExecutor(address executor) external view returns (bool);

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Queues a transaction to the timelock.
   * @param target The address of the contract to call.
   * @param value The value to send with the transaction.
   * @param signature The function signature to call.
   * @param data The data to send with the transaction.
   * @param eta The eta of the transaction.
   * @return The hash of the queued transaction.
   */
  function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    returns (bytes32);

  /**
   * @notice Cancels a transaction on the timelock.
   * @param target The address of the contract to call.
   * @param value The value to send with the transaction.
   * @param signature The function signature to call.
   * @param data The data to send with the transaction.
   * @param eta The eta of the transaction.
   */
  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external;

  /**
   * @notice Executes a transaction on the timelock.
   * @param target The address of the contract to call.
   * @param value The value to send with the transaction.
   * @param signature The function signature to call.
   * @param data The data to send with the transaction.
   * @param eta The eta of the transaction.
   * @return The data returned by the transaction.
   */
  function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    payable
    returns (bytes memory);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Adds an executor to the timelock.
   * @param _newExecutor The address of the new executor.
   */
  function addExecutor(address _newExecutor) external;

  /**
   * @notice Removes an executor from the timelock.
   * @param _executor The address of the executor to remove.
   */
  function removeExecutor(address _executor) external;

  /**
   * @notice Updates the admin.
   * @param _newAdmin The address of the new admin.
   */
  function updateAdmin(address _newAdmin) external;
}
