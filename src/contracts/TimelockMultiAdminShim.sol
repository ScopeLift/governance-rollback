// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal Imports
import {ITimelockMultiAdminShim} from "interfaces/ITimelockMultiAdminShim.sol";

/// @title TimelockMultiAdminShim
/// @author [ScopeLift](https://scopelift.co)
/// @notice A shim contract that wraps a Compound Timelock and adds support for multiple executors and a mutable admin.
/// @dev Security Model:
///      - Only the admin can queue transactions targeting this shim contract (e.g., configuration changes).
///      - The admin and any authorized executor can queue transactions targeting external contracts.
contract TimelockMultiAdminShim is ITimelockMultiAdminShim {
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
  mapping(address => bool) public isExecutor;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructor for the TimelockMultiAdminShim contract.
  /// @param _admin The address of the Admin contract.
  /// @param _timelock The address of the Compound Timelock contract.
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

  /// @notice Adds an executor to the timelock.
  /// @param _newExecutor The address of the new executor.
  function addExecutor(address _newExecutor) external {
    _revertIfNotTimelock();
    _revertIfInvalidExecutor(_newExecutor);
    isExecutor[_newExecutor] = true;
    emit ExecutorAdded(_newExecutor);
  }

  /// @notice Removes an executor from the timelock.
  /// @param _executor The address of the executor to remove.
  function removeExecutor(address _executor) external {
    _revertIfNotTimelock();
    _revertIfInvalidExecutor(_executor);
    isExecutor[_executor] = false;
    emit ExecutorRemoved(_executor);
  }

  /// @notice Sets the admin.
  /// @param _newAdmin The address of the new admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotTimelock();
    _setAdmin(_newAdmin);
  }

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  /// @notice Queues a transaction to the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  /// @return The hash of the queued transaction.
  function queueTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta)
    public
    returns (bytes32)
  {
    _revertIfCannotQueue(_target);
    return TIMELOCK.queueTransaction(_target, _value, _signature, _data, _eta);
  }

  /// @notice Cancels a transaction on the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  function cancelTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) public {
    _revertIfNotAdminOrExecutor();
    TIMELOCK.cancelTransaction(_target, _value, _signature, _data, _eta);
  }

  /// @notice Executes a transaction on the timelock.
  /// @param _target The address of the contract to call.
  /// @param _value The value to send with the transaction.
  /// @param _signature The function signature to call.
  /// @param _data The data to send with the transaction.
  /// @param _eta The eta of the transaction.
  /// @return The data returned by the transaction.
  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) public payable returns (bytes memory) {
    _revertIfNotAdminOrExecutor();
    return TIMELOCK.executeTransaction(_target, _value, _signature, _data, _eta);
  }

  /// @notice Returns the delay of the timelock.
  /// @return The delay of the timelock.
  function delay() external view returns (uint256) {
    return TIMELOCK.delay();
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Validates authorization for queueing transactions to the timelock.
  /// @param _target The address of the contract that the function call targets.
  /// @dev Reverts with TimelockMultiAdminShim__Unauthorized if:
  ///      - The target is this contract and the caller is not the admin.
  ///      - The target is an external contract and the caller is not the admin or an authorized executor.
  function _revertIfCannotQueue(address _target) internal view {
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

  /// @notice Utility function to set the admin.
  function _setAdmin(address _newAdmin) internal {
    if (_newAdmin == address(0)) {
      revert TimelockMultiAdminShim__InvalidAdmin();
    }

    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Reverts if the executor is invalid.
  function _revertIfInvalidExecutor(address _executor) internal pure {
    if (_executor == address(0)) {
      revert TimelockMultiAdminShim__InvalidExecutor();
    }
  }
}
