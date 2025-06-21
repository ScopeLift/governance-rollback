// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {ITimelockTarget} from "src/interfaces/ITimelockTarget.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockTimelockTarget} from "test/mocks/MockTimelockTarget.sol";

contract UpgradeRegressionManagerTest is Test {
  UpgradeRegressionManager public upgradeRegressionManager;

  MockTimelockTarget public timelockTarget;

  address public guardian = makeAddr("guardian");
  address public admin = makeAddr("admin");
  uint256 public rollbackQueueWindow = 1 days;

  function setUp() external {
    timelockTarget = new MockTimelockTarget();
    upgradeRegressionManager = new UpgradeRegressionManager(timelockTarget, admin, guardian, rollbackQueueWindow);
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

  function _boundToRealisticRollbackQueueWindow(uint256 _rollbackQueueWindow) internal pure returns (uint256) {
    return bound(_rollbackQueueWindow, 1 hours, 20 days);
  }

  function _assumeSafeInitParams(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) internal pure returns (uint256) {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    return _boundToRealisticRollbackQueueWindow(_rollbackQueueWindow);
  }

  function _proposeRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    vm.prank(admin);
    _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
  }

  function _proposeAndQueueRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    _proposeRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    _rollbackId = upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
  }

  function toDynamicArrays(
    address[2] memory _fixedTargets,
    uint256[2] memory _fixedValues,
    bytes[2] memory _fixedCalldatas
  ) internal pure returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
    targets = new address[](2);
    values = new uint256[](2);
    calldatas = new bytes[](2);

    for (uint256 i = 0; i < 2; i++) {
      targets[i] = _fixedTargets[i];
      values[i] = _fixedValues[i];
      calldatas[i] = _fixedCalldatas[i];
    }
  }
}

contract Constructor is UpgradeRegressionManagerTest {
  function testFuzz_SetsIntializeParameters(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) external {
    _rollbackQueueWindow = _assumeSafeInitParams(_timelockTarget, _admin, _guardian, _rollbackQueueWindow);

    UpgradeRegressionManager _upgradeRegressionManager =
      new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), _admin, _guardian, _rollbackQueueWindow);

    assertEq(address(_upgradeRegressionManager.TARGET()), _timelockTarget);
    assertEq(_upgradeRegressionManager.admin(), _admin);
    assertEq(_upgradeRegressionManager.guardian(), _guardian);
    assertEq(_upgradeRegressionManager.rollbackQueueWindow(), _rollbackQueueWindow);
  }

  function testFuzz_EmitsRollbackQueueWindowSet(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) external {
    _rollbackQueueWindow = _assumeSafeInitParams(_timelockTarget, _admin, _guardian, _rollbackQueueWindow);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackQueueWindowSet(0, _rollbackQueueWindow);
    new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), _admin, _guardian, _rollbackQueueWindow);
  }

  function testFuzz_EmitsGuardianSet(
    address _timelockTarget,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) external {
    _rollbackQueueWindow = _assumeSafeInitParams(_timelockTarget, _admin, _guardian, _rollbackQueueWindow);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.GuardianSet(address(0), _guardian);
    new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), _admin, _guardian, _rollbackQueueWindow);
  }

  function testFuzz_RevertIf_TimelockTargetIsZeroAddress(
    address _admin,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) external {
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _rollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_rollbackQueueWindow);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidAddress.selector);
    new UpgradeRegressionManager(ITimelockTarget(address(0)), _admin, _guardian, _rollbackQueueWindow);
  }

  function testFuzz_RevertIf_AdminIsZeroAddress(
    address _timelockTarget,
    address _guardian,
    uint256 _rollbackQueueWindow
  ) external {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeGuardian(_guardian);
    _rollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_rollbackQueueWindow);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidAddress.selector);
    new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), address(0), _guardian, _rollbackQueueWindow);
  }

  function testFuzz_RevertIf_GuardianIsZeroAddress(
    address _timelockTarget,
    address _admin,
    uint256 _rollbackQueueWindow
  ) external {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _rollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_rollbackQueueWindow);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidAddress.selector);
    new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), _admin, address(0), _rollbackQueueWindow);
  }

  function testFuzz_RevertIf_RollbackQueueWindowIsZero(address _timelockTarget, address _admin, address _guardian)
    external
  {
    _assumeSafeTimelockTarget(_timelockTarget);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidRollbackQueueWindow.selector);
    new UpgradeRegressionManager(ITimelockTarget(_timelockTarget), _admin, _guardian, 0);
  }
}

