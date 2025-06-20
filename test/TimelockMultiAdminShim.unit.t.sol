// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";

contract TimelockMultiAdminShimTest is Test {
  TimelockMultiAdminShim public timelockMultiAdminShim;
  address public admin = makeAddr("Admin");
  MockCompoundTimelock public timelock;

  function setUp() external {
    timelock = new MockCompoundTimelock();
   
    timelockMultiAdminShim = new TimelockMultiAdminShim(
      admin,
      timelock
    );
  }

  function _assumeSafeAdmin(address _newAdmin) public pure {
    vm.assume(_newAdmin != address(0));
  }

  function _assumeSafeExecutor(address _newExecutor) public pure {
    vm.assume(_newExecutor != address(0));
  }  

  function _assumeReasonableValue(uint256 _value) public pure {
    // Constrain value to reasonable amounts for testing (e.g., max 100 ETH)
    vm.assume(_value <= 100 ether);
  }

  function _addExecutor(address _executor) internal {
    vm.startPrank(address(timelock));
    timelockMultiAdminShim.addExecutor(_executor);
    vm.stopPrank();
  }

  function _safeAddExecutor(address _executor) internal {
    vm.assume(_executor!= address(0));
    _addExecutor(_executor);
  }
}


contract Constructor is TimelockMultiAdminShimTest {
  
  function testFuzz_SetsIntializeParameters(address _admin) external {
    _assumeSafeAdmin(_admin);
    
    TimelockMultiAdminShim _shim = new TimelockMultiAdminShim(_admin, timelock);

    assertEq(_shim.admin(), _admin);
    assertEq(address(_shim.TIMELOCK()), address(timelock));
  }

  function testFuzz_EmitsTimelockSetEvent(address _admin) external {
    _assumeSafeAdmin(_admin);
    
    vm.expectEmit(true, true, true, true);
    emit TimelockMultiAdminShim.TimelockSet(address(timelock));
    new TimelockMultiAdminShim(_admin, timelock);
  }

  function testFuzz_EmitsAdminUpdatedEvent(address _admin) external {
    _assumeSafeAdmin(_admin);
    
    vm.expectEmit(true, true, true, true);
    emit TimelockMultiAdminShim.AdminUpdated(address(0), _admin);
    new TimelockMultiAdminShim(_admin, timelock);
  }
  
  function testFuzz_RevertIf_TimelockIsZeroAddress(address _admin) external {
    _assumeSafeAdmin(_admin);
    
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidTimelock.selector);
    new TimelockMultiAdminShim(_admin, MockCompoundTimelock(payable(address(0))));
  }

  function testFuzz_RevertIf_AdminIsZeroAddress() external {
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidAdmin.selector);
    new TimelockMultiAdminShim(address(0), timelock);
  }
}

contract AddExecutor is TimelockMultiAdminShimTest {

  function testFuzz_AddsAsExecutor(address _executor) external {
    _assumeSafeExecutor(_executor);
  
    _addExecutor(_executor);

    assertEq(timelockMultiAdminShim.isExecutor(_executor), true);
  }

  function testFuzz_EmitsExecutorAddedEvent(address _executor) external {
    _assumeSafeExecutor(_executor);
    
    vm.expectEmit(true, true, true, true);
    emit TimelockMultiAdminShim.ExecutorAdded(_executor);
    _addExecutor(_executor);
  }

  function test_RevertIf_ExecutorIsZeroAddress() external {    
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidExecutor.selector);
    _addExecutor(address(0));
  }

  function testFuzz_RevertIf_CallerIsNotTimelock(address _executor) external {
    _assumeSafeExecutor(_executor);
    
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.addExecutor(_executor);
  }
}

contract RemoveExecutor is TimelockMultiAdminShimTest {
  function testFuzz_RemovesAsExecutor(address _executor) external {
    _assumeSafeExecutor(_executor);
    _addExecutor(_executor);
    
    vm.prank(address(timelock));
    timelockMultiAdminShim.removeExecutor(_executor);

    assertEq(timelockMultiAdminShim.isExecutor(_executor), false);
  }

  function testFuzz_EmitsExecutorRemovedEvent(address _executor) external {
    _assumeSafeExecutor(_executor);
    _addExecutor(_executor);
    
    vm.prank(address(timelock));
    vm.expectEmit(true, true, true, true);
    emit TimelockMultiAdminShim.ExecutorRemoved(_executor);
    timelockMultiAdminShim.removeExecutor(_executor);
  }

  function test_RevertIf_ExecutorIsZeroAddress() external {
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidExecutor.selector);
    vm.prank(address(timelock));
    timelockMultiAdminShim.removeExecutor(address(0));
  }

  function testFuzz_RevertIf_CallerIsNotTimelock(address _executor) external {
    _assumeSafeExecutor(_executor);
    _addExecutor(_executor);
    
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.removeExecutor(_executor);
  }
}

