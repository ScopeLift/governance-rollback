// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal Imports
import {ITimelockMultiAdminShim} from "interfaces/ITimelockMultiAdminShim.sol";

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
contract TimelockMultiAdminShim is ITimelockMultiAdminShim {
  /*///////////////////////////////////////////////////////////////
                          Errors
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when an unauthorized caller attempts to queue a transaction.
  error TimelockMultiAdminShim__Unauthorized();

  /// @notice Emitted when an invalid admin address is provided.
  error TimelockMultiAdminShim__InvalidAdmin();

  /// @notice Emitted when an invalid timelock address is provided.
  error TimelockMultiAdminShim__InvalidTimelock();

  /// @notice Emitted when an invalid executor address is provided.
  error TimelockMultiAdminShim__InvalidExecutor();

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
   * @param previousAdmin The address of the previous admin.
   * @param newAdmin The address of the new admin.
   */
  event AdminUpdated(address indexed previousAdmin, address indexed newAdmin);

  /**
   * @notice Emitted when the timelock is updated.
   * @param timelock The address of the timelock.
   */
  event TimelockSet(address indexed timelock);

  /*///////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////*/

  /// @notice The address of the admin.
  address public admin;

  /// @notice The timelock contract.
  ICompoundTimelock public immutable TIMELOCK;

  /// @notice Tracks which addresses are authorized to execute queue and execute transactions.
  mapping(address => bool) public isExecutor;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Constructor for the TimelockMultiAdminShim contract.
   * @param _admin The address of the Admin contract.
   * @param _timelock The address of the Compound Timelock contract.
   */
  constructor(address _admin, ICompoundTimelock _timelock) {
    if (address(_timelock) == address(0)) {
      revert TimelockMultiAdminShim__InvalidTimelock();
    }
    TIMELOCK = _timelock;
    emit TimelockSet(address(_timelock));

    _setAdmin(_admin);
  }

  /*///////////////////////////////////////////////////////////////
                      External Functions
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Adds an executor to the timelock.
   * @param _newExecutor The address of the new executor.
   */
  function addExecutor(address _newExecutor) external {
    _revertIfNotTimelock();
    _revertIfInvalidExecutor(_newExecutor);
    isExecutor[_newExecutor] = true;
    emit ExecutorAdded(_newExecutor);
  }

  /**
   * @notice Removes an executor from the timelock.
   * @param _executor The address of the executor to remove.
   */
  function removeExecutor(address _executor) external {
    _revertIfNotTimelock();
    _revertIfInvalidExecutor(_executor);
    isExecutor[_executor] = false;
    emit ExecutorRemoved(_executor);
  }

  /**
   * @notice Updates the admin.
   * @param _newAdmin The address of the new admin.
   */
  function updateAdmin(address _newAdmin) external {
    _revertIfNotTimelock();
    _setAdmin(_newAdmin);
  }

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
    public
    returns (bytes32)
  {
    _revertIfCannotQueue(target);
    return TIMELOCK.queueTransaction(target, value, signature, data, eta);
  }

  /**
   * @notice Cancels a transaction on the timelock.
   * @param target The address of the contract to call.
   * @param value The value to send with the transaction.
   * @param signature The function signature to call.
   * @param data The data to send with the transaction.
   * @param eta The eta of the transaction.
   */
  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    public
  {
    _revertIfNotAdmin();
    TIMELOCK.cancelTransaction(target, value, signature, data, eta);
  }

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
    public
    payable
    returns (bytes memory)
  {
    _revertIfNotAdmin();
    return TIMELOCK.executeTransaction(target, value, signature, data, eta);
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Validates authorization for queueing transactions to the timelock.
   * @param target The address of the contract that the function call targets.
   * @dev Reverts with TimelockMultiAdminShim__Unauthorized if:
   *      - The target is this contract and the caller is not the admin or an authorized executor.
   *      - Allows any caller to queue transactions targeting external contracts.
   */
  function _revertIfCannotQueue(address target) internal view {
    if (target == address(this)) {
      if (msg.sender != admin && !isExecutor[msg.sender]) {
        revert TimelockMultiAdminShim__Unauthorized();
      }
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

  /// @notice Utility function to set the admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) {
      revert TimelockMultiAdminShim__InvalidAdmin();
    }

    emit AdminUpdated(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Reverts if the executor is invalid.
  function _revertIfInvalidExecutor(address _executor) internal pure {
    if (_executor == address(0)) {
      revert TimelockMultiAdminShim__InvalidExecutor();
    }
  }
}

/*///////////////////////////////////////////////////////////////
                      Team Notes
//////////////////////////////////////////////////////////////*/

// This method should only be callable by the TIMELOCK *when the transaction originated from the Governor*
// Ways we might be able to do this:
// * In the shim, before forwarding to the timelock, cache the address that is making the call,
// and remember it when the Timelock calls it. Are there timing issues here where we can't know for sure
// that the transaction executing is the most recently cached executor? This would probably look like the
// OZ Governor protection that puts operations on the Governor itself into a `_governanceCall` queue. This
// method would allow the transaction to flow through the timelock, experience the timelock delay, execute
// from the timelock after the delay, and yet only be executable if the transaction came originally from
// Governor. ACTUALLY: Aditya points out we don't need a queue. In the `queueTransaction` method, if the
// sender is not the Governor, but the target is this contract, just revert.
// * In the queueTransaction method that calls the Timelock, have it observe the target/calldata and use some
// specific target/calldata combo as a "special" code that can configure the shim but only if sent from
// the Governor. For example, if the target address is this contract, execute immediately and remove from
// the list forwarded to the Timelock. This version would skip the time delay for transactions that configure
// the shim.
