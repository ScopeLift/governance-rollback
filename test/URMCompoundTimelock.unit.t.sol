// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {URMCompoundTimelock} from "src/contracts/urm/URMCompoundTimelock.sol";
import {URMCore} from "src/contracts/URMCore.sol";
import {Rollback, ProposalState} from "src/types/GovernanceTypes.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockCompoundTimelockTarget} from "test/mocks/MockCompoundTimelockTarget.sol";

contract URMCompoundTimelockTest is Test {
  URMCompoundTimelock public urm;

  MockCompoundTimelockTarget public timelockTarget;

  address public guardian = makeAddr("guardian");
  address public admin = makeAddr("admin");
  uint256 public rollbackQueueableDuration = 1 days;
  uint256 public minRollbackQueueableDuration = 5 minutes;

  function setUp() external {
    timelockTarget = new MockCompoundTimelockTarget();
    urm = new URMCompoundTimelock(
      address(timelockTarget), admin, guardian, rollbackQueueableDuration, minRollbackQueueableDuration
    );
  }

  function _assumeSafeAdmin(address _admin) internal pure {
    vm.assume(_admin != address(0));
  }

  function _assumeSafeGuardian(address _guardian) internal pure {
    vm.assume(_guardian != address(0));
  }

  function _assumeSafeTimelockTarget(address _timelockTarget) internal pure {
    vm.assume(_timelockTarget != address(0));
  }

  function _boundToRealisticMinRollbackQueueableDuration(uint256 _minRollbackQueueableDuration)
    internal
    pure
    returns (uint256)
  {
    return bound(_minRollbackQueueableDuration, 1 hours, 20 days);
  }

  function _boundToRealisticRollbackQueueableDuration(
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal pure returns (uint256) {
    return bound(_rollbackQueueableDuration, _minRollbackQueueableDuration, 10 * 365 days);
  }

  function _assumeSafeInitParams(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal pure returns (uint256, uint256) {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    return (
      _minRollbackQueueableDuration,
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration)
    );
  }

  function _proposeRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    vm.prank(admin);
    _rollbackId = urm.propose(_targets, _values, _calldatas, _description);
  }

  function _proposeAndQueueRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    _proposeRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    _rollbackId = urm.queue(_targets, _values, _calldatas, _description);
  }

  function toDynamicArrays(
    address[2] memory _fixedTargets,
    uint256[2] memory _fixedValues,
    bytes[2] memory _fixedCalldatas
  ) internal pure returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
    targets = new address[](2);
    values = new uint256[](2);
    calldatas = new bytes[](2);

    for (uint256 _i = 0; _i < 2; _i++) {
      targets[_i] = _fixedTargets[_i];
      values[_i] = _fixedValues[_i];
      calldatas[_i] = _fixedCalldatas[_i];
    }
  }
}

