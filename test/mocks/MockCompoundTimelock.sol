// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

/// @title MockCompoundTimelock
/// @dev Mock implementation of ICompoundTimelock for testing purposes.
/// Tracks parameters of function calls for verification in tests.
contract MockCompoundTimelock is ICompoundTimelock {
  // Struct for tracking function call parameters
  struct TimelockTransactionCall {
    address target;
    uint256 value;
    string signature;
    bytes data;
    uint256 eta;
    bool called;
  }

  // Storage for tracking the most recent call to each function
  TimelockTransactionCall public _lastParam__queueTransaction__;
  TimelockTransactionCall public _lastParam__cancelTransaction__;
  TimelockTransactionCall public _lastParam__executeTransaction__;

  // Mock return values
  bytes32 public mock__queueTransactionReturn = bytes32(uint256(1));
  bytes public mock__executeTransactionReturn = bytes("");

  // Admin for setting mock return values
  address public admin;

  constructor() {
    admin = msg.sender;
  }

  modifier onlyAdmin() {
    require(msg.sender == admin, "MockCompoundTimelock: caller is not admin");
    _;
  }

  /// @dev Mock implementation that tracks parameters and returns mock value
  function queueTransaction(
    address _target,
    uint256 _value,
    string calldata _signature,
    bytes calldata _data,
    uint256 _eta
  ) external returns (bytes32) {
    // Track the call parameters
    _lastParam__queueTransaction__ = TimelockTransactionCall({
      target: _target,
      value: _value,
      signature: _signature,
      data: _data,
      eta: _eta,
      called: true
    });

    return mock__queueTransactionReturn;
  }

  /// @dev Mock implementation that tracks parameters
  function cancelTransaction(
    address _target,
    uint256 _value,
    string calldata _signature,
    bytes calldata _data,
    uint256 _eta
  ) external {
    // Track the call parameters
    _lastParam__cancelTransaction__ = TimelockTransactionCall({
      target: _target,
      value: _value,
      signature: _signature,
      data: _data,
      eta: _eta,
      called: true
    });
  }

  /// @dev Mock implementation that tracks parameters and returns mock value
  function executeTransaction(
    address _target,
    uint256 _value,
    string calldata _signature,
    bytes calldata _data,
    uint256 _eta
  ) external payable returns (bytes memory) {
    // Track the call parameters
    _lastParam__executeTransaction__ = TimelockTransactionCall({
      target: _target,
      value: _value,
      signature: _signature,
      data: _data,
      eta: _eta,
      called: true
    });

    return mock__executeTransactionReturn;
  }

  /// @dev Clear all tracked call data (useful for test cleanup)
  function clearCallHistory() external onlyAdmin {
    delete _lastParam__queueTransaction__;
    delete _lastParam__cancelTransaction__;
    delete _lastParam__executeTransaction__;
  }

  /// @dev Check if queueTransaction was called
  function wasLastParam__queueTransaction__Called() external view returns (bool) {
    return _lastParam__queueTransaction__.called;
  }

  /// @dev Check if cancelTransaction was called
  function wasLastParam__cancelTransaction__Called() external view returns (bool) {
    return _lastParam__cancelTransaction__.called;
  }

  /// @dev Check if executeTransaction was called
  function wasLastParam__executeTransaction__Called() external view returns (bool) {
    return _lastParam__executeTransaction__.called;
  }

  /// @dev Get the last queue transaction call as a struct
  function lastParam__queueTransaction__() external view returns (TimelockTransactionCall memory) {
    return _lastParam__queueTransaction__;
  }

  /// @dev Get the last cancel transaction call as a struct
  function lastParam__cancelTransaction__() external view returns (TimelockTransactionCall memory) {
    return _lastParam__cancelTransaction__;
  }

  /// @dev Get the last execute transaction call as a struct
  function lastParam__executeTransaction__() external view returns (TimelockTransactionCall memory) {
    return _lastParam__executeTransaction__;
  }

  // Empty implementations for other interface functions
  receive() external payable {}

  function GRACE_PERIOD() external pure returns (uint256) {
    return 14 days;
  }

  function MINIMUM_DELAY() external pure returns (uint256) {
    return 2 days;
  }

  function MAXIMUM_DELAY() external pure returns (uint256) {
    return 30 days;
  }

  function pendingAdmin() external pure returns (address) {
    return address(0);
  }

  function delay() external pure returns (uint256) {
    return 2 days;
  }

  function queuedTransactions(bytes32) external pure returns (bool) {
    return false;
  }

  function setDelay(uint256) external {}

  function acceptAdmin() external {}

  function setPendingAdmin(address) external {}
}
