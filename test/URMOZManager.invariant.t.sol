// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {URMCore} from "src/contracts/URMCore.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";
import {MockOZTargetTimelock} from "test/mocks/MockOZTargetTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {URMOZManagerHandler} from "test/handlers/URMOZManager.handler.sol";
import {URMInvariantTestBase} from "test/helpers/URMInvariantTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackProposal} from "test/helpers/RollbackSet.sol";
import {URMHandlerBase} from "test/helpers/URMHandlerBase.sol";

contract URMOZManagerInvariantTest is URMInvariantTestBase {
  URMOZManager public urm;
  MockOZTargetTimelock public timelockTarget;
  URMOZManagerHandler public handler;

  function setUp() public override {
    timelockTarget = new MockOZTargetTimelock();
    timelockTarget.setMinDelay(delay);

    targets = new FakeProtocolContract[](3);
    targets[0] = new FakeProtocolContract(admin);
    targets[1] = new FakeProtocolContract(admin);
    targets[2] = new FakeProtocolContract(admin);

    urm = new URMOZManager(address(timelockTarget), admin, guardian, delay, delay);

    handler = new URMOZManagerHandler(urm, admin, guardian, targets);

    // target the handler for invariant testing
    targetContract(address(handler));

    // Exclude handler iteration functions from fuzzing
    bytes4[] memory excludeSelectors = new bytes4[](6);
    excludeSelectors[0] = URMHandlerBase.forEachRollbackQueuedButNotExecutable.selector;
    excludeSelectors[1] = URMHandlerBase.forEachRollbackByState.selector;
    excludeSelectors[2] = URMHandlerBase.forEachRollback.selector;
    excludeSelectors[3] = URMHandlerBase.getRollbackSetCount.selector;
    excludeSelectors[4] = URMHandlerBase.getRollbackProposal.selector;
    excludeSelectors[5] = URMHandlerBase.callSummary.selector;

    excludeSelector(FuzzSelector(address(handler), excludeSelectors));
  }

  function _getURM() internal view override returns (URMCore) {
    return urm;
  }

  function _getHandler() internal view override returns (address) {
    return address(handler);
  }

  function _forEachRollbackByState(IGovernor.ProposalState _state, function(RollbackProposal memory) external _func)
    internal
    override
  {
    handler.forEachRollbackByState(_state, _func);
  }

  function _forEachRollbackQueuedButNotExecutable(function(RollbackProposal memory) external _func) internal override {
    handler.forEachRollbackQueuedButNotExecutable(_func);
  }

  function _callSummary() internal override {
    handler.callSummary();
  }

  function invariant_callSummary() public override {
    handler.callSummary();
  }
}
