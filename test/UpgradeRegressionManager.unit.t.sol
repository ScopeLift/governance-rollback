// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {ITimelockTarget} from "src/interfaces/ITimelockTarget.sol";
import {Rollback} from "src/interfaces/IUpgradeRegressionManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

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

    for (uint256 _i = 0; _i < 2; _i++) {
      targets[_i] = _fixedTargets[_i];
      values[_i] = _fixedValues[_i];
      calldatas[_i] = _fixedCalldatas[_i];
    }
  }
}

contract Constructor is UpgradeRegressionManagerTest {
  function testFuzz_SetsInitialParameters(
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

    vm.expectEmit();
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

    vm.expectEmit();
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

contract GetRollback is UpgradeRegressionManagerTest {
  function testFuzz_ReturnsTheRollbackData(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    _proposeRollback(_targets, _values, _calldatas, _description);

    uint256 _rollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);
    uint256 _rollbackQueueWindow = upgradeRegressionManager.rollbackQueueWindow();

    Rollback memory _rollback = upgradeRegressionManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + _rollbackQueueWindow);
    assertEq(_rollback.executableAt, 0);
    assertEq(_rollback.canceled, false);
    assertEq(_rollback.executed, false);
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

    vm.expectEmit();
    emit UpgradeRegressionManager.RollbackProposed(
      _computedRollbackId, block.timestamp + rollbackQueueWindow, _targets, _values, _calldatas, _description
    );

    vm.prank(admin);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);
  }

  function testFuzz_RollbackStateIsCorrectlySet(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = upgradeRegressionManager.getRollback(_computedRollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + rollbackQueueWindow);
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

    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.prank(admin);
    upgradeRegressionManager.propose(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_computedRollbackId);
    assertEq(uint8(_state), uint8(IGovernor.ProposalState.Pending));
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

    assertEq(upgradeRegressionManager.getRollback(_rollbackId).queueExpiresAt, block.timestamp + _rollbackQueueWindow);
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

    uint256 _queueExpiresAtBeforeQueuing = upgradeRegressionManager.getRollback(_rollbackId).queueExpiresAt;

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = upgradeRegressionManager.getRollback(_rollbackId);

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

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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
    emit UpgradeRegressionManager.RollbackQueued(_rollbackId, block.timestamp + timelockTarget.delay());

    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);
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
      abi.encodeWithSelector(
        UpgradeRegressionManager.UpgradeRegressionManager__NonExistentRollback.selector, _rollbackId
      )
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
    IGovernor.ProposalState _initialState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Pending));

    // Warp to exactly when the queue window expires
    vm.warp(block.timestamp + rollbackQueueWindow);

    // Verify the rollback is now in expired state
    IGovernor.ProposalState _expiredState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_expiredState), uint8(IGovernor.ProposalState.Expired));

    // Try to queue the expired rollback - should revert with specific error
    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__Expired.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.queue(_targets, _values, _calldatas, _description);

    // Warp further into the future and try again
    _timeAfterExpiry = bound(_timeAfterExpiry, 1, 365 days);
    vm.warp(block.timestamp + _timeAfterExpiry);

    // Should still revert with the same error
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
    emit UpgradeRegressionManager.RollbackCanceled(_rollbackId);

    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);
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
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = upgradeRegressionManager.getRollback(_rollbackId);

    assertEq(_rollback.queueExpiresAt, block.timestamp + rollbackQueueWindow);
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
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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
    uint256 _computedRollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(
        UpgradeRegressionManager.UpgradeRegressionManager__NonExistentRollback.selector, _computedRollbackId
      )
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
    IGovernor.ProposalState _initialState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Warp to after the execution time and execute the rollback
    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in executed state
    IGovernor.ProposalState _executedState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_executedState), uint8(IGovernor.ProposalState.Executed));

    // Try to cancel the executed rollback - should revert with specific error
    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in executed state after the failed cancel attempt
    IGovernor.ProposalState _finalState = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _eta = block.timestamp + timelockTarget.delay();

    vm.warp(_eta);
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    MockTimelockTarget.TimelockTransactionCall[] memory _lastExecuteTransactionCalls =
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
    emit UpgradeRegressionManager.RollbackExecuted(_rollbackId);

    vm.warp(block.timestamp + timelockTarget.delay());
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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

    uint256 _queueExpiresAt = upgradeRegressionManager.getRollback(_rollbackId).queueExpiresAt;
    uint256 _executableAt = upgradeRegressionManager.getRollback(_rollbackId).executableAt;

    vm.warp(_queueExpiresAt);
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    Rollback memory _rollback = upgradeRegressionManager.getRollback(_rollbackId);

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
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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
      abi.encodeWithSelector(
        UpgradeRegressionManager.UpgradeRegressionManager__NonExistentRollback.selector, _computedRollbackId
      )
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);
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
    IGovernor.ProposalState _initialState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Cancel the rollback
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    // Verify the rollback is now in canceled state
    IGovernor.ProposalState _canceledState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_canceledState), uint8(IGovernor.ProposalState.Canceled));

    // Warp to after the execution time would have been
    vm.warp(block.timestamp + timelockTarget.delay());

    // Try to execute the canceled rollback - should revert with specific error
    vm.expectRevert(
      abi.encodeWithSelector(UpgradeRegressionManager.UpgradeRegressionManager__NotQueued.selector, _rollbackId)
    );
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    // Verify the rollback is still in canceled state after the failed execution attempt
    IGovernor.ProposalState _finalState = upgradeRegressionManager.state(_rollbackId);
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

