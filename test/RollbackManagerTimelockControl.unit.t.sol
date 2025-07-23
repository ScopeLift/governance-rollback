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

  function setUp() public override {
    targetTimelock = new MockTimelockTargetControl();
    rollbackManager = _deployRollbackManager(
      address(targetTimelock), admin, guardian, rollbackQueueableDuration, minRollbackQueueableDuration
    );
  }
}

contract Constructor is ConstructorBase, RollbackManagerTimelockControlTest {}

contract GetRollback is RollbackManagerTimelockControlTest {
  function testFuzz_ReturnsTheRollbackData(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _proposeRollback(_targets, _values, _calldatas, _description);

    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);
    uint256 _rollbackQueueableDuration = rollbackManager.rollbackQueueableDuration();

    Rollback memory _rollback = rollbackManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + _rollbackQueueableDuration);
    assertEq(_rollback.executableAt, 0);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
  }
}

contract Propose is RollbackManagerTimelockControlTest {
  function testFuzz_AdminProposeRollbackReturnsId(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    uint256 _rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);

    assertEq(_rollbackId, _computedRollbackId);
  }

  function testFuzz_EmitsRollbackProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit RollbackManager.RollbackProposed(
      _computedRollbackId, block.timestamp + rollbackQueueableDuration, _targets, _values, _calldatas, _description
    );

    vm.prank(admin);
    rollbackManager.propose(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    rollbackManager.propose(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = rollbackManager.getRollback(_computedRollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + rollbackQueueableDuration);
    assertEq(_rollback.executableAt, 0);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
  }

  function testFuzz_SetsTheProposalStateToPending(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    rollbackManager.propose(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_computedRollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Pending));
  }

  function testFuzz_SetsExpirationTimeBasedOnDuration(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _rollbackQueueableDuration
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, minRollbackQueueableDuration);

    vm.startPrank(admin);
    // Set the rollback queueable duration to the new value.
    rollbackManager.setRollbackQueueableDuration(_rollbackQueueableDuration);
    uint256 _rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);
    vm.stopPrank();

    assertEq(rollbackManager.getRollback(_rollbackId).queueExpiresAt, block.timestamp + _rollbackQueueableDuration);
  }

  function testFuzz_RevertIf_RollbackAlreadyExists(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.startPrank(admin);
    uint256 _rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__AlreadyExists.selector, _rollbackId));
    rollbackManager.propose(_targets, _values, _calldatas, _description);
    vm.stopPrank();
  }

  function testFuzz_RevertIf_MismatchedParameters(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256[] memory _valuesMismatch = new uint256[](1);
    bytes[] memory _calldatasMismatch = new bytes[](1);

    vm.startPrank(admin);

    // target and values length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.propose(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.propose(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(
    address _caller,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    vm.assume(_caller != admin);

    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.propose(_targets, _values, _calldatas, _description);
  }
}

