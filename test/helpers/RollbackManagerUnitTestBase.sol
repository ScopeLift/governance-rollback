// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {RollbackManager, Rollback, IGovernor} from "src/RollbackManager.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {MockTimelockTargetControl} from "test/mocks/MockTimelockTargetControl.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";

/// @title Base contract for Rollback Manager unit tests
/// @notice Contains common setup and helper functions for both RollbackManagerTimelockControl and
/// RollbackManagerTimelockCompound
/// @dev This base contract reduces code duplication between the two unit test suites
abstract contract RollbackManagerUnitTestBase is Test {
  RollbackManager public rollbackManager;

  address public guardian = makeAddr("guardian");
  address public admin = makeAddr("admin");
  uint256 public rollbackQueueableDuration = 1 days;
  uint256 public minRollbackQueueableDuration = 5 minutes;

  // Abstract functions that must be implemented by child contracts
  function _getRollbackManagerType() internal view virtual returns (RollbackManager);
  function _deployRollbackManager(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal virtual returns (RollbackManager);

  function setUp() public virtual;
  // Child classes should override this method and call _deployRollbackManager with their specific mock timelock

  /*///////////////////////////////////////////////////////////////
                      Common Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _assumeSafeAdmin(address _admin) internal pure {
    vm.assume(_admin != address(0));
  }

  function _assumeSafeGuardian(address _guardian) internal pure {
    vm.assume(_guardian != address(0));
  }

  function _assumeSafeTargetTimelock(address _targetTimelock) internal pure {
    vm.assume(_targetTimelock != address(0));
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
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal pure returns (uint256, uint256) {
    _assumeSafeTargetTimelock(_targetTimelock);
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
    _rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);
  }

  function _queueRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    _proposeRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    _rollbackId = rollbackManager.queue(_targets, _values, _calldatas, _description);
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

  function _timelockDelay() internal view virtual returns (uint256);
}

abstract contract ConstructorBase is RollbackManagerUnitTestBase {
  function testFuzz_SetsInitialParameters(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    RollbackManager _rollbackManager = _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    assertEq(address(_rollbackManager.TARGET_TIMELOCK()), _targetTimelock);
    assertEq(_rollbackManager.MIN_ROLLBACK_QUEUEABLE_DURATION(), _minRollbackQueueableDuration);
    assertEq(_rollbackManager.admin(), _admin);
    assertEq(_rollbackManager.guardian(), _guardian);
    assertEq(_rollbackManager.rollbackQueueableDuration(), _rollbackQueueableDuration);
  }

  function testFuzz_EmitsRollbackQueueableDurationSet(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit RollbackManager.RollbackQueueableDurationSet(0, _rollbackQueueableDuration);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_EmitsGuardianSet(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit RollbackManager.GuardianSet(address(0), _guardian);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_TargetTimelockIsZeroAddress(
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

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(address(0), _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration);
  }

  function testFuzz_RevertIf_AdminIsZeroAddress(
    address _targetTimelock,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(
      _targetTimelock, address(0), _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_GuardianIsZeroAddress(
    address _targetTimelock,
    address _admin,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeAdmin(_admin);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(
      _targetTimelock, _admin, address(0), _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_DurationLessThanMin(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);

    // The rollback queueable duration is bound to be less than the min rollback queueable duration.
    uint256 _invalidRollbackQueueableDuration = bound(_rollbackQueueableDuration, 0, _minRollbackQueueableDuration - 1);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidRollbackQueueableDuration.selector);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _invalidRollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_MinRollbackQueueableDurationIsZero(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
    vm.expectRevert(RollbackManager.RollbackManager__InvalidRollbackQueueableDuration.selector);
    _deployRollbackManager(_targetTimelock, _admin, _guardian, _rollbackQueueableDuration, 0);
  }
}

abstract contract GetRollbackBase is RollbackManagerUnitTestBase {
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

abstract contract ProposeBase is RollbackManagerUnitTestBase {
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

  function testFuzz_SetsStateToPending(
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

abstract contract QueueBase is RollbackManagerUnitTestBase {
  function testFuzz_ForwardsToTimelockWhenGuardian(
    uint256 _delay,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external virtual;

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
    assertEq(_rollback.executableAt, block.timestamp + _timelockDelay());
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
    emit RollbackManager.RollbackQueued(_rollbackId, block.timestamp + _timelockDelay());

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

abstract contract CancelBase is RollbackManagerUnitTestBase {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external virtual;

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
    assertEq(_rollback.executableAt, block.timestamp + _timelockDelay());
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
    vm.warp(block.timestamp + _timelockDelay());
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