contract Constructor is URMCompoundTimelockTest {
  function testFuzz_SetsInitialParameters(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    URMCompoundTimelock _urm = new URMCompoundTimelock(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    assertEq(address(_urm.TARGET_TIMELOCK()), _timelockTarget);
    assertEq(_urm.MIN_ROLLBACK_QUEUEABLE_DURATION(), _minRollbackQueueableDuration);
    assertEq(_urm.admin(), _admin);
    assertEq(_urm.guardian(), _guardian);
    assertEq(_urm.rollbackQueueableDuration(), _rollbackQueueableDuration);
  }

  function testFuzz_EmitsRollbackQueueableDurationSet(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit URMCore.RollbackQueueableDurationSet(0, _rollbackQueueableDuration);
    new URMCompoundTimelock(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_EmitsGuardianSet(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit URMCore.GuardianSet(address(0), _guardian);
    new URMCompoundTimelock(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_TimelockTargetIsZeroAddress(
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(URMCore.URM__InvalidAddress.selector);
    new URMCompoundTimelock(address(0), _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration);
  }

  function testFuzz_RevertIf_AdminIsZeroAddress(
    address _timelockTarget,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(URMCore.URM__InvalidAddress.selector);
    new URMCompoundTimelock(
      _timelockTarget, address(0), _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_GuardianIsZeroAddress(
    address _timelockTarget,
    address _admin,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(URMCore.URM__InvalidAddress.selector);
    new URMCompoundTimelock(
      _timelockTarget, _admin, address(0), _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_RollbackQueueableDurationIsLessThanMinRollbackQueueableDuration(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);

    // The rollback queueable duration is bound to be less than the min rollback queueable duration.
    uint256 _invalidRollbackQueueableDuration = bound(_rollbackQueueableDuration, 0, _minRollbackQueueableDuration - 1);

    vm.expectRevert(URMCore.URM__InvalidRollbackQueueableDuration.selector);
    new URMCompoundTimelock(
      _timelockTarget, _admin, _guardian, _invalidRollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_MinRollbackQueueableDurationIsZero(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _timelockTarget, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
    vm.expectRevert(URMCore.URM__InvalidRollbackQueueableDuration.selector);
    new URMCompoundTimelock(_timelockTarget, _admin, _guardian, _rollbackQueueableDuration, 0);
  }
}

contract GetRollback is URMCompoundTimelockTest {
  function testFuzz_ReturnsTheRollbackData(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _proposeRollback(_targets, _values, _calldatas, _description);

    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);
    uint256 _rollbackQueueableDuration = urm.rollbackQueueableDuration();

    Rollback memory _rollback = urm.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + _rollbackQueueableDuration);
    assertEq(_rollback.executableAt, 0);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
  }
}

contract Propose is URMCompoundTimelockTest {
  function testFuzz_AllowTheAdminToProposeARollbackAndReturnsTheRollbackId(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    uint256 _rollbackId = urm.propose(_targets, _values, _calldatas, _description);

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

    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit URMCore.RollbackProposed(
      _computedRollbackId, block.timestamp + rollbackQueueableDuration, _targets, _values, _calldatas, _description
    );

    vm.prank(admin);
    urm.propose(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    urm.propose(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = urm.getRollback(_computedRollbackId);

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

    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    urm.propose(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_computedRollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Pending));
  }

  function testFuzz_SetsTheExpirationTimeBasedOnRollbackQueueableDuration(
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
    urm.setRollbackQueueableDuration(_rollbackQueueableDuration);
    uint256 _rollbackId = urm.propose(_targets, _values, _calldatas, _description);
    vm.stopPrank();

    assertEq(urm.getRollback(_rollbackId).queueExpiresAt, block.timestamp + _rollbackQueueableDuration);
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
    uint256 _rollbackId = urm.propose(_targets, _values, _calldatas, _description);
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__AlreadyExists.selector, _rollbackId));
    urm.propose(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.propose(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.propose(_targets, _values, _calldatasMismatch, _description);

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

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.propose(_targets, _values, _calldatas, _description);
  }
}

contract Queue is URMCompoundTimelockTest {
  function testFuzz_ForwardsParametersToTimelockTargetWhenCallerIsGuardian(
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
    urm.queue(_targets, _values, _calldatas, _description);

    MockCompoundTimelockTarget.TimelockTransactionCall[] memory _lastQueueTransactionCalls =
      timelockTarget.lastParam__queueTransactions__();

    assertEq(_lastQueueTransactionCalls.length, 2);

    assertEq(_lastQueueTransactionCalls[0].target, _targets[0]);
    assertEq(_lastQueueTransactionCalls[0].value, _values[0]);
    assertEq(_lastQueueTransactionCalls[0].signature, "");
    assertEq(_lastQueueTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastQueueTransactionCalls[0].eta, block.timestamp + timelockTarget.delay());

    assertEq(_lastQueueTransactionCalls[1].target, _targets[1]);
    assertEq(_lastQueueTransactionCalls[1].value, _values[1]);
    assertEq(_lastQueueTransactionCalls[1].signature, "");
    assertEq(_lastQueueTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastQueueTransactionCalls[1].eta, block.timestamp + timelockTarget.delay());
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

    uint256 _queueExpiresAtBeforeQueuing = urm.getRollback(_rollbackId).queueExpiresAt;

    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = urm.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, _queueExpiresAtBeforeQueuing);
    assertEq(_rollback.executableAt, block.timestamp + timelockTarget.delay());
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
  }

  function testFuzz_SetsTheProposalStateToQueued(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Queued));
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
    emit URMCore.RollbackQueued(_rollbackId, block.timestamp + timelockTarget.delay());

    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);
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

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackDoesNotExist(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueueable.selector, _rollbackId));
    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);
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
    urm.queue(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueueable.selector, _rollbackId));
    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);
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
    ProposalState _initialState = urm.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(ProposalState.Pending));

    // Warp to exactly when the rollback queue duration expires
    vm.warp(block.timestamp + rollbackQueueableDuration);

    // Verify the rollback is now in expired state
    ProposalState _expiredState = urm.state(_rollbackId);
    assertEq(uint8(_expiredState), uint8(ProposalState.Expired));

    // Try to queue the expired rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__Expired.selector, _rollbackId));
    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);

    // Warp further into the future and try again
    _timeAfterExpiry = bound(_timeAfterExpiry, 1, 365 days);
    vm.warp(block.timestamp + _timeAfterExpiry);

    // Should still revert with the same error
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__Expired.selector, _rollbackId));
    vm.prank(guardian);
    urm.queue(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.queue(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.queue(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract Cancel is URMCompoundTimelockTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _proposeAndQueueRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    MockCompoundTimelockTarget.TimelockTransactionCall[] memory _lastCancelTransactionCalls =
      timelockTarget.lastParam__cancelTransactions__();

    assertEq(_lastCancelTransactionCalls.length, 2);

    assertEq(_lastCancelTransactionCalls[0].target, _targets[0]);
    assertEq(_lastCancelTransactionCalls[0].value, _values[0]);
    assertEq(_lastCancelTransactionCalls[0].signature, "");
    assertEq(_lastCancelTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastCancelTransactionCalls[0].eta, block.timestamp + timelockTarget.delay());

    assertEq(_lastCancelTransactionCalls[1].target, _targets[1]);
    assertEq(_lastCancelTransactionCalls[1].value, _values[1]);
    assertEq(_lastCancelTransactionCalls[1].signature, "");
    assertEq(_lastCancelTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastCancelTransactionCalls[1].eta, block.timestamp + timelockTarget.delay());
  }

  function testFuzz_EmitsRollbackCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit URMCore.RollbackCanceled(_rollbackId);

    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = urm.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + rollbackQueueableDuration);
    assertEq(_rollback.executableAt, block.timestamp + timelockTarget.delay());
    assertEq(_rollback.canceled, true);
    assertEq(_rollback.executed, false);
  }

  function testFuzz_SetsTheProposalStateToCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Canceled));
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _computedRollbackId));
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackWasAlreadyCanceled(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_CancelExecutedRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    ProposalState _initialState = urm.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(ProposalState.Queued));

    // Warp to after the execution time and execute the rollback
    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in executed state
    ProposalState _executedState = urm.state(_rollbackId);
    assertEq(uint8(_executedState), uint8(ProposalState.Executed));

    // Try to cancel the executed rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in executed state after the failed cancel attempt
    ProposalState _finalState = urm.state(_rollbackId);
    assertEq(uint8(_finalState), uint8(ProposalState.Executed));
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

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.cancel(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.cancel(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.cancel(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract Execute is URMCompoundTimelockTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    uint256 _eta = block.timestamp + timelockTarget.delay();

    vm.warp(_eta);
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    MockCompoundTimelockTarget.TimelockTransactionCall[] memory _lastExecuteTransactionCalls =
      timelockTarget.lastParam__executeTransactions__();

    assertEq(_lastExecuteTransactionCalls.length, 2);

    assertEq(_lastExecuteTransactionCalls[0].target, _targets[0]);
    assertEq(_lastExecuteTransactionCalls[0].value, _values[0]);
    assertEq(_lastExecuteTransactionCalls[0].signature, "");
    assertEq(_lastExecuteTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastExecuteTransactionCalls[0].eta, _eta);

    assertEq(_lastExecuteTransactionCalls[1].target, _targets[1]);
    assertEq(_lastExecuteTransactionCalls[1].value, _values[1]);
    assertEq(_lastExecuteTransactionCalls[1].signature, "");
    assertEq(_lastExecuteTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastExecuteTransactionCalls[1].eta, _eta);
  }

  function testFuzz_EmitsRollbackExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.expectEmit();
    emit URMCore.RollbackExecuted(_rollbackId);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    uint256 _queueExpiresAt = urm.getRollback(_rollbackId).queueExpiresAt;
    uint256 _executableAt = urm.getRollback(_rollbackId).executableAt;

    vm.warp(_queueExpiresAt);
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = urm.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, _queueExpiresAt);
    assertEq(_rollback.executableAt, _executableAt);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, true);
  }

  function testFuzz_SetsTheProposalStateToExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Executed));
  }

  function testFuzz_RevertIf_RollbackExecutionEtaHasNotPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay() - 1);
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__ExecutionTooEarly.selector, _rollbackId));
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _computedRollbackId));
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_ExecuteCanceledRollback(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    ProposalState _initialState = urm.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(ProposalState.Queued));

    // Cancel the rollback
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in canceled state
    ProposalState _canceledState = urm.state(_rollbackId);
    assertEq(uint8(_canceledState), uint8(ProposalState.Canceled));

    // Warp to after the execution time would have been
    vm.warp(block.timestamp + timelockTarget.delay());

    // Try to execute the canceled rollback - should revert with specific error
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in canceled state after the failed execution attempt
    ProposalState _finalState = urm.state(_rollbackId);
    assertEq(uint8(_finalState), uint8(ProposalState.Canceled));
  }

  function testFuzz_RevertIf_RollbackWasAlreadyExecuted(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__NotQueued.selector, _rollbackId));
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);
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

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.execute(_targets, _values, _calldatas, _description);
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

    _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());

    vm.startPrank(guardian);
    // target and values length mismatch
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.execute(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(URMCore.URM__MismatchedParameters.selector);
    urm.execute(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract State is URMCompoundTimelockTest {
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

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Pending));
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

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Expired));
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
    ProposalState _initialState = urm.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(ProposalState.Pending));

    // Warp to exactly when the rollback queue duration expires
    vm.warp(block.timestamp + rollbackQueueableDuration);

    // Verify the rollback is now in expired state at the exact boundary
    ProposalState _exactExpirationState = urm.state(_rollbackId);
    assertEq(uint8(_exactExpirationState), uint8(ProposalState.Expired));

    // Warp 1 second before expiration to verify it's still pending
    vm.warp(block.timestamp - rollbackQueueableDuration + rollbackQueueableDuration - 1);
    ProposalState _beforeExpirationState = urm.state(_rollbackId);
    assertEq(uint8(_beforeExpirationState), uint8(ProposalState.Pending));

    // Warp back to exact expiration time
    vm.warp(block.timestamp + 1);
    ProposalState _atExpirationState = urm.state(_rollbackId);
    assertEq(uint8(_atExpirationState), uint8(ProposalState.Expired));
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be before the executable time
    _timeOffset = bound(_timeOffset, 0, timelockTarget.delay() - 1);

    // Warp to a time before the executable duration
    vm.warp(block.timestamp + _timeOffset);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Queued));
  }

  function testFuzz_ActiveAfterExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be after the executable time
    _timeOffset = bound(_timeOffset, timelockTarget.delay(), timelockTarget.delay() + 30 days);

    // Warp to a time after the executable duration
    vm.warp(block.timestamp + _timeOffset);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Active));
  }

  function testFuzz_ActiveAtExactExecutionTime(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    ProposalState _initialState = urm.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(ProposalState.Queued));

    // Warp to exactly when the execution time arrives
    vm.warp(block.timestamp + timelockTarget.delay());

    // Verify the rollback is now in active state at the exact boundary
    ProposalState _exactExecutionState = urm.state(_rollbackId);
    assertEq(uint8(_exactExecutionState), uint8(ProposalState.Active));

    // Warp 1 second before execution time to verify it's still queued
    vm.warp(block.timestamp - timelockTarget.delay() + timelockTarget.delay() - 1);
    ProposalState _beforeExecutionState = urm.state(_rollbackId);
    assertEq(uint8(_beforeExecutionState), uint8(ProposalState.Queued));

    // Warp back to exact execution time
    vm.warp(block.timestamp + 1);
    ProposalState _atExecutionState = urm.state(_rollbackId);
    assertEq(uint8(_atExecutionState), uint8(ProposalState.Active));
  }

  function testFuzz_ExecutedState(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Warp to executable time
    vm.warp(block.timestamp + timelockTarget.delay());

    // Execute the rollback
    vm.prank(guardian);
    urm.execute(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Executed));
  }

  function testFuzz_CanceledState(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Cancel the rollback
    vm.prank(guardian);
    urm.cancel(_targets, _values, _calldatas, _description);

    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Canceled));
  }

  function testFuzz_UnknownState(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external view {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    // Check state without proposing
    ProposalState _state = urm.state(_rollbackId);
    assertEq(uint8(_state), uint8(ProposalState.Unknown));
  }
}