contract Queue is RollbackManagerTimelockControlTest {
  function testFuzz_ForwardsToTimelockWhenGuardian(
    uint256 _delay,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
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
    assertEq(_lastScheduleBatchCall.delay, targetTimelock.getMinDelay());

    // Check that the salt is correctly computed (should match RollbackManagerTimelockControl's _timelockSalt)
    bytes32 expectedSalt = bytes20(address(rollbackManager)) ^ keccak256(bytes(_description));
    assertEq(_lastScheduleBatchCall.salt, expectedSalt);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    uint256 _queueExpiresAtBeforeQueuing = rollbackManager.getRollback(_rollbackId).queueExpiresAt;

    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = rollbackManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, _queueExpiresAtBeforeQueuing);
    assertEq(_rollback.executableAt, block.timestamp + targetTimelock.getMinDelay());
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
  }

  function testFuzz_SetsStateToQueued(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Queued));
  }

  function testFuzz_EmitsRollbackQueued(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit RollbackManager.RollbackQueued(_rollbackId, block.timestamp + targetTimelock.getMinDelay());

    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_CallerIsNotGuardian(
    address _caller,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.assume(_caller != guardian);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackDoesNotExist(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NonExistentRollback.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackIsAlreadyQueued(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueueable.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_QueueRollbackExpires(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeAfterExpiry
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in pending state
    IGovernor.ProposalState _initialState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Pending));

    // Warp to exactly when the rollback queue duration expires
    vm.warp(block.timestamp + rollbackQueueableDuration);

    // Verify the rollback is now in expired state
    IGovernor.ProposalState _expiredState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_expiredState), uint8(IGovernor.ProposalState.Expired));

    // Try to queue the expired rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__Expired.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);

    // Warp further into the future and try again
    _timeAfterExpiry = bound(_timeAfterExpiry, 1, 365 days);
    vm.warp(block.timestamp + _timeAfterExpiry);

    // Should still revert with the same error
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__Expired.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_MismatchedParameters(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256[] memory _valuesMismatch = new uint256[](1);
    bytes[] memory _calldatasMismatch = new bytes[](1);

    vm.startPrank(guardian);
    // target and values length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.queue(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.queue(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
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

  function testFuzz_EmitsRollbackCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit RollbackManager.RollbackCanceled(_rollbackId);

    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = rollbackManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + rollbackQueueableDuration);
    assertEq(_rollback.executableAt, block.timestamp + targetTimelock.getMinDelay());
    assertEq(_rollback.canceled, true);
    assertEq(_rollback.executed, false);
  }

  function testFuzz_SetsStateToCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Canceled));
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(RollbackManager.RollbackManager__NonExistentRollback.selector, _computedRollbackId)
    );
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackWasAlreadyCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_CancelExecutedRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    IGovernor.ProposalState _initialState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Warp to after the execution time and execute the rollback
    vm.warp(block.timestamp + targetTimelock.getMinDelay());
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in executed state
    IGovernor.ProposalState _executedState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_executedState), uint8(IGovernor.ProposalState.Executed));

    // Try to cancel the executed rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in executed state after the failed cancel attempt
    IGovernor.ProposalState _finalState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_finalState), uint8(IGovernor.ProposalState.Executed));
  }

  function testFuzz_RevertIf_CallerIsNotGuardian(
    address _caller,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    vm.assume(_caller != guardian);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_MismatchedParameters(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256[] memory _valuesMismatch = new uint256[](1);
    bytes[] memory _calldatasMismatch = new bytes[](1);

    vm.startPrank(guardian);
    // target and values length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.cancel(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.cancel(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract Execute is RollbackManagerTimelockControlTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
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

  function testFuzz_EmitsRollbackExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit RollbackManager.RollbackExecuted(_rollbackId);

    vm.warp(block.timestamp + targetTimelock.getMinDelay());
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    uint256 _queueExpiresAt = rollbackManager.getRollback(_rollbackId).queueExpiresAt;
    uint256 _executableAt = rollbackManager.getRollback(_rollbackId).executableAt;

    vm.warp(_queueExpiresAt);
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = rollbackManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, _queueExpiresAt);
    assertEq(_rollback.executableAt, _executableAt);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, true);
  }

  function testFuzz_SetsStateToExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + targetTimelock.getMinDelay());
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Executed));
  }

  function testFuzz_RevertIf_RollbackExecutionEtaHasNotPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + targetTimelock.getMinDelay() - 1);
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__ExecutionTooEarly.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + targetTimelock.getMinDelay());

    vm.expectRevert(
      abi.encodeWithSelector(RollbackManager.RollbackManager__NonExistentRollback.selector, _computedRollbackId)
    );
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_ExecuteCanceledRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    IGovernor.ProposalState _initialState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Cancel the rollback
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in canceled state
    IGovernor.ProposalState _canceledState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_canceledState), uint8(IGovernor.ProposalState.Canceled));

    // Warp to after the execution time would have been
    vm.warp(block.timestamp + targetTimelock.getMinDelay());

    // Try to execute the canceled rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in canceled state after the failed execution attempt
    IGovernor.ProposalState _finalState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_finalState), uint8(IGovernor.ProposalState.Canceled));
  }

  function testFuzz_RevertIf_RollbackWasAlreadyExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + targetTimelock.getMinDelay());
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_CallerIsNotGuardian(
    address _caller,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    vm.assume(_caller != guardian);

    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    vm.prank(_caller);
    rollbackManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_MismatchedParameters(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256[] memory _valuesMismatch = new uint256[](1);
    bytes[] memory _calldatasMismatch = new bytes[](1);

    _queueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + targetTimelock.getMinDelay());

    vm.startPrank(guardian);
    // target and values length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.execute(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(RollbackManager.RollbackManager__MismatchedParameters.selector);
    rollbackManager.execute(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract State is RollbackManagerTimelockControlTest {
  function testFuzz_PendingWithinQueueWindow(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    // Bound time offset to be within the rollback queue duration
    _timeOffset = bound(_timeOffset, 0, rollbackQueueableDuration - 1);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Warp to a time within the expiry duration
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Pending));
  }

  function testFuzz_ExpiredAfterQueueWindow(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    // Bound time offset to be after the rollback queue duration
    _timeOffset = bound(_timeOffset, rollbackQueueableDuration, rollbackQueueableDuration + 30 days);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Warp to a time after the rollback queue duration
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Expired));
  }

  function testFuzz_ExpiredAtExactBoundary(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in pending state
    IGovernor.ProposalState _initialState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Pending));

    // Warp to exactly when the rollback queue duration expires
    vm.warp(block.timestamp + rollbackQueueableDuration);

    // Verify the rollback is now in expired state at the exact boundary
    IGovernor.ProposalState _exactExpirationState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_exactExpirationState), uint8(IGovernor.ProposalState.Expired));

    // Warp 1 second before expiration to verify it's still pending
    vm.warp(block.timestamp - rollbackQueueableDuration + rollbackQueueableDuration - 1);
    IGovernor.ProposalState _beforeExpirationState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_beforeExpirationState), uint8(IGovernor.ProposalState.Pending));

    // Warp back to exact expiration time
    vm.warp(block.timestamp + 1);
    IGovernor.ProposalState _atExpirationState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_atExpirationState), uint8(IGovernor.ProposalState.Expired));
  }

  function testFuzz_QueuedBeforeExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be before the executable time
    _timeOffset = bound(_timeOffset, 0, targetTimelock.getMinDelay() - 1);

    // Warp to a time before the executable duration
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Queued));
  }

  function testFuzz_QueuedRollbackStateAfterExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be after the executable time
    _timeOffset = bound(_timeOffset, targetTimelock.getMinDelay(), targetTimelock.getMinDelay() + 30 days);

    // Warp to a time after the executable duration
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Queued));
  }

  function testFuzz_QueuedAtExactExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    IGovernor.ProposalState _initialState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Warp to exactly when the execution time arrives
    vm.warp(block.timestamp + targetTimelock.getMinDelay());

    // Verify the rollback is now in queued state at the exact boundary
    IGovernor.ProposalState _exactExecutionState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_exactExecutionState), uint8(IGovernor.ProposalState.Queued));

    // Warp 1 second before execution time to verify it's still queued
    vm.warp(block.timestamp - 1);
    IGovernor.ProposalState _beforeExecutionState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_beforeExecutionState), uint8(IGovernor.ProposalState.Queued));

    // Warp back to exact execution time
    vm.warp(block.timestamp + 2);
    IGovernor.ProposalState _atExecutionState = rollbackManager.state(_rollbackId);
    assertEq(uint8(_atExecutionState), uint8(IGovernor.ProposalState.Queued));
  }

  function testFuzz_ExecutedState(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Warp to executable time
    vm.warp(block.timestamp + targetTimelock.getMinDelay());

    // Execute the rollback
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Executed));
  }

  function testFuzz_CanceledState(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Cancel the rollback
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = rollbackManager.state(_rollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Canceled));
  }

  function testFuzz_RevertIf_RollbackDoesNotExist(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NonExistentRollback.selector, _rollbackId));
    rollbackManager.state(_rollbackId);
  }
}

