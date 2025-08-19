// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";

contract TimelockMultiAdminShimTest is Test {
  TimelockMultiAdminShim public timelockMultiAdminShim;
  address public admin = makeAddr("Admin");
  address public executor = makeAddr("Executor");
  address[] public noExecutors = new address[](0);
  MockCompoundTimelock public timelock;

  function setUp() external {
    timelock = new MockCompoundTimelock();
    address[] memory executors = new address[](1);
    executors[0] = executor;

    timelockMultiAdminShim = new TimelockMultiAdminShim(admin, timelock, executors);
  }

  function _assumeSafeAdmin(address _newAdmin) public pure {
    vm.assume(_newAdmin != address(0));
  }

  function _assumeSafeExecutor(address _newExecutor) public pure {
    vm.assume(_newExecutor != address(0));
  }

  function _assumeSafeExecutors(address[] memory _executors) public pure {
    for (uint256 _i = 0; _i < _executors.length; _i++) {
      vm.assume(_executors[_i] != address(0));
    }
  }

  function _addExecutor(address _executor) internal {
    vm.startPrank(address(timelock));
    timelockMultiAdminShim.addExecutor(_executor);
    vm.stopPrank();
  }

  function _safeAddExecutor(address _executor) internal {
    vm.assume(_executor != address(0));
    _addExecutor(_executor);
  }
}

contract Constructor is TimelockMultiAdminShimTest {
  function testFuzz_SetsInitialParameters(address _admin, address[] memory _executors) external {
    _assumeSafeAdmin(_admin);
    _assumeSafeExecutors(_executors);

    TimelockMultiAdminShim _shim = new TimelockMultiAdminShim(_admin, timelock, _executors);

    assertEq(_shim.admin(), _admin);
    assertEq(address(_shim.TIMELOCK()), address(timelock));

    for (uint256 _index = 0; _index < _executors.length; _index++) {
      assertTrue(_shim.isExecutor(_executors[_index]));
    }
  }

  function testFuzz_EmitsTimelockSetEvent(address _admin, address[] memory _executors) external {
    _assumeSafeAdmin(_admin);
    _assumeSafeExecutors(_executors);

    for (uint256 _index = 0; _index < _executors.length; _index++) {
      vm.expectEmit();
      emit TimelockMultiAdminShim.ExecutorAdded(_executors[_index]);
    }

    new TimelockMultiAdminShim(_admin, timelock, _executors);
  }

  function testFuzz_EmitsAdminSetEvent(address _admin) external {
    _assumeSafeAdmin(_admin);

    vm.expectEmit();
    emit TimelockMultiAdminShim.AdminSet(address(0), _admin);
    new TimelockMultiAdminShim(_admin, timelock, noExecutors);
  }

  function testFuzz_RevertIf_TimelockIsZeroAddress(address _admin) external {
    _assumeSafeAdmin(_admin);

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidTimelock.selector);
    new TimelockMultiAdminShim(_admin, MockCompoundTimelock(payable(address(0))), noExecutors);
  }

  function testFuzz_RevertIf_AdminIsZeroAddress() external {
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidAdmin.selector);
    new TimelockMultiAdminShim(address(0), timelock, noExecutors);
  }
}

