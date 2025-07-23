// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackProposal} from "test/helpers/RollbackSet.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

/// @title RollbackManagerInvariantTestBase
/// @notice Abstract base invariant test class containing all shared invariant checks
/// @dev This abstract class contains all the common functionality between
///      RollbackManagerTimelockCompound and RollbackManagerTimelockControl. Subclasses need to implement:
///      - setUp() - to initialize the specific RollbackManager and handler instances
///      - _getRollbackManager() - to return the RollbackManager contract instance
///      - _getHandler() - to return the handler contract address
///      - _forEachRollbackByState() - to iterate over rollbacks by state
///      - _forEachRollbackQueuedButNotExecutable() - to iterate over queued but not executable rollbacks
///      - _callSummary() - to call the handler's callSummary function
abstract contract RollbackManagerInvariantTestBase is Test {
  // Common state variables
  address public admin = address(0x1);
  address public guardian = address(0x2);
  uint256 public delay = 2 days;
  FakeProtocolContract[] public rollbackProposalTargets;

  /// @notice Abstract method to get the RollbackManager contract instance
  /// @return The RollbackManager contract instance
  function _getRollbackManager() internal view virtual returns (RollbackManager);

  /// @notice Abstract method to get the handler instance
  /// @return The handler instance
  function _getHandler() internal view virtual returns (RollbackManagerHandlerBase);

  /// @notice Abstract setUp method to be implemented by subclasses
  function setUp() public virtual;

  // Expired proposals are not executable
  function invariant_expiredRollbackIsNotExecutable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotExecutable);
  }

  function _checkExpiredProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of expired proposals should revert
    }
  }

  // Expired proposals are not cancelable
  function invariant_expiredRollbackIsNotCancelable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotCancelable);
  }

  function _checkExpiredProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of expired proposals should revert
    }
  }

  // Executed proposals are not cancelable
  function invariant_executedRollbackIsNotCancelable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Executed, this._checkExecutedProposalNotCancelable);
  }

  function _checkExecutedProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Executed proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of executed proposals should revert
    }
  }

  // Executed proposals are not executable
  function invariant_executedRollbackIsNotExecutable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Executed, this._checkExecutedProposalNotExecutable);
  }

  function _checkExecutedProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Executed proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of executed proposals should revert
    }
  }

  // Cancelled proposals are not cancelable
  function invariant_cancelledRollbackIsNotCancelable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Canceled, this._checkCancelledProposalNotCancelable);
  }

  function _checkCancelledProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Cancelled proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of cancelled proposals should revert
    }
  }

  // Cancelled proposals are not executable
  function invariant_cancelledRollbackIsNotExecutable() public {
    _forEachRollbackByState(IGovernor.ProposalState.Canceled, this._checkCancelledProposalNotExecutable);
  }

  function _checkCancelledProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Cancelled proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of cancelled proposals should revert
    }
  }

  function invariant_cannotExecuteRollbackWithoutQueueing() public {
    _forEachRollbackByState(IGovernor.ProposalState.Pending, this._checkPendingProposalNotExecutable);
  }

  function _checkPendingProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Pending proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of pending proposals should revert
    }
  }

  function invariant_cannotCancelRollbackWithoutQueueing() public {
    _forEachRollbackByState(IGovernor.ProposalState.Pending, this._checkPendingProposalNotCancelable);
  }

  function _checkPendingProposalNotCancelable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().cancel(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Pending proposal was cancelled - invariant violation");
    } catch {
      // Expected behavior - cancellation of pending proposals should revert
    }
  }

  function invariant_cannotExecuteRollbackBeforeTimelockDelay() public {
    _forEachRollbackQueuedButNotExecutable(this._checkQueuedProposalNotExecutable);
  }

  function _checkQueuedProposalNotExecutable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().execute(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Queued proposal was executed - invariant violation");
    } catch {
      // Expected behavior - execution of queued proposals should revert
    }
  }

  function invariant_cannotQueueRollbackAfterQueuableDurationPasses() public {
    _forEachRollbackByState(IGovernor.ProposalState.Expired, this._checkExpiredProposalNotQueueable);
  }

  function _checkExpiredProposalNotQueueable(RollbackProposal memory _proposal) external {
    vm.prank(guardian);
    try _getRollbackManager().queue(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description) {
      revert("Expired proposal was queued - invariant violation");
    } catch {
      // Expected behavior - queuing of expired proposals should revert
    }
  }

  // Concrete implementations of the handler methods
  function _forEachRollbackByState(IGovernor.ProposalState _state, function(RollbackProposal memory) external _func)
    internal
  {
    _getHandler().forEachRollbackByState(_state, _func);
  }

  function _forEachRollbackQueuedButNotExecutable(function(RollbackProposal memory) external _func) internal {
    _getHandler().forEachRollbackQueuedButNotExecutable(_func);
  }

  function _callSummary() internal {
    _getHandler().callSummary();
  }

  function invariant_callSummary() public {
    _getHandler().callSummary();
  }
}
