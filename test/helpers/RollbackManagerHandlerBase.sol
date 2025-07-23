// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Internal Imports
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackSet, LibRollbackSet, RollbackProposal} from "test/helpers/RollbackSet.sol";
import {RollbackTransactionGenerator} from "test/helpers/RollbackTransactionGenerator.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackManager} from "src/RollbackManager.sol";

/// @title RollbackManagerHandlerBase
/// @notice Base handler contract for Rollback Manager invariant testing
/// @dev This abstract class contains all the common functionality between
///      RollbackManagerTimelockCompound and RollbackManagerTimelockControl handlers. Subclasses need to implement:
///      - _getRollbackManager() - to return the RollbackManager contract instance
///      - _getDescription() - to return the description string
abstract contract RollbackManagerHandlerBase is Test {
  using LibRollbackSet for RollbackSet;

  FakeProtocolContract[] public rollbackProposalTargets;
  RollbackSet public _rollbackSet;
  bytes4[] public selectors;

  address public admin;
  address public guardian;

  // Call tracking
  mapping(bytes32 => uint256) public calls;
  uint256 public ghost_rollbackExistsReverts;
  uint256 public ghost_invalidOperationReverts;
  uint256 public ghost_authorizationReverts;
  uint256 public ghost_unableToFindProposals;

  modifier countCall(bytes32 key) {
    calls[key]++;
    _;
  }

  constructor(address _admin, address _guardian, FakeProtocolContract[] memory _targets) {
    admin = _admin;
    guardian = _guardian;

    for (uint256 i = 0; i < _targets.length; i++) {
      rollbackProposalTargets.push(_targets[i]);
    }

    selectors = [FakeProtocolContract.setFee.selector, FakeProtocolContract.setFeeGuardian.selector];

    // Note: Rollback Manager address will be set by child class after initialization
  }

  /// @notice Abstract method to get the RollbackManager contract instance
  /// @return The RollbackManager contract instance
  function _getRollbackManager() internal view virtual returns (RollbackManager);

  /// @notice Abstract method to get the description string
  /// @return The description string
  function _getDescription() internal view virtual returns (string memory);

  /// @notice Set the Rollback Manager address in the RollbackSet (called by child constructor)
  function _setRollbackManagerAddress() internal {
    _rollbackSet.setRollbackManager(address(_getRollbackManager()));
  }

  /// @notice Propose a rollback
  /// @param _rollbackFee The new fee
  function propose(uint256 _rollbackFee) external countCall("propose") {
    // Get the rollback transactions
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      RollbackTransactionGenerator.generateRandomRollbackTransactions(_rollbackFee, guardian, rollbackProposalTargets, selectors);

    // Get the rollback ID
    uint256 _rollbackId = _getRollbackManager().getRollbackId(_targets, _values, _calldatas, _getDescription());

    // Only propose if it doesn't already exist
    if (LibRollbackSet.contains(_rollbackSet, _rollbackId)) {
      ghost_rollbackExistsReverts++;
      return; // Skip instead of reverting
    }

    vm.prank(admin);
    _getRollbackManager().propose(_targets, _values, _calldatas, _getDescription());

    _rollbackSet.add(
      RollbackProposal({
        targets: _targets,
        values: _values,
        calldatas: _calldatas,
        description: _getDescription(),
        rollbackId: _rollbackId
      })
    );
  }

  /// @notice Queue a valid rollback proposal
  /// @param _randomIndex Used to randomly select a queueable proposal
  function queue(uint256 _randomIndex) external countCall("queue") {
    // Only proceed if there are pending proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Pending)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random proposed proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Pending, _randomIndex);

    // Queue the proposal
    vm.prank(guardian);
    try _getRollbackManager().queue(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid queue operation");
    }
  }

  /// @notice Wrap before expiry and queue a valid rollback proposal
  /// @param _randomIndex Used to randomly select an expired proposal
  function wrapBeforeExpiryAndQueue(uint256 _randomIndex) external countCall("wrapBeforeExpiryAndQueue") {
    // Only proceed if there are expired proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Expired)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random expired proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Expired, _randomIndex);

    // Warp to the proposal's queueExpiresAt time
    uint256 _queueExpiresAt = _getRollbackManager().getRollback(_randomProposal.rollbackId).queueExpiresAt;
    vm.warp(_queueExpiresAt - 1);

    // Queue the proposal
    vm.prank(guardian);
    try _getRollbackManager().queue(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid wrapBeforeExpiryAndQueue operation");
    }
  }

  /// @notice Execute a valid rollback proposal
  /// @param _randomIndex Used to randomly select an executable proposal
  function execute(uint256 _randomIndex) external countCall("execute") {
    // Only proceed if there are executable proposals
    if (!_rollbackSet.hasExecutableProposals()) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random executable proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randExecutable(_randomIndex);

    // Execute the proposal
    vm.prank(guardian);
    try _getRollbackManager().execute(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid execute operation");
    }
  }

  function warpAndExecute(uint256 _randomIndex) external countCall("warpAndExecute") {
    // Only proceed if there are queued proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Queued)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random queued proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Warp to the proposal's executableAt time
    uint256 _executableAt = _getRollbackManager().getRollback(_randomProposal.rollbackId).executableAt;
    vm.warp(_executableAt + 1);

    // Execute the proposal
    vm.prank(guardian);
    try _getRollbackManager().execute(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid warpAndExecute operation");
    }
  }

  /// @notice Cancel a valid rollback proposal
  /// @param _randomIndex Used to randomly select a cancellable proposal
  function cancel(uint256 _randomIndex) external countCall("cancel") {
    // Only proceed if there are queued proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Queued)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random queued proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Cancel the proposal
    vm.prank(guardian);
    try _getRollbackManager().cancel(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid cancel operation");
    }
  }

  /// @notice Attempt to queue a rollback proposal that's not meant to be queued
  /// @param _randomIndex Used to randomly select a proposal from invalid states
  function invalidQueue(uint256 _randomIndex) external countCall("invalidQueue") {
    // Get invalid states for queueing (all states except Pending)
    IGovernor.ProposalState[] memory _invalidStates = new IGovernor.ProposalState[](4);
    _invalidStates[0] = IGovernor.ProposalState.Queued;
    _invalidStates[1] = IGovernor.ProposalState.Canceled;
    _invalidStates[2] = IGovernor.ProposalState.Expired;
    _invalidStates[3] = IGovernor.ProposalState.Executed;

    // Only proceed if there are proposals in invalid states
    if (!_rollbackSet.hasProposalsInStates(_invalidStates)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random proposal from invalid states
    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

    // Attempt to queue the proposal which should revert
    vm.prank(guardian);
    try _getRollbackManager().queue(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the queue should have reverted
      revert("Queue should have reverted for invalid proposal state");
    } catch {
      // Expected behavior - revert was caught
      ghost_invalidOperationReverts++;
    }
  }

  /// @notice Attempt to execute a rollback proposal that's not meant to be executed
  /// @param _randomIndex Used to randomly select a proposal from invalid states
  function invalidExecute(uint256 _randomIndex) external countCall("invalidExecute") {
    // Get invalid states for execution (all states except Queued and Executed)
    IGovernor.ProposalState[] memory _invalidStates = new IGovernor.ProposalState[](4);
    _invalidStates[0] = IGovernor.ProposalState.Pending;
    _invalidStates[1] = IGovernor.ProposalState.Canceled;
    _invalidStates[2] = IGovernor.ProposalState.Expired;
    _invalidStates[3] = IGovernor.ProposalState.Executed;

    // Only proceed if there are proposals in invalid states
    if (!_rollbackSet.hasProposalsInStates(_invalidStates)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random proposal from invalid states
    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

    // Attempt to execute the proposal (should revert)
    vm.prank(guardian);
    try _getRollbackManager().execute(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the execute should have reverted
      revert("Execute should have reverted for invalid proposal state");
    } catch {
      // Expected behavior - revert was caught
      ghost_invalidOperationReverts++;
    }
  }

  /// @notice Attempt to cancel a rollback proposal that's not meant to be cancelled
  /// @param _randomIndex Used to randomly select a proposal from invalid states
  function invalidCancel(uint256 _randomIndex) external countCall("invalidCancel") {
    // Get a random proposal from invalid states for cancellation
    IGovernor.ProposalState[] memory _invalidStates = new IGovernor.ProposalState[](4);
    _invalidStates[0] = IGovernor.ProposalState.Pending;
    _invalidStates[1] = IGovernor.ProposalState.Canceled;
    _invalidStates[2] = IGovernor.ProposalState.Executed;
    _invalidStates[3] = IGovernor.ProposalState.Expired;

    // Only proceed if there are proposals in invalid states
    if (!_rollbackSet.hasProposalsInStates(_invalidStates)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random proposal from invalid states
    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

    // Attempt to cancel the proposal (should revert)
    vm.prank(guardian);
    try _getRollbackManager().cancel(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the cancel should have reverted
      revert("Cancel should have reverted for invalid proposal state");
    } catch {
      // Expected behavior - revert was caught
      ghost_invalidOperationReverts++;
    }
  }

  /// @notice Attempt to queue a proposal with an invalid caller (should revert)
  /// @param _randomIndex Used to randomly select a valid proposal
  /// @param _caller Random caller address
  function invalidCallerOnQueue(uint256 _randomIndex, address _caller) external countCall("invalidCallerOnQueue") {
    // Assume caller is not the guardian
    vm.assume(_caller != guardian);

    // Only proceed if there are pending proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Pending)) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random pending proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Pending, _randomIndex);

    // Attempt to queue with a non-guardian caller (should revert)
    vm.prank(_caller);
    try _getRollbackManager().queue(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the queue should have reverted
      revert("Queue should have reverted for invalid caller");
    } catch {
      // Expected behavior - revert was caught
      ghost_authorizationReverts++;
    }
  }

  /// @notice Attempt to execute a proposal with an invalid caller (should revert)
  /// @param _randomIndex Used to randomly select a valid proposal
  /// @param _caller Random caller address
  function invalidCallerOnExecute(uint256 _randomIndex, address _caller) external countCall("invalidCallerOnExecute") {
    // Assume caller is not the guardian
    vm.assume(_caller != guardian);

    // Only proceed if there are executable proposals
    if (!_rollbackSet.hasExecutableProposals()) {
      ghost_unableToFindProposals++;
      return;
    }

    // Get a random executable proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randExecutable(_randomIndex);

    // Attempt to execute with a non-guardian caller (should revert)
    vm.prank(_caller);
    try _getRollbackManager().execute(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the execute should have reverted
      revert("Execute should have reverted for invalid caller");
    } catch {
      // Expected behavior - revert was caught
      ghost_authorizationReverts++;
    }
  }

  /// @notice Attempt to cancel a proposal with an invalid caller (should revert)
  /// @param _randomIndex Used to randomly select a valid proposal
  /// @param _caller Random caller address
  function invalidCallerOnCancel(uint256 _randomIndex, address _caller) external countCall("invalidCallerOnCancel") {
    // Assume caller is not the guardian
    vm.assume(_caller != guardian);

    // Only proceed if there are queued proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Queued)) {
      ghost_unableToFindProposals++;
      return;
    }

    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Attempt to cancel with a non-guardian caller (should revert)
    vm.prank(_caller);
    try _getRollbackManager().cancel(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the cancel should have reverted
      revert("Cancel should have reverted for invalid caller");
    } catch {
      // Expected behavior - revert was caught
      ghost_authorizationReverts++;
    }
  }

  // Add these view/iteration functions to the base class
  function callSummary() external countCall("callSummary") {
    console.log("Call summary:");
    console.log("-------------------");
    console.log("propose", calls["propose"]);
    console.log("queue", calls["queue"]);
    console.log("wrapBeforeExpiryAndQueue", calls["wrapBeforeExpiryAndQueue"]);
    console.log("execute", calls["execute"]);
    console.log("warpAndExecute", calls["warpAndExecute"]);
    console.log("cancel", calls["cancel"]);
    console.log("invalidQueue", calls["invalidQueue"]);
    console.log("invalidExecute", calls["invalidExecute"]);
    console.log("invalidCancel", calls["invalidCancel"]);
    console.log("invalidCallerOnQueue", calls["invalidCallerOnQueue"]);
    console.log("invalidCallerOnExecute", calls["invalidCallerOnExecute"]);
    console.log("invalidCallerOnCancel", calls["invalidCallerOnCancel"]);
    console.log("----------VIEW FUNCTIONS---------");
    console.log("callSummary", calls["callSummary"]);
    console.log("forEachRollback", calls["forEachRollback"]);
    console.log("forEachRollbackByState", calls["forEachRollbackByState"]);
    console.log("forEachRollbackQueuedButNotExecutable", calls["forEachRollbackQueued"]);
    console.log("getRollbackSetCount", calls["getRollbackSetCount"]);
    console.log("getRollbackProposal", calls["getRollbackProposal"]);
    console.log("----------GHOST VARIABLES---------");
    console.log("ghost_unableToFindProposals", ghost_unableToFindProposals);
    console.log("ghost_rollbackExistsReverts", ghost_rollbackExistsReverts);
    console.log("ghost_invalidOperationReverts", ghost_invalidOperationReverts);
    console.log("ghost_authorizationReverts", ghost_authorizationReverts);
    console.log("-------------------");
    console.log(
      "TOTAL EXPECTED REVERTS:",
      ghost_rollbackExistsReverts + ghost_invalidOperationReverts + ghost_authorizationReverts
    );
    console.log("(includes: duplicate rollbacks, invalid operations, auth failures, random selection errors)");
    console.log("-------------------");
  }

  function forEachRollback(function(RollbackProposal memory) external _func) external countCall("forEachRollback") {
    _rollbackSet.forEach(_func);
  }

  function forEachRollbackByState(IGovernor.ProposalState _state, function(RollbackProposal memory) external _func)
    public
    countCall("forEachRollbackByState")
  {
    _rollbackSet.forEachByState(_state, _func);
  }

  function forEachRollbackQueuedButNotExecutable(function(RollbackProposal memory) external _func)
    external
    countCall("forEachRollbackQueued")
  {
    _rollbackSet.forEachQueuedButNotExecutable(_func);
  }

  function getRollbackSetCount() external countCall("getRollbackSetCount") returns (uint256) {
    return _rollbackSet.count();
  }

  function getRollbackProposal(uint256 _index)
    external
    countCall("getRollbackProposal")
    returns (RollbackProposal memory)
  {
    return _rollbackSet.proposals[_index];
  }
}
