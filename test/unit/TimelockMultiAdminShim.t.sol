// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract TimelockMultiAdminShim {

    function test_ConstructorWhenPassingValidAdminAndTimelockAddresses() external {
        // it should deploy
        // it should set the admin address
        // it should set the timelock address
    }

    function test_ConstructorRevertWhen_PassingZeroAdminAddress() external {
        // it should revert
    }

    function test_ConstructorRevertWhen_PassingZeroTimelockAddress() external {
        // it should revert
    }

    modifier whenTargetIsThisContract() {
        _;
    }

    function test_QueueTransactionWhenCallerIsAdmin() external whenTargetIsThisContract {
        // it should forward the call to timelock
    }

    function test_QueueTransactionWhenCallerIsAuthorizedExecutor() external whenTargetIsThisContract {
        // it should forward the call to timelock
    }

    function test_QueueTransactionWhenCallerIsBothAdminAndExecutor() external whenTargetIsThisContract {
        // it should forward the call to timelock
    }

    function test_QueueTransactionRevertWhen_CallerIsNotAdminOrExecutor() external whenTargetIsThisContract {
        // it should revert
    }

    function test_QueueTransactionWhenTargetIsExternalContract() external {
        // it should forward the call to timelock
    }

    function test_CancelTransactionWhenCalled() external {
        // it should forward the call to timelock
    }

    function test_ExecuteTransactionWhenCalled() external {
        // it should forward the call to timelock
    }

    function test_AddExecutorWhenCalledByTimelock() external {
        // it should mark the address as executor
        // it should emit ExecutorAdded event
    }

    function test_AddExecutorRevertWhen_CalledByNon_timelock() external {
        // it should revert
    }

    function test_RemoveExecutorWhenCalledByTimelock() external {
        // it should unmark the address as executor
        // it should emit ExecutorRemoved event
    }

    function test_RemoveExecutorRevertWhen_CalledByNon_timelock() external {
        // it should revert
    }

    function test_UpdateAdminWhenCalledByTimelock() external {
        // it should update the admin address
        // it should emit AdminUpdated event
    }

    function test_UpdateAdminRevertWhen_CalledByNon_timelock() external {
        // it should revert
    }
}