contract SetGuardian is URMCompoundTimelockTest {
  function test_SetsGuardian(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.prank(admin);
    urm.setGuardian(_newGuardian);

    assertEq(urm.guardian(), _newGuardian);
  }

  function testFuzz_EmitsGuardianSet(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.expectEmit();
    emit URMCore.GuardianSet(guardian, _newGuardian);
    vm.prank(admin);
    urm.setGuardian(_newGuardian);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);
    vm.assume(_caller != admin);

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.setGuardian(_newGuardian);
  }

  function test_RevertIf_NewGuardianIsZeroAddress() external {
    vm.expectRevert(URMCore.URM__InvalidAddress.selector);
    vm.prank(admin);
    urm.setGuardian(address(0));
  }
}

contract SetRollbackQueueableDuration is URMCompoundTimelockTest {
  function test_SetsRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) external {
    _newRollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_newRollbackQueueableDuration, minRollbackQueueableDuration);

    vm.prank(admin);
    urm.setRollbackQueueableDuration(_newRollbackQueueableDuration);

    assertEq(urm.rollbackQueueableDuration(), _newRollbackQueueableDuration);
  }

  function testFuzz_EmitsRollbackQueueableDurationSet(uint256 _newRollbackQueueableDuration) external {
    _newRollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_newRollbackQueueableDuration, minRollbackQueueableDuration);

    vm.expectEmit();
    emit URMCore.RollbackQueueableDurationSet(rollbackQueueableDuration, _newRollbackQueueableDuration);
    vm.prank(admin);
    urm.setRollbackQueueableDuration(_newRollbackQueueableDuration);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, uint256 _newRollbackQueueableDuration) external {
    vm.assume(_caller != admin);

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.setRollbackQueueableDuration(_newRollbackQueueableDuration);
  }

  function test_RevertIf_NewRollbackQueueableDurationIsLessThanMinRollbackQueueableDuration(
    uint256 _newRollbackQueueableDuration
  ) external {
    uint256 _invalidRollbackQueueableDuration =
      bound(_newRollbackQueueableDuration, 0, minRollbackQueueableDuration - 1);

    vm.expectRevert(URMCore.URM__InvalidRollbackQueueableDuration.selector);
    vm.prank(admin);
    urm.setRollbackQueueableDuration(_invalidRollbackQueueableDuration);
  }
}

contract SetAdmin is URMCompoundTimelockTest {
  function test_SetsAdmin(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.prank(admin);
    urm.setAdmin(_newAdmin);

    assertEq(urm.admin(), _newAdmin);
  }

  function testFuzz_EmitsAdminSet(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.expectEmit();
    emit URMCore.AdminSet(admin, _newAdmin);
    vm.prank(admin);
    urm.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    vm.assume(_caller != admin);

    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    vm.prank(_caller);
    urm.setAdmin(_newAdmin);
  }

  function test_RevertIf_NewAdminIsZeroAddress() external {
    vm.expectRevert(URMCore.URM__InvalidAddress.selector);
    vm.prank(admin);
    urm.setAdmin(address(0));
  }
}

contract GetRollbackId is URMCompoundTimelockTest {
  function test_ReturnsRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view {
    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, _description);

    assertEq(_rollbackId, uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description))));
  }
}