contract State is UpgradeRegressionManagerTest {
  function testFuzz_PendingWithinQueueWindow(
    address[2] memory _targetsFixed,
    uint256[2] memory _valuesFixed,
    bytes[2] memory _calldatasFixed,
    string memory _description,
    uint256 _timeOffset
  ) external {
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      toDynamicArrays(_targetsFixed, _valuesFixed, _calldatasFixed);

    // Bound time offset to be within the queue window
    _timeOffset = bound(_timeOffset, 0, rollbackQueueWindow - 1);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Warp to a time within the expiry window
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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

    // Bound time offset to be after the queue window
    _timeOffset = bound(_timeOffset, rollbackQueueWindow, rollbackQueueWindow + 30 days);

    uint256 _rollbackId = _proposeRollback(_targets, _values, _calldatas, _description);

    // Warp to a time after the expiry window
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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
    IGovernor.ProposalState _initialState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Pending));

    // Warp to exactly when the queue window expires
    vm.warp(block.timestamp + rollbackQueueWindow);

    // Verify the rollback is now in expired state at the exact boundary
    IGovernor.ProposalState _exactExpirationState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_exactExpirationState), uint8(IGovernor.ProposalState.Expired));

    // Warp 1 second before expiration to verify it's still pending
    vm.warp(block.timestamp - rollbackQueueWindow + rollbackQueueWindow - 1);
    IGovernor.ProposalState _beforeExpirationState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_beforeExpirationState), uint8(IGovernor.ProposalState.Pending));

    // Warp back to exact expiration time
    vm.warp(block.timestamp + 1);
    IGovernor.ProposalState _atExpirationState = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be before the executable time
    _timeOffset = bound(_timeOffset, 0, timelockTarget.delay() - 1);

    // Warp to a time before the executable window
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Bound time offset to be after the executable time
    _timeOffset = bound(_timeOffset, timelockTarget.delay(), timelockTarget.delay() + 30 days);

    // Warp to a time after the executable window
    vm.warp(block.timestamp + _timeOffset);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Verify the rollback is initially in queued state
    IGovernor.ProposalState _initialState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_initialState), uint8(IGovernor.ProposalState.Queued));

    // Warp to exactly when the execution time arrives
    vm.warp(block.timestamp + timelockTarget.delay());

    // Verify the rollback is now in queued state at the exact boundary
    IGovernor.ProposalState _exactExecutionState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_exactExecutionState), uint8(IGovernor.ProposalState.Queued));

    // Warp 1 second before execution time to verify it's still queued
    vm.warp(block.timestamp - timelockTarget.delay() + timelockTarget.delay() - 1);
    IGovernor.ProposalState _beforeExecutionState = upgradeRegressionManager.state(_rollbackId);
    assertEq(uint8(_beforeExecutionState), uint8(IGovernor.ProposalState.Queued));

    // Warp back to exact execution time
    vm.warp(block.timestamp + 1);
    IGovernor.ProposalState _atExecutionState = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Warp to executable time
    vm.warp(block.timestamp + timelockTarget.delay());

    // Execute the rollback
    vm.prank(guardian);
    upgradeRegressionManager.execute(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = _proposeAndQueueRollback(_targets, _values, _calldatas, _description);

    // Cancel the rollback
    vm.prank(guardian);
    upgradeRegressionManager.cancel(_targets, _values, _calldatas, _description);

    IGovernor.ProposalState _state = upgradeRegressionManager.state(_rollbackId);
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

    uint256 _rollbackId = upgradeRegressionManager.getRollbackId(_targets, _values, _calldatas, _description);

    vm.expectRevert(
      abi.encodeWithSelector(
        UpgradeRegressionManager.UpgradeRegressionManager__NonExistentRollback.selector, _rollbackId
      )
    );
    upgradeRegressionManager.state(_rollbackId);
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

    vm.expectEmit();
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

    vm.expectEmit();
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

    vm.expectEmit();
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
