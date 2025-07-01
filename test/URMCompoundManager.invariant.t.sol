// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {URMCore} from "src/contracts/URMCore.sol";
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {URMCompoundManagerHandler} from "test/handlers/URMCompoundManager.handler.sol";
import {URMInvariantTestBase} from "test/helpers/URMInvariantTestBase.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackProposal} from "test/helpers/RollbackSet.sol";
import {URMHandlerBase} from "test/helpers/URMHandlerBase.sol";

contract URMCompoundManagerInvariantTest is URMInvariantTestBase {
  URMCompoundManager public urm;
  MockCompoundTimelock public timelockTarget;
  URMCompoundManagerHandler public handler;

  function setUp() public override {
    timelockTarget = new MockCompoundTimelock();
    timelockTarget.setDelay(delay);

    targets = new FakeProtocolContract[](3);
    targets[0] = new FakeProtocolContract(address(timelockTarget));
    targets[1] = new FakeProtocolContract(address(timelockTarget));
    targets[2] = new FakeProtocolContract(address(timelockTarget));

    urm = new URMCompoundManager(address(timelockTarget), admin, guardian, delay, delay);

    handler = new URMCompoundManagerHandler(urm, admin, guardian, targets);

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
