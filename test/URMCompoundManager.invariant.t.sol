// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {URMCompoundManagerHandler} from "test/handlers/URMCompoundManager.handler.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackProposal} from "test/helpers/RollbackSet.sol";

contract URMCompoundManagerInvariantTest is Test {
  URMCompoundManager public urm;
  MockCompoundTimelock public timelockTarget;
  FakeProtocolContract[] public targets;
  URMCompoundManagerHandler public handler;

  address public admin = makeAddr("admin");
  address public guardian = makeAddr("guardian");
  uint256 public delay = 5 seconds;

  function setUp() public {
    timelockTarget = new MockCompoundTimelock();
    timelockTarget.setDelay(delay);

    targets = new FakeProtocolContract[](3);
    targets[0] = new FakeProtocolContract(admin);
    targets[1] = new FakeProtocolContract(admin);
    targets[2] = new FakeProtocolContract(admin);

    urm = new URMCompoundManager(address(timelockTarget), admin, guardian, delay, delay);

    handler = new URMCompoundManagerHandler(urm, admin, guardian, targets);

    // target the handler for invariant testing
    targetContract(address(handler));

    // Exclude handler iteration functions from fuzzing
    bytes4[] memory excludeSelectors = new bytes4[](3);
    excludeSelectors[0] = URMCompoundManagerHandler.forEachRollbackQueuedButNotExecutable.selector;
    excludeSelectors[1] = URMCompoundManagerHandler.forEachRollbackByState.selector;
    excludeSelectors[2] = URMCompoundManagerHandler.forEachRollback.selector;
    excludeSelector(FuzzSelector(address(handler), excludeSelectors));
  }

  function invariant_rollbackIdIsUnique() public view {
    // Ensure all proposals have a unique id
    uint256 _proposalCount = handler.getRollbackSetCount();

    // Check that all rollback IDs are unique by comparing each pair
    for (uint256 i = 0; i < _proposalCount; i++) {
      for (uint256 j = i + 1; j < _proposalCount; j++) {
        assert(handler.getRollbackProposal(i).rollbackId != handler.getRollbackProposal(j).rollbackId);
      }
    }
  }

  // Expired proposals are not executable
  function invariant_expiredRollbackIsNotExecutable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotExecutable);
  }

  function _checkExpiredProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of expired proposals should revert
    }
  }

  // Expired proposals are not cancelable
  function invariant_expiredRollbackIsNotCancelable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotCancelable);
  }

  function _checkExpiredProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of expired proposals should revert
    }
  }

  // Executed proposals are not cancelable
  function invariant_executedRollbackIsNotCancelable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Executed, this._checkExecutedProposalNotCancelable);
  }

  function _checkExecutedProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Executed proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of executed proposals should revert
    }
  }

  // Executed proposals are not executable
  function invariant_executedRollbackIsNotExecutable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Executed, this._checkExecutedProposalNotExecutable);
  }

  function _checkExecutedProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Executed proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of executed proposals should revert
    }
  }

  // Cancelled proposals are not cancelable
  function invariant_cancelledRollbackIsNotCancelable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Canceled, this._checkCancelledProposalNotCancelable);
  }

  function _checkCancelledProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Cancelled proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of cancelled proposals should revert
    }
  }

  // Cancelled proposals are not executable
  function invariant_cancelledRollbackIsNotExecutable() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Canceled, this._checkCancelledProposalNotExecutable);
  }

  function _checkCancelledProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Cancelled proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of cancelled proposals should revert
    }
  }

  function invariant_cannotExecuteRollbackWithoutQueueing() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Pending, this._checkPendingProposalNotExecutable);
  }

  function _checkPendingProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Pending proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of pending proposals should revert
    }
  }

  function invariant_cannotCancelRollbackWithoutQueueing() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Pending, this._checkPendingProposalNotCancelable);
  }

  function _checkPendingProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Pending proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of pending proposals should revert
    }
  }

  function invariant_cannotExecuteRollbackBeforeTimelockDelay() public {
    handler.forEachRollbackQueuedButNotExecutable(this._checkQueuedProposalNotExecutable);
  }

  function _checkQueuedProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Queued proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of queued proposals should revert
    }
  }

  function invariant_cannotQueueRollbackAfterQueuableDurationPasses() public {
    handler.forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotQueueable);
  }

  function _checkExpiredProposalNotQueueable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try urm.queue(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was queued - invariant violation");
    } catch {
      // Expected behavior - queuing of expired proposals should revert
    }
  }

  function invariant_callSummary() public view {
    handler.callSummary();
  }
}
