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
    }

    // Storage for tracking the most recent call to each function
    TimelockTransactionCall public lastQueueTransactionCall;
    TimelockTransactionCall public lastCancelTransactionCall;
    TimelockTransactionCall public lastExecuteTransactionCall;

    // Mock return values
    bytes32 public mockQueueTransactionReturn = bytes32(uint256(1));
    bytes public mockExecuteTransactionReturn = "";

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
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external returns (bytes32) {
        // Track the call parameters
        lastQueueTransactionCall = TimelockTransactionCall({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta
        });

        return mockQueueTransactionReturn;
    }

    /// @dev Mock implementation that tracks parameters
    function cancelTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external {
        // Track the call parameters
        lastCancelTransactionCall = TimelockTransactionCall({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta
        });
    }

    /// @dev Mock implementation that tracks parameters and returns mock value
    function executeTransaction(
        address target,
        uint256 value,
        string calldata signature,
        bytes calldata data,
        uint256 eta
    ) external payable returns (bytes memory) {
        // Track the call parameters
        lastExecuteTransactionCall = TimelockTransactionCall({
            target: target,
            value: value,
            signature: signature,
            data: data,
            eta: eta
        });

        return mockExecuteTransactionReturn;
    }

    /// @dev Clear all tracked call data (useful for test cleanup)
    function clearCallHistory() external onlyAdmin {
        delete lastQueueTransactionCall;
        delete lastCancelTransactionCall;
        delete lastExecuteTransactionCall;
    }

    /// @dev Check if queueTransaction was called
    function wasQueueTransactionCalled() external view returns (bool) {
        return lastQueueTransactionCall.target != address(0);
    }

    /// @dev Check if cancelTransaction was called
    function wasCancelTransactionCalled() external view returns (bool) {
        return lastCancelTransactionCall.target != address(0);
    }

    /// @dev Check if executeTransaction was called
    function wasExecuteTransactionCalled() external view returns (bool) {
        return lastExecuteTransactionCall.target != address(0);
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