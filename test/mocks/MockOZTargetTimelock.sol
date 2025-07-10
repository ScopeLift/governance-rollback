// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITimelockControllerTarget} from "src/interfaces/ITimelockControllerTarget.sol";

contract MockOZTargetTimelock is ITimelockControllerTarget {
  // Structs for tracking function call parameters
  struct BatchCall {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 predecessor;
    bytes32 salt;
    uint256 delay;
    bool called;
    uint256 valueSent;
  }

  struct ExecuteBatchCall {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    bytes32 predecessor;
    bytes32 salt;
    uint256 valueSent;
    bool called;
  }

  struct CancelCall {
    bytes32 rollbackId;
    bool called;
  }

  // Storage for tracking the most recent call to each function
  BatchCall internal _lastParam__scheduleBatch__;
  ExecuteBatchCall internal _lastParam__executeBatch__;
  CancelCall internal _lastParam__cancel__;
  uint256 public minDelay = 1 days;

  // Mock implementation of scheduleBatch
  function scheduleBatch(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 predecessor,
    bytes32 salt,
    uint256 delay
  ) external override {
    _lastParam__scheduleBatch__ = BatchCall({
      targets: targets,
      values: values,
      calldatas: calldatas,
      predecessor: predecessor,
      salt: salt,
      delay: delay,
      called: true,
      valueSent: 0
    });
  }

  // Mock implementation of cancel
  function cancel(bytes32 rollbackId) external override {
    _lastParam__cancel__ = CancelCall({rollbackId: rollbackId, called: true});
  }

  // Mock implementation of executeBatch
  function executeBatch(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 predecessor,
    bytes32 salt
  ) external payable override {
    _lastParam__executeBatch__ = ExecuteBatchCall({
      targets: targets,
      values: values,
      calldatas: calldatas,
      predecessor: predecessor,
      salt: salt,
      valueSent: msg.value,
      called: true
    });
  }

  // Mock implementation of getMinDelay
  function getMinDelay() external view override returns (uint256) {
    return minDelay;
  }

  // Mock implementation of hashOperationBatch
  function hashOperationBatch(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata payloads,
    bytes32 predecessor,
    bytes32 salt
  ) external pure override returns (bytes32) {
    return keccak256(abi.encode(targets, values, payloads, predecessor, salt));
  }

  // Helper functions to access call history
  function lastParam__scheduleBatch__() external view returns (BatchCall memory) {
    return _lastParam__scheduleBatch__;
  }

  function lastParam__executeBatch__() external view returns (ExecuteBatchCall memory) {
    return _lastParam__executeBatch__;
  }

  function lastParam__cancel__() external view returns (CancelCall memory) {
    return _lastParam__cancel__;
  }

  function clearCallHistory() external {
    delete _lastParam__scheduleBatch__;
    delete _lastParam__executeBatch__;
    delete _lastParam__cancel__;
  }

  function setMinDelay(uint256 _minDelay) external {
    minDelay = _minDelay;
  }
}
