// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {RollbackManager} from "src/RollbackManager.sol";
import {Rollback} from "src/interfaces/IRollbackManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

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
}

contract State is RollbackManagerTimelockCompoundTest {
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
    vm.warp(block.timestamp - 1);
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
    _timeOffset = bound(_timeOffset, 0, targetTimelock.delay() - 1);

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
    _timeOffset = bound(_timeOffset, targetTimelock.delay(), targetTimelock.delay() + 30 days);

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
    vm.warp(block.timestamp + targetTimelock.delay());

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
    vm.warp(block.timestamp + targetTimelock.delay());

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

contract IsRollbackExecutable is RollbackManagerTimelockCompoundTest {
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
    vm.warp(block.timestamp + targetTimelock.delay());
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
    _delayAfterQueuing = bound(_delayAfterQueuing, 0, targetTimelock.delay() - 1);
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
    _delayAfterQueuing = bound(_delayAfterQueuing, targetTimelock.delay(), 365 days * 100);
    vm.warp(block.timestamp + _delayAfterQueuing);

    bool _isExecutable = rollbackManager.isRollbackExecutable(_rollbackId);
    assertTrue(_isExecutable);
  }
}

contract SetGuardian is RollbackManagerTimelockCompoundTest {
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

contract SetRollbackQueueableDuration is RollbackManagerTimelockCompoundTest {
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

contract SetAdmin is RollbackManagerTimelockCompoundTest {
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

contract GetRollbackId is RollbackManagerTimelockCompoundTest {
  function test_ReturnsRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view {
    uint256 _rollbackId = rollbackManager.getRollbackId(_targets, _values, _calldatas, _description);

    assertEq(_rollbackId, uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description))));
  }
}