contract Propose is UpgradeRegressionManagerTest {
  function testFuzz_AllowTheAdminToProposeARollbackAndReturnsTheRollbackId(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

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

    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackProposed(
      _computedRollbackId, block.timestamp + rollbackQueueWindow, _targets, _values, _calldatas, _description
    );

    vm.prank(admin);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
  }

  function testFuzz_AddsOnlyToRollbackQueue(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackQueueExpiresAt(_computedRollbackId), 0);

    vm.prank(admin);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    assertEq(
      upgradeRegressionManager.rollbackQueueExpiresAt(_computedRollbackId), block.timestamp + rollbackQueueWindow
    );
    assertEq(upgradeRegressionManager.rollbackExecutableAt(_computedRollbackId), 0);
  }

  function testFuzz_SetsTheExpirationTimeBasedOnRollbackQueueWindow(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _rollbackQueueWindow
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _rollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_rollbackQueueWindow);

    vm.startPrank(admin);
    // Set the rollback queue window to the new value.
    upgradeRegressionManager.setRollbackQueueWindow(_rollbackQueueWindow);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
    vm.stopPrank();

    assertEq(upgradeRegressionManager.rollbackQueueExpiresAt(_rollbackId), block.timestamp + _rollbackQueueWindow);
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
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__AlreadyExists.selector, _rollbackId)
    );
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.propose(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.propose(_targets, _values, _calldatasMismatch, _description);

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

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
  }
}

