// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITimelockTargetCompound} from "src/interfaces/ITimelockTargetCompound.sol";

contract MockTimelockTargetCompound is ITimelockTargetCompound {
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
  TimelockTransactionCall[] internal _lastParam__queueTransactions__;
  TimelockTransactionCall[] internal _lastParam__cancelTransactions__;
  TimelockTransactionCall[] internal _lastParam__executeTransactions__;

  // Mock delay for testing
  uint256 public delay = 1 days;

  /// @dev Mock implementation that tracks parameters and returns mock value
  function queueTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta)
    external
    returns (bytes32)
  {
    // Track the call parameters
    _lastParam__queueTransactions__.push(
      TimelockTransactionCall({target: target, value: value, signature: signature, data: data, eta: eta, called: true})
    );

    return bytes32(uint256(_lastParam__queueTransactions__.length));
  }

  /// @dev Mock implementation that tracks parameters
  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
  {
    // Track the call parameters
    _lastParam__cancelTransactions__.push(
      TimelockTransactionCall({target: target, value: value, signature: signature, data: data, eta: eta, called: true})
    );
  }

  /// @dev Mock implementation that tracks parameters and returns mock value
  function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    payable
    override
    returns (bytes memory)
  {
    // Track the call parameters
    _lastParam__executeTransactions__.push(
      TimelockTransactionCall({target: target, value: value, signature: signature, data: data, eta: eta, called: true})
    );

    return abi.encode(_lastParam__executeTransactions__.length);
  }

  // Helper function to clear all tracked call data
  function clearCallHistory() external {
    delete _lastParam__queueTransactions__;
    delete _lastParam__cancelTransactions__;
    delete _lastParam__executeTransactions__;
  }

  // Helper function to get the last queue transaction call as a struct
  function lastParam__queueTransactions__() external view returns (TimelockTransactionCall[] memory) {
    return _lastParam__queueTransactions__;
  }

  // Helper function to get the last execute transaction call as a struct
  function lastParam__executeTransactions__() external view returns (TimelockTransactionCall[] memory) {
    return _lastParam__executeTransactions__;
  }

  // Helper function to get the last cancel transaction call as a struct
  function lastParam__cancelTransactions__() external view returns (TimelockTransactionCall[] memory) {
    return _lastParam__cancelTransactions__;
  }

  // Helper function to set the delay
  function setDelay(uint256 _delay) external {
    delay = _delay;
  }
}
