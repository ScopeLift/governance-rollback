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
}

contract State is StateBase, RollbackManagerTimelockCompoundTest {}

contract IsRollbackExecutable is IsRollbackExecutableBase, RollbackManagerTimelockCompoundTest {}

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
