// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackManagerTimelockCompoundHandler} from "test/handlers/RollbackManagerTimelockCompound.handler.sol";
import {RollbackManagerInvariantTestBase} from "test/helpers/RollbackManagerInvariantTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackProposal} from "test/helpers/RollbackSet.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

contract RollbackManagerTimelockCompoundInvariantTest is RollbackManagerInvariantTestBase {
  RollbackManagerTimelockCompound public rollbackManager;
  MockCompoundTimelock public timelockTarget;
  RollbackManagerTimelockCompoundHandler public handler;

  function setUp() public override {
    timelockTarget = new MockCompoundTimelock();
    timelockTarget.setDelay(delay);

    rollbackProposalTargets = new FakeProtocolContract[](3);
    rollbackProposalTargets[0] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[1] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[2] = new FakeProtocolContract(address(timelockTarget));

    rollbackManager = new RollbackManagerTimelockCompound(address(timelockTarget), admin, guardian, delay, delay);

    handler = new RollbackManagerTimelockCompoundHandler(rollbackManager, admin, guardian, rollbackProposalTargets);

    // target the handler for invariant testing
    targetContract(address(handler));

    // Exclude handler iteration functions from fuzzing
    bytes4[] memory excludeSelectors = new bytes4[](6);
    excludeSelectors[0] = RollbackManagerHandlerBase.forEachRollbackQueuedButNotExecutable.selector;
    excludeSelectors[1] = RollbackManagerHandlerBase.forEachRollbackByState.selector;
    excludeSelectors[2] = RollbackManagerHandlerBase.forEachRollback.selector;
    excludeSelectors[3] = RollbackManagerHandlerBase.getRollbackSetCount.selector;
    excludeSelectors[4] = RollbackManagerHandlerBase.getRollbackProposal.selector;
    excludeSelectors[5] = RollbackManagerHandlerBase.callSummary.selector;

    excludeSelector(FuzzSelector(address(handler), excludeSelectors));
  }

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
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