contract IsRollbackExecutable is RollbackManagerTimelockControlTest {
  function testFuzz_RevertIf_RollbackDoesNotExist(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__NonExistentRollback.selector, _rollbackId));
    rollbackManager.isRollbackExecutable(_rollbackId);
  }

  function testFuzz_ReturnsFalseForPendingRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }

  function testFuzz_ReturnsFalseForCanceledRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Cancel the rollback
    vm.prank(guardian);
    rollbackManager.cancel(_targets, _values, _calldatas, _description);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }

  function testFuzz_ReturnsFalseForExecutedRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Warp to executable time and execute
    vm.warp(block.timestamp + targetTimelock.getMinDelay());
    vm.prank(guardian);
    rollbackManager.execute(_targets, _values, _calldatas, _description);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }

  function testFuzz_ReturnsFalseForExpiredRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _delayAfterProposing
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Bound the delay to be at least the rollback queueable duration
    _delayAfterProposing = bound(_delayAfterProposing, rollbackQueueableDuration, 365 days * 100);
    vm.warp(block.timestamp + _delayAfterProposing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }

  function testFuzz_ReturnsFalseForQueuedRollbackBeforeDelay(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _delayAfterQueuing
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound the delay to be before the timelock delay
    _delayAfterQueuing = bound(_delayAfterQueuing, 0, targetTimelock.getMinDelay() - 1);
    vm.warp(block.timestamp + _delayAfterQueuing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertFalse(_isExecutable);
  }

  function testFuzz_ReturnsTrueForQueuedRollbackAfterDelay(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _delayAfterQueuing
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _queueRollback(_targets, _values, _calldatas, _description);

    // Bound the delay to be at least the timelock delay
    _delayAfterQueuing = bound(_delayAfterQueuing, targetTimelock.getMinDelay(), 365 days * 100);
    vm.warp(block.timestamp + _delayAfterQueuing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertTrue(_isExecutable);
  }
}

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