contract AddExecutor is TimelockMultiAdminShimTest {
  function testFuzz_AddsAsExecutor(address _executor) external {
    _assumeSafeExecutor(_executor);

    _addExecutor(_executor);

    assertTrue(timelockMultiAdminShim.isExecutor(_executor));
  }

  function testFuzz_EmitsExecutorAddedEvent(address _executor) external {
    _assumeSafeExecutor(_executor);

    vm.expectEmit();
    emit TimelockMultiAdminShim.ExecutorAdded(_executor);
    _addExecutor(_executor);
  }

  function testFuzz_EmitsExecutorAddedEventEvenIfAddressIsAlreadyAnExecutor(address _executor) external {
    _assumeSafeExecutor(_executor);
    _addExecutor(_executor);

    assertTrue(timelockMultiAdminShim.isExecutor(_executor));

    vm.expectEmit();
    emit TimelockMultiAdminShim.ExecutorAdded(_executor);
    _addExecutor(_executor);

    assertTrue(timelockMultiAdminShim.isExecutor(_executor));
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

    assertFalse(timelockMultiAdminShim.isExecutor(_executor));
  }

  function testFuzz_EmitsExecutorRemovedEvent(address _executor) external {
    _assumeSafeExecutor(_executor);
    _addExecutor(_executor);

    vm.prank(address(timelock));
    vm.expectEmit();
    emit TimelockMultiAdminShim.ExecutorRemoved(_executor);
    timelockMultiAdminShim.removeExecutor(_executor);
  }

  function testFuzz_EmitsExecutorRemovedEventEvenIfExecutorIsNotAnExecutor(address _executor) external {
    _assumeSafeExecutor(_executor);
    vm.prank(address(timelock));
    vm.expectEmit();
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

contract SetAdmin is TimelockMultiAdminShimTest {
  function testFuzz_SetsAdmin(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.prank(address(timelock));
    timelockMultiAdminShim.setAdmin(_newAdmin);

    assertEq(timelockMultiAdminShim.admin(), _newAdmin);
  }

  function testFuzz_EmitsAdminSetEvent(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.prank(address(timelock));
    vm.expectEmit();
    emit TimelockMultiAdminShim.AdminSet(admin, _newAdmin);
    timelockMultiAdminShim.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_NewAdminIsZeroAddress() external {
    vm.prank(address(timelock));
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__InvalidAdmin.selector);
    timelockMultiAdminShim.setAdmin(address(0));
  }

  function testFuzz_RevertIf_CallerIsNotTimelock(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.setAdmin(_newAdmin);
  }
}

contract GRACE_PERIOD is TimelockMultiAdminShimTest {
  function test_ReturnsGracePeriodSetInTimelock() external view {
    assertEq(timelockMultiAdminShim.GRACE_PERIOD(), timelock.GRACE_PERIOD());
  }
}

contract MINIMUM_DELAY is TimelockMultiAdminShimTest {
  function test_ReturnsMinimumDelaySetInTimelock() external view {
    assertEq(timelockMultiAdminShim.MINIMUM_DELAY(), timelock.MINIMUM_DELAY());
  }
}

contract MAXIMUM_DELAY is TimelockMultiAdminShimTest {
  function test_ReturnsMaximumDelaySetInTimelock() external view {
    assertEq(timelockMultiAdminShim.MAXIMUM_DELAY(), timelock.MAXIMUM_DELAY());
  }
}

contract QueueTransaction is TimelockMultiAdminShimTest {
  function testFuzz_ForwardsParametersToTimelockWhenTargetIsNotShimAndCallerIsAdmin(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_target != address(timelockMultiAdminShim));

    vm.prank(admin);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    assertTrue(timelock.wasLastParam__queueTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__queueTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_QueueTransactionForwardsParametersToTimelockWhenTargetIsNotShimAndCallerIsExecutor(
    address _executor,
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_target != address(timelockMultiAdminShim));
    _safeAddExecutor(_executor);

    vm.prank(_executor);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
    assertTrue(timelock.wasLastParam__queueTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__queueTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_ForwardsParametersToTimelockWhenTargetIsShimAndCallerIsAdmin(
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    address _target = address(timelockMultiAdminShim);

    vm.prank(admin);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);

    assertTrue(timelock.wasLastParam__queueTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__queueTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_RevertWhen_QueueTransactionTargetIsShimAndCallerIsExecutor(
    address _newExecutor,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    address _target = address(timelockMultiAdminShim);

    vm.assume(_newExecutor != admin);
    _safeAddExecutor(_newExecutor);

    vm.prank(_newExecutor);
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
  }

  function testFuzz_RevertWhen_TargetIsShimAndCallerIsNotAdminOrExecutor(
    address _caller,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    address _target = address(timelockMultiAdminShim);

    vm.assume(_caller != admin);
    vm.assume(_caller != address(0));

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.queueTransaction(_target, _value, _signature, _data, _eta);
  }
}

contract CancelTransaction is TimelockMultiAdminShimTest {
  function testFuzz_ForwardsParametersToTimelockWhenTargetIsNotShimAndCallerIsAdmin(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.prank(admin);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
    assertTrue(timelock.wasLastParam__cancelTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__cancelTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_CancelTransactionForwardsParametersToTimelockWhenTargetIsNotShimAndCallerIsExecutor(
    address _executor,
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_executor != admin);
    vm.assume(_target != address(timelockMultiAdminShim));
    _safeAddExecutor(_executor);

    vm.prank(_executor);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
    assertTrue(timelock.wasLastParam__cancelTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__cancelTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_RevertIf_CallerIsNotAdminOrExecutor(
    address _caller,
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_caller != admin);
    vm.assume(_caller != address(0));
    // No executor added

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
  }

  function testFuzz_ForwardsParametersToTimelockWhenTargetIsShimAndCallerIsAdmin(
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    address _target = address(timelockMultiAdminShim);

    vm.prank(admin);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);

    assertTrue(timelock.wasLastParam__cancelTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__cancelTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_RevertWhen_CancelTransactionTargetIsShimAndCallerIsExecutor(
    address _newExecutor,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    address _target = address(timelockMultiAdminShim);

    vm.assume(_newExecutor != admin);
    _safeAddExecutor(_newExecutor);

    vm.prank(_newExecutor);
    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.cancelTransaction(_target, _value, _signature, _data, _eta);
  }
}

contract ExecuteTransaction is TimelockMultiAdminShimTest {
  function testFuzz_ForwardsParametersToTimelockWhenCallerIsAdmin(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.prank(admin);
    vm.deal(admin, _value);
    bytes memory returnData =
      timelockMultiAdminShim.executeTransaction{value: _value}(_target, _value, _signature, _data, _eta);
    assertEq(returnData, timelock.mock__executeTransactionReturn());
    assertTrue(timelock.wasLastParam__executeTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__executeTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_WhenCallerIsExecutor(
    address _executor,
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_executor != admin);
    _safeAddExecutor(_executor);

    vm.prank(_executor);
    timelockMultiAdminShim.executeTransaction(_target, _value, _signature, _data, _eta);
    assertTrue(timelock.wasLastParam__executeTransaction__Called());

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__executeTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_ForwardsParametersToTheTimelock(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.prank(admin);
    vm.deal(admin, _value);

    timelockMultiAdminShim.executeTransaction(_target, _value, _signature, _data, _eta);

    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__executeTransaction__();

    assertEq(timelockTxnCall.target, _target);
    assertEq(timelockTxnCall.value, _value);
    assertEq(timelockTxnCall.signature, _signature);
    assertEq(timelockTxnCall.data, _data);
    assertEq(timelockTxnCall.eta, _eta);
  }

  function testFuzz_FlushesAccidentallySentETH(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta,
    uint256 _accidentalETH
  ) external {
    _value = bound(_value, 0, 10 ether);
    _accidentalETH = bound(_accidentalETH, 1 ether, 5 ether);

    // Simulate someone accidentally sending ETH to the shim contract
    vm.deal(address(timelockMultiAdminShim), _accidentalETH);
    assertEq(address(timelockMultiAdminShim).balance, _accidentalETH);

    vm.deal(admin, _value);
    vm.prank(admin);

    // Execute transaction - should flush ALL ETH (both the intended value and accidental ETH)
    timelockMultiAdminShim.executeTransaction{value: _value}(_target, _value, _signature, _data, _eta);

    // Verify that ALL ETH was flushed (both the intended value and the accidental ETH)
    assertEq(address(timelockMultiAdminShim).balance, 0);

    // Verify that the timelock received the original intended value as the parameter
    // (the timelock actually receives all ETH via {value: address(this).balance},
    // but the _value parameter is still the original intended value)
    MockCompoundTimelock.TimelockTransactionCall memory timelockTxnCall = timelock.lastParam__executeTransaction__();
    assertEq(timelockTxnCall.value, _value);
  }

  function testFuzz_RevertIf_CallerIsNotAdminOrExecutor(
    address _caller,
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external {
    vm.assume(_caller != admin);
    vm.assume(_caller != address(0));
    // No executor added

    vm.expectRevert(TimelockMultiAdminShim.TimelockMultiAdminShim__Unauthorized.selector);
    timelockMultiAdminShim.executeTransaction(_target, _value, _signature, _data, _eta);
  }
}

contract Delay is TimelockMultiAdminShimTest {
  function test_ReturnsDelaySetInTimelock() external view {
    assertEq(timelockMultiAdminShim.delay(), timelock.delay());
  }
}

contract QueuedTransactions is TimelockMultiAdminShimTest {
  function test_ReturnsQueuedTransactionsSetInTimelock() external view {
    bytes32 txHash = keccak256(abi.encode(address(0), 0, "", "", 0));
    assertEq(timelockMultiAdminShim.queuedTransactions(txHash), timelock.queuedTransactions(txHash));
  }
}

contract AcceptAdmin is TimelockMultiAdminShimTest {
  function testFuzz_AcceptsAdminPassesToTimelock(address _newAdmin) external {
    vm.prank(_newAdmin);
    timelockMultiAdminShim.acceptAdmin();
    assertTrue(timelock.lastParam__acceptAdmin__called());
  }
}

contract Receive is TimelockMultiAdminShimTest {
  function testFuzz_ReceiveAcceptsEther(uint256 _amount) external {
    _amount = bound(_amount, 0, 10 ether);
    vm.deal(address(this), _amount);
    assertEq(address(timelockMultiAdminShim).balance, 0);
    (bool success,) = payable(address(timelockMultiAdminShim)).call{value: _amount}("");
    assertTrue(success);
    assertEq(address(timelockMultiAdminShim).balance, _amount);
  }
}