contract Queue is UpgradeRegressionManagerTest {
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

    _delay = bound(_delay, 0, rollbackQueueWindow - 1);
    vm.warp(block.timestamp + _delay);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    MockTimelockTarget.TimelockTransactionCall[] memory _lastQueueTransactionCalls =
      timelockTarget.lastParam__queueTransactions__();

    assertEq(_lastQueueTransactionCalls.length, 2);

    assertEq(_lastQueueTransactionCalls[0].target, _targets[0]);
    assertEq(_lastQueueTransactionCalls[0].value, _values[0]);
    assertEq(_lastQueueTransactionCalls[0].signature, "");
    assertEq(_lastQueueTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastQueueTransactionCalls[0].eta, 0);

    assertEq(_lastQueueTransactionCalls[1].target, _targets[1]);
    assertEq(_lastQueueTransactionCalls[1].value, _values[1]);
    assertEq(_lastQueueTransactionCalls[1].signature, "");
    assertEq(_lastQueueTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastQueueTransactionCalls[1].eta, 0);
  }

  function testFuzz_SetsTheExecutableTimeToAfterTimelockTargetDelay(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), block.timestamp + timelockTarget.delay());
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

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackQueued(_rollbackId, block.timestamp + timelockTarget.delay());

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RemovesFromRollbackQueue(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackQueueExpiresAt(_rollbackId), 0);
  }

  function testFuzz_AddsToRollbackExecutableAtQueue(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Ensure that the rollback is not already queued.
    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), 0);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), block.timestamp + timelockTarget.delay());
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

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackDoesNotExist(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueueable.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueueable.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackQueueHasExpired(
    uint256 _delay,
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    _delay = bound(_delay, rollbackQueueWindow, type(uint256).max - block.timestamp);

    vm.warp(block.timestamp + _delay);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__Expired.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.queue(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.queue(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract Cancel is UpgradeRegressionManagerTest {
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
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    MockTimelockTarget.TimelockTransactionCall[] memory _lastCancelTransactionCalls =
      timelockTarget.lastParam__cancelTransactions__();

    assertEq(_lastCancelTransactionCalls.length, 2);

    assertEq(_lastCancelTransactionCalls[0].target, _targets[0]);
    assertEq(_lastCancelTransactionCalls[0].value, _values[0]);
    assertEq(_lastCancelTransactionCalls[0].signature, "");
    assertEq(_lastCancelTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastCancelTransactionCalls[0].eta, 0);

    assertEq(_lastCancelTransactionCalls[1].target, _targets[1]);
    assertEq(_lastCancelTransactionCalls[1].value, _values[1]);
    assertEq(_lastCancelTransactionCalls[1].signature, "");
    assertEq(_lastCancelTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastCancelTransactionCalls[1].eta, 0);
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

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackCanceled(_rollbackId);

    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RemovesFromRollbackExecutableAtQueue(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), 0);
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _computedRollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
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

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.cancel(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.cancel(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract Execute is UpgradeRegressionManagerTest {
  function testFuzz_ForwardsParametersToTargetTimelockWhenCallerIsGuardian(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    MockTimelockTarget.TimelockTransactionCall[] memory _lastExecuteTransactionCalls =
      timelockTarget.lastParam__executeTransactions__();

    assertEq(_lastExecuteTransactionCalls.length, 2);

    assertEq(_lastExecuteTransactionCalls[0].target, _targets[0]);
    assertEq(_lastExecuteTransactionCalls[0].value, _values[0]);
    assertEq(_lastExecuteTransactionCalls[0].signature, "");
    assertEq(_lastExecuteTransactionCalls[0].data, _calldatas[0]);
    assertEq(_lastExecuteTransactionCalls[0].eta, 0);

    assertEq(_lastExecuteTransactionCalls[1].target, _targets[1]);
    assertEq(_lastExecuteTransactionCalls[1].value, _values[1]);
    assertEq(_lastExecuteTransactionCalls[1].signature, "");
    assertEq(_lastExecuteTransactionCalls[1].data, _calldatas[1]);
    assertEq(_lastExecuteTransactionCalls[1].eta, 0);
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

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackExecuted(_rollbackId);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RemovesFromRollbackExecutableAtQueue(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), block.timestamp + timelockTarget.delay());
    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.rollbackExecutableAt(_rollbackId), 0);
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
    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__ExecutionTooEarly.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RevertIf_RollbackWasNeverProposed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);
    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _computedRollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.execute(_targets, _valuesMismatch, _calldatas, _description);

    // target and calldatas length mismatch
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__MismatchedParameters.selector);
    upgradeRegressionManager.execute(_targets, _values, _calldatasMismatch, _description);

    vm.stopPrank();
  }
}

contract IsRollbackEligibleToQueue is UpgradeRegressionManagerTest {
  function test_ReturnsFalseIfRollbackDoesNotExist(uint256 _rollbackId) external view {
    assertEq(upgradeRegressionManager.isRollbackEligibleToQueue(_rollbackId), false);
  }

  function test_ReturnsFalseIfRollbackQueueExpiryWindowHasPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.prank(admin);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
    vm.warp(block.timestamp + rollbackQueueWindow + 1);
    assertEq(upgradeRegressionManager.isRollbackEligibleToQueue(_rollbackId), false);
  }

  function test_ReturnsTrueIfRollbackQueueExpiryWindowHasNotPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.prank(admin);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.isRollbackEligibleToQueue(_rollbackId), true);
  }
}

contract IsRollbackReadyToExecute is UpgradeRegressionManagerTest {
  function test_ReturnsFalseIfRollbackDoesNotExist(uint256 _rollbackId) external view {
    assertEq(upgradeRegressionManager.isRollbackReadyToExecute(_rollbackId), false);
  }

  function test_ReturnsFalseIfRollbackExecutionDelayHasNotPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.prank(admin);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    assertEq(upgradeRegressionManager.isRollbackReadyToExecute(_rollbackId), false);
  }

  function test_ReturnsTrueIfRollbackExecutionDelayHasPassed(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    vm.prank(admin);
    uint256 _rollbackId = upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    vm.warp(block.timestamp + timelockTarget.delay());

    assertEq(upgradeRegressionManager.isRollbackReadyToExecute(_rollbackId), true);
  }
}

