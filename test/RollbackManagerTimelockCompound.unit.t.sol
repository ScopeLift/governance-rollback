// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {RollbackManager} from "src/RollbackManager.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockTimelockTargetCompound} from "test/mocks/MockTimelockTargetCompound.sol";
import "test/helpers/RollbackManagerUnitTestBase.sol";

contract RollbackManagerTimelockCompoundTest is RollbackManagerUnitTestBase {
  MockTimelockTargetCompound public targetTimelock;

  function _getRollbackManagerType() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _deployRollbackManager(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal override returns (RollbackManager) {
    return new RollbackManagerTimelockCompound(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function _timelockDelay() internal view override returns (uint256) {
    return targetTimelock.delay();
  }

  function setUp() public override {
    targetTimelock = new MockTimelockTargetCompound();
    rollbackManager = _deployRollbackManager(
      address(targetTimelock), admin, guardian, rollbackQueueableDuration, minRollbackQueueableDuration
    );
  }
}

contract Constructor is ConstructorBase, RollbackManagerTimelockCompoundTest {}

contract GetRollback is GetRollbackBase, RollbackManagerTimelockCompoundTest {}

contract Propose is ProposeBase, RollbackManagerTimelockCompoundTest {}

contract Queue is QueueBase, RollbackManagerTimelockCompoundTest {
  function testFuzz_ForwardsToTimelockWhenGuardian(
    uint256 _delay,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _proposeRollback(_targets, _values, _calldatas, _description);

    _delay = bound(_delay, 0, rollbackQueueableDuration - 1);
    vm.warp(block.timestamp + _delay);

    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    MockTimelockTargetCompound.TimelockTransactionCall[] memory _lastQueueTransactionCalls =
      targetTimelock.lastParam__queueTransactions__();

    assertEq(_lastQueueTransactionCalls.length, _targets.length);

    for (uint256 i = 0; i < _targets.length; i++) {
      assertEq(_lastQueueTransactionCalls[i].target, _targets[i]);
      assertEq(_lastQueueTransactionCalls[i].value, _values[i]);
      assertEq(_lastQueueTransactionCalls[i].signature, "");
      assertEq(_lastQueueTransactionCalls[i].data, _calldatas[i]);
      assertEq(_lastQueueTransactionCalls[i].eta, block.timestamp + _timelockDelay());
    }
  }
}

contract Cancel is CancelBase, RollbackManagerTimelockCompoundTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external virtual override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _queueRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    MockTimelockTargetCompound.TimelockTransactionCall[] memory _lastCancelTransactionCalls =
      targetTimelock.lastParam__cancelTransactions__();

    assertEq(_lastCancelTransactionCalls.length, _targets.length);

    for (uint256 i = 0; i < _targets.length; i++) {
      assertEq(_lastCancelTransactionCalls[i].target, _targets[i]);
      assertEq(_lastCancelTransactionCalls[i].value, _values[i]);
      assertEq(_lastCancelTransactionCalls[i].signature, "");
      assertEq(_lastCancelTransactionCalls[i].data, _calldatas[i]);
      assertEq(_lastCancelTransactionCalls[i].eta, block.timestamp + targetTimelock.delay());
    }
  }
}

contract Execute is ExecuteBase, RollbackManagerTimelockCompoundTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _queueRollback(_targets, _values, _calldatas, _description);

    uint256 _eta = block.timestamp + targetTimelock.delay();

    vm.warp(_eta);
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    MockTimelockTargetCompound.TimelockTransactionCall[] memory _lastExecuteTransactionCalls =
      targetTimelock.lastParam__executeTransactions__();

    assertEq(_lastExecuteTransactionCalls.length, _targets.length);

    for (uint256 i = 0; i < _targets.length; i++) {
      assertEq(_lastExecuteTransactionCalls[i].target, _targets[i]);
      assertEq(_lastExecuteTransactionCalls[i].value, _values[i]);
      assertEq(_lastExecuteTransactionCalls[i].signature, "");
      assertEq(_lastExecuteTransactionCalls[i].data, _calldatas[i]);
      assertEq(_lastExecuteTransactionCalls[i].eta, _eta);
    }
  }

  function testFuzz_WillExecuteARollbackWithinTheGracePeriod(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    // Propose a rollback
    vm.prank(admin);
    uint256 rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);

    // Queue the rollback
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    // Bound time offset to be within grace period (after executable time but before grace period expires)
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _timeOffset = bound(_timeOffset, _timelockDelay(), _timelockDelay() + gracePeriod - 1);

    // Fast forward to executable time within grace period
    vm.warp(block.timestamp + _timeOffset);

    // Should be in Queued state (within grace period)
    assertEq(uint8(rollbackManager.state(rollbackId)), uint8(IGovernor.ProposalState.Queued));

    // Execute should succeed
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertWhen_TheGracePeriodHasElapsed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    // Propose a rollback
    vm.prank(admin);
    uint256 rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);

    // Queue the rollback
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    // Bound time offset to be after grace period expires
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _timeOffset =
      bound(_timeOffset, _timelockDelay() + gracePeriod + 1, _timelockDelay() + gracePeriod + 365 days * 100);

    // Fast forward past grace period
    vm.warp(block.timestamp + _timeOffset);

    // Should be in Expired state (past grace period)
    assertEq(uint8(rollbackManager.state(rollbackId)), uint8(IGovernor.ProposalState.Expired));

    // Execute should revert because state is not Queued
    vm.prank(guardian);
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueued.selector, rollbackId));
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }
}

