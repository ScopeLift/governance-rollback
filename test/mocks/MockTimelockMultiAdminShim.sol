// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ITimelockMultiAdminShim} from "../../src/interfaces/ITimelockMultiAdminShim.sol";

contract MockTimelockMultiAdminShim is ITimelockMultiAdminShim {
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
    TimelockTransactionCall internal _lastQueueTransactionCall;
    TimelockTransactionCall internal _lastExecuteTransactionCall;
    
    // Mock delay for testing
    uint256 public delay = 86400; // 1 day default

    // Mock return values
    bytes32 public mockQueueTransactionReturn = bytes32(uint256(1));
    bytes public mockExecuteTransactionReturn = bytes("");

    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external override returns (bytes32) {
        // Track the call parameters
        _lastQueueTransactionCall = TimelockTransactionCall({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta,
            called: true
        });
        
        return mockQueueTransactionReturn;
    }

    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external payable override returns (bytes memory) {
        // Track the call parameters
        _lastExecuteTransactionCall = TimelockTransactionCall({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta,
            called: true
        });
        
        return mockExecuteTransactionReturn;
    }

    function addExecutor(address _newExecutor) external override {
        // Empty implementation
    }

    function removeExecutor(address _executor) external override {
        // Empty implementation
    }

    function updateAdmin(address _newAdmin) external override {
        // Empty implementation
    }

    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) external override {
        // Empty implementation
    }

    // Helper function to clear all tracked call data
    function clearCallHistory() external {
        delete _lastQueueTransactionCall;
        delete _lastExecuteTransactionCall;
    }

    // Helper function to check if queueTransaction was called
    function wasQueueTransactionCalled() external view returns (bool) {
        return _lastQueueTransactionCall.called;
    }

    // Helper function to check if executeTransaction was called
    function wasExecuteTransactionCalled() external view returns (bool) {
        return _lastExecuteTransactionCall.called;
    }

    // Helper function to get the last queue transaction call as a struct
    function lastQueueTransactionCall() external view returns (TimelockTransactionCall memory) {
        return _lastQueueTransactionCall;
    }

    // Helper function to get the last execute transaction call as a struct
    function lastExecuteTransactionCall() external view returns (TimelockTransactionCall memory) {
        return _lastExecuteTransactionCall;
    }
}