contract SetGuardian is UpgradeRegressionManagerTest {
  function test_SetsGuardian(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.prank(admin);
    upgradeRegressionManager.setGuardian(_newGuardian);

    assertEq(upgradeRegressionManager.guardian(), _newGuardian);
  }

  function testFuzz_EmitsGuardianSet(address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.GuardianSet(guardian, _newGuardian);
    vm.prank(admin);
    upgradeRegressionManager.setGuardian(_newGuardian);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newGuardian) external {
    _assumeSafeGuardian(_newGuardian);
    vm.assume(_caller != admin);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.setGuardian(_newGuardian);
  }

  function test_RevertIf_NewGuardianIsZeroAddress() external {
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidAddress.selector);
    vm.prank(admin);
    upgradeRegressionManager.setGuardian(address(0));
  }
}

contract SetRollbackQueueWindow is UpgradeRegressionManagerTest {
  function test_SetsRollbackQueueWindow(uint256 _newRollbackQueueWindow) external {
    _newRollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_newRollbackQueueWindow);

    vm.prank(admin);
    upgradeRegressionManager.setRollbackQueueWindow(_newRollbackQueueWindow);

    assertEq(upgradeRegressionManager.rollbackQueueWindow(), _newRollbackQueueWindow);
  }

  function testFuzz_EmitsRollbackQueueWindowSet(uint256 _newRollbackQueueWindow) external {
    _newRollbackQueueWindow = _boundToRealisticRollbackQueueWindow(_newRollbackQueueWindow);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.RollbackQueueWindowSet(rollbackQueueWindow, _newRollbackQueueWindow);
    vm.prank(admin);
    upgradeRegressionManager.setRollbackQueueWindow(_newRollbackQueueWindow);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, uint256 _newRollbackQueueWindow) external {
    vm.assume(_caller != admin);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.setRollbackQueueWindow(_newRollbackQueueWindow);
  }

  function test_RevertIf_NewRollbackQueueWindowIsZero() external {
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidRollbackQueueWindow.selector);
    vm.prank(admin);
    upgradeRegressionManager.setRollbackQueueWindow(0);
  }
}

contract SetAdmin is UpgradeRegressionManagerTest {
  function test_SetsAdmin(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.prank(admin);
    upgradeRegressionManager.setAdmin(_newAdmin);

    assertEq(upgradeRegressionManager.admin(), _newAdmin);
  }

  function testFuzz_EmitsAdminSet(address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);

    vm.expectEmit(true, true, true, true);
    emit UpgradeRegressionManager.AdminSet(admin, _newAdmin);
    vm.prank(admin);
    upgradeRegressionManager.setAdmin(_newAdmin);
  }

  function testFuzz_RevertIf_CallerIsNotAdmin(address _caller, address _newAdmin) external {
    _assumeSafeAdmin(_newAdmin);
    vm.assume(_caller != admin);

    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__Unauthorized.selector);
    vm.prank(_caller);
    upgradeRegressionManager.setAdmin(_newAdmin);
  }

  function test_RevertIf_NewAdminIsZeroAddress() external {
    vm.expectRevert(UpgradeRegressionManager.UpgradeRegressionManager__InvalidAddress.selector);
    vm.prank(admin);
    upgradeRegressionManager.setAdmin(address(0));
  }
}

contract GetRollbackId is UpgradeRegressionManagerTest {
  function test_ReturnsRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view {
    uint256 _rollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    assertEq(_rollbackId, uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description))));
  }
}

/// @dev Internal Functions Skipped as these are not intended to be inherited by other contracts
contract _revertIfNotAdmin is UpgradeRegressionManagerTest {}

contract _revertIfNotGuardian is UpgradeRegressionManagerTest {}

contract _revertIfMismatchedParameters is UpgradeRegressionManagerTest {}

contract _setGuardian is UpgradeRegressionManagerTest {}

contract _setRollbackQueueWindow is UpgradeRegressionManagerTest {}

contract _setAdmin is UpgradeRegressionManagerTest {}