contract UpdateAdmin is TimelockMultiAdminShimTest {
  function testFuzz_UpdatesAdmin(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    
    vm.prank(address(timelock));
    timelockMultiAdminShim.updateAdmin(_newAdmin);

    assertEq(timelockMultiAdminShim.admin(), _newAdmin);
  }

  function testFuzz_EmitsAdminUpdatedEvent(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    
    vm.prank(address(timelock));
    vm.expectEmit(true, true, true, true);
    emit TimelockMultiAdminShim.AdminUpdated(admin, _newAdmin);
    timelockMultiAdminShim.updateAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_NewAdminIsZeroAddress() external {
    vm.prank(address(timelock));
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidAdmin.selector);
    timelockMultiAdminShim.updateAdmin(address(0));
  }

  function testFuzz_RevertIf_CallerIsNotTimelock(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.updateAdmin(_newAdmin);
  }
}

contract QueueTransaction is TimelockMultiAdminShimTest {
  function testFuzz_QueuesTransactionWhenTargetIsNotShim(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.assume(_target != address(timelockMultiAdminShim));

    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    assertEq(timelock.wasQueueTransactionCalled(), true);
  }

  function testFuzz_ParametersArePassedToTimelock(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.prank(admin);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    
    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastQueueTransactionCall();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_QueuesTransactionWhenTargetIsShimAndCallerIsAdmin(uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    address _target = address(timelockMultiAdminShim);

    vm.prank(admin);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    
    assertEq(timelock.wasQueueTransactionCalled(), true);
  }

  function testFuzz_QueuesTransactionWhenTargetIsShimAndCallerIsExecutor(address _newExecutor, address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    address _target = address(timelockMultiAdminShim);
    
    vm.assume(_newExecutor != admin);
    _safeAddExecutor(_newExecutor);

    vm.prank(_newExecutor);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    assertEq(timelock.wasQueueTransactionCalled(), true);
  }

  function testFuzz_RevertWhen_TargetIsShimAndCallerIsNotAdminOrExecutor(uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    address _target = address(timelockMultiAdminShim);

    vm.assume(msg.sender != admin);
    // No executor added

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
  }
  
}

contract CancelTransaction is TimelockMultiAdminShimTest {
  function testFuzz_CancelsTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.prank(admin);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
    assertEq(timelock.wasCancelTransactionCalled(), true);
  }

  function testFuzz_ParametersArePassedToTimelock(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.prank(admin);

    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastCancelTransactionCall();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
  }
}

contract ExecuteTransaction is TimelockMultiAdminShimTest {
  function testFuzz_ExecutesTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.prank(admin);
    vm.deal(admin, _value);
    bytes memory returnData = timelockMultiAdminShim.executeTransaction{value: _value}(_target, _value, _signature, _data, _eta);
    assertEq(returnData, timelock.mockExecuteTransactionReturn());
    assertEq(timelock.wasExecuteTransactionCalled(), true);
  }

  function testFuzz_ParametersArePassedToTimelock(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.prank(admin);
    vm.deal(admin, _value);

    timelockMultiAdminShim.executeTransaction(_target, _value, _signature, _data, _eta);

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastExecuteTransactionCall();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta) external {
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.executeTransaction(_target, _value, _signature, _data, _eta);
  }
}

/// @dev Internal Functions Skipped as these are not intended to be inherited by other contracts
contract _revertIfCannotQueue is TimelockMultiAdminShimTest { }
contract _revertIfNotAdmin is TimelockMultiAdminShimTest { }
contract _revertIfNotTimelock is TimelockMultiAdminShimTest { }
contract _setAdmin is TimelockMultiAdminShimTest { }
contract _revertIfInvalidExecutor is TimelockMultiAdminShimTest { }