// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {RollbackManager} from "src/RollbackManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Rollback} from "src/interfaces/IRollbackManager.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockTimelockTargetControl} from "test/mocks/MockTimelockTargetControl.sol";
import "test/helpers/RollbackManagerUnitTestBase.sol";

contract RollbackManagerTimelockControlTest is RollbackManagerUnitTestBase {
  MockTimelockTargetControl public targetTimelock;

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
    return new RollbackManagerTimelockControl(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function _timelockDelay() internal view override returns (uint256) {
    return targetTimelock.getMinDelay();
  }

  function setUp() public override {
    targetTimelock = new MockTimelockTargetControl();
    rollbackManager = _deployRollbackManager(
      address(targetTimelock), admin, guardian, rollbackQueueableDuration, minRollbackQueueableDuration
    );
  }
}

contract Constructor is ConstructorBase, RollbackManagerTimelockControlTest {}

contract GetRollback is GetRollbackBase, RollbackManagerTimelockControlTest {}

contract Propose is ProposeBase, RollbackManagerTimelockControlTest {}

contract Queue is QueueBase, RollbackManagerTimelockControlTest {
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

    MockTimelockTargetControl.BatchCall memory _lastScheduleBatchCall = targetTimelock.lastParam__scheduleBatch__();

    // Check that scheduleBatch was called
    assertTrue(_lastScheduleBatchCall.called);

    // Check that the targets array matches
    assertEq(_lastScheduleBatchCall.targets.length, _targets.length);
    for (uint256 i = 0; i < _targets.length; i++) {
      assertEq(_lastScheduleBatchCall.targets[i], _targets[i]);
    }

    // Check that the values array matches
    assertEq(_lastScheduleBatchCall.values.length, _values.length);
    for (uint256 i = 0; i < _values.length; i++) {
      assertEq(_lastScheduleBatchCall.values[i], _values[i]);
    }

    // Check that the calldatas array matches
    assertEq(_lastScheduleBatchCall.calldatas.length, _calldatas.length);
    for (uint256 i = 0; i < _calldatas.length; i++) {
      assertEq(_lastScheduleBatchCall.calldatas[i], _calldatas[i]);
    }

    // Check OZ-specific parameters
    assertEq(_lastScheduleBatchCall.predecessor, bytes32(0));
    assertEq(_lastScheduleBatchCall.delay, _timelockDelay());

    // Check that the salt is correctly computed (should match RollbackManagerTimelockControl's _timelockSalt)
    bytes32 expectedSalt = bytes20(address(rollbackManager)) ^ keccak256(bytes(_description));
    assertEq(_lastScheduleBatchCall.salt, expectedSalt);
  }
}

contract Cancel is RollbackManagerTimelockControlTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _queueRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    bytes32 _salt = bytes20(address(rollbackManager)) ^ keccak256(bytes(_description));

    bytes32 _rollbackId = targetTimelock.hashOperationBatch(_targets, _values, _calldatas, 0, _salt);
    MockTimelockTargetControl.CancelCall memory _lastCancelCall = targetTimelock.lastParam__cancel__();

    assertTrue(_lastCancelCall.called);
    assertEq(_lastCancelCall.rollbackId, _rollbackId);
  }
}

contract Execute is ExecuteBase, RollbackManagerTimelockControlTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external override {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _queueRollback(_targets, _values, _calldatas, _description);

    uint256 _eta = block.timestamp + targetTimelock.getMinDelay();

    vm.warp(_eta);
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    MockTimelockTargetControl.ExecuteBatchCall memory _lastExecuteBatchCall = targetTimelock.lastParam__executeBatch__();

    bytes32 _salt = bytes20(address(rollbackManager)) ^ keccak256(bytes(_description));

    assertTrue(_lastExecuteBatchCall.called);
    assertEq(_lastExecuteBatchCall.targets.length, _targets.length);
    assertEq(_lastExecuteBatchCall.values.length, _values.length);
    assertEq(_lastExecuteBatchCall.calldatas.length, _calldatas.length);
    assertEq(_lastExecuteBatchCall.predecessor, bytes32(0));
    assertEq(_lastExecuteBatchCall.salt, _salt);
    assertEq(_lastExecuteBatchCall.valueSent, 0);

    for (uint256 i = 0; i < _targets.length; i++) {
      assertEq(_lastExecuteBatchCall.targets[i], _targets[i]);
      assertEq(_lastExecuteBatchCall.values[i], _values[i]);
      assertEq(_lastExecuteBatchCall.calldatas[i], _calldatas[i]);
    }
  }
}