contract State is StateBase, RollbackManagerTimelockCompoundTest {
  // Override the base test to account for Compound's grace period
  function testFuzz_QueuedRollbackStateAfterExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be within grace period (after executable time and including grace period boundary)
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _timeOffset = bound(_timeOffset, _timelockDelay(), _timelockDelay() + gracePeriod);

    // Warp to a time after the executable duration but within grace period
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Queued));
  }

  // Test that rollbacks properly expire after grace period for Compound timelocks
  function testFuzz_ExpiredRollbackStateAfterGracePeriod(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be after grace period expires
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _timeOffset =
      bound(_timeOffset, _timelockDelay() + gracePeriod + 1, _timelockDelay() + gracePeriod + 365 days * 100);

    // Warp to a time after the grace period has expired
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Expired));
  }
}

contract IsRollbackExecutable is IsRollbackExecutableBase, RollbackManagerTimelockCompoundTest {
  // Override the base test to account for Compound's grace period
  function testFuzz_ReturnsTrueForQueuedRollbackAfterDelay(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _delayAfterQueuing
  ) external override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound the delay to be within the grace period (after timelock delay and including grace period boundary)
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _delayAfterQueuing = bound(_delayAfterQueuing, _timelockDelay(), _timelockDelay() + gracePeriod);
    vm.warp(block.timestamp + _delayAfterQueuing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertTrue(_isExecutable);
  }

  // Test that rollbacks are not executable after grace period expires for Compound timelocks
  function testFuzz_ReturnsFalseForQueuedRollbackAfterGracePeriod(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _delayAfterQueuing
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound the delay to be after grace period expires (use large bound to catch overflow bugs)
    uint256 gracePeriod = targetTimelock.GRACE_PERIOD();
    _delayAfterQueuing =
      bound(_delayAfterQueuing, _timelockDelay() + gracePeriod + 1, _timelockDelay() + gracePeriod + 365 days * 100);
    vm.warp(block.timestamp + _delayAfterQueuing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }
}

contract SetGuardian is SetGuardianBase, RollbackManagerTimelockCompoundTest {}

contract SetRollbackQueueableDuration is SetRollbackQueueableDurationBase, RollbackManagerTimelockCompoundTest {}

contract SetAdmin is SetAdminBase, RollbackManagerTimelockCompoundTest {}

contract GetRollbackId is GetRollbackIdBase, RollbackManagerTimelockCompoundTest {
  function _getExpectedRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal pure override returns (uint256) {
    return uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description)));
  }
}