contract State is StateBase, RollbackManagerTimelockControlTest {}

contract IsRollbackExecutable is IsRollbackExecutableBase, RollbackManagerTimelockControlTest {}

contract SetGuardian is RollbackManagerTimelockControlTest {
  function test_SetsGuardian(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.prank(admin);
    rollbackManager.setGuardian(_newGuardian);

    assertEq(rollbackManager.guardian(), _newGuardian);
  }

  function testFuzz_EmitsGuardianSet(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.expectEmit();
    emit RollbackManager.GuardianSet(guardian, _newGuardian);
    vm.prank(admin);
    rollbackManager.setGuardian(_newGuardian);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);
    vm.assume(_caller != admin);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.setGuardian(_newGuardian);
  }

  function test_RevertIf_NewGuardianIsZeroAddress() external {
    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    vm.prank(admin);
    rollbackManager.setGuardian(address(0));
  }
}

contract SetRollbackQueueableDuration is RollbackManagerTimelockControlTest {
  function test_SetsRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) external {
    _newRollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_newRollbackQueueableDuration, minRollbackQueueableDuration);

    vm.prank(admin);
    rollbackManager.setRollbackQueueableDuration(_newRollbackQueueableDuration);

    assertEq(rollbackManager.rollbackQueueableDuration(), _newRollbackQueueableDuration);
  }

  function testFuzz_EmitsRollbackQueueableDurationSet(uint256 _newRollbackQueueableDuration) external {
    _newRollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_newRollbackQueueableDuration, minRollbackQueueableDuration);

    vm.expectEmit();
    emit RollbackManager.RollbackQueueableDurationSet(rollbackQueueableDuration, _newRollbackQueueableDuration);
    vm.prank(admin);
    rollbackManager.setRollbackQueueableDuration(_newRollbackQueueableDuration);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, uint256 _newRollbackQueueableDuration) external {
    vm.assume(_caller != admin);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.setRollbackQueueableDuration(_newRollbackQueueableDuration);
  }

  function test_RevertIf_NewRollbackQueueableDurationIsLessThanMinRollbackQueueableDuration(
    uint256 _newRollbackQueueableDuration
  ) external {
    uint256 _invalidRollbackQueueableDuration =
      bound(_newRollbackQueueableDuration, 0, minRollbackQueueableDuration - 1);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidRollbackQueueableDuration.selector);
    vm.prank(admin);
    rollbackManager.setRollbackQueueableDuration(_invalidRollbackQueueableDuration);
  }
}

contract SetAdmin is RollbackManagerTimelockControlTest {
  function test_SetsAdmin(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.prank(admin);
    rollbackManager.setAdmin(_newAdmin);

    assertEq(rollbackManager.admin(), _newAdmin);
  }

  function testFuzz_EmitsAdminSet(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.expectEmit();
    emit RollbackManager.AdminSet(admin, _newAdmin);
    vm.prank(admin);
    rollbackManager.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    vm.assume(_caller != admin);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.setAdmin(_newAdmin);
  }

  function test_RevertIf_NewAdminIsZeroAddress() external {
    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    vm.prank(admin);
    rollbackManager.setAdmin(address(0));
  }
}

contract GetRollbackId is RollbackManagerTimelockControlTest {
  function test_ReturnsRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view {
    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    // The RollbackManagerTimelockControl uses the timelock's hashOperationBatch method
    bytes32 _salt = bytes20(address(rollbackManager)) ^ keccak256(bytes(_description));
    bytes32 expectedRollbackId = targetTimelock.hashOperationBatch(_targets, _values, _calldatas, 0, _salt);

    assertEq(_rollbackId, uint256(expectedRollbackId));
  }
}
