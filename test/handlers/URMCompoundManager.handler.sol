// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

// Internal Imports
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {RollbackSet, LibRollbackSet, RollbackProposal} from "test/helpers/RollbackSet.sol";
import {RollbackTransactionGenerator} from "test/helpers/RollbackTransactionGenerator.sol";

contract URMCompoundManagerHandler is CommonBase, StdCheats, StdUtils {
  using LibRollbackSet for RollbackSet;

  URMCompoundManager public urm;

  FakeProtocolContract[] public targets;
  bytes4[] public selectors;
  string public constant DESCRIPTION = "test rollback";

  address public admin;
  address public guardian;

  // Use RollbackSet for tracking
  RollbackSet internal _rollbackSet;

  // call summary
  mapping(bytes32 => uint256) public calls;

  uint256 public ghost_rollbackExistsReverts;
  uint256 public ghost_invalidOperationReverts;
  uint256 public ghost_authorizationReverts;

  modifier countCall(bytes32 key) {
    calls[key]++;
    _;
  }

  constructor(URMCompoundManager _urm, address _admin, address _guardian, FakeProtocolContract[] memory _targets) {
    urm = _urm;
    admin = _admin;
    guardian = _guardian;

    for (uint256 i = 0; i < _targets.length; i++) {
      targets.push(_targets[i]);
    }

    selectors = [FakeProtocolContract.setFee.selector, FakeProtocolContract.setFeeGuardian.selector];

    // Set the URM address in the RollbackSet
    _rollbackSet.setURM(address(_urm));
  }

  /// @notice Propose a rollback
  /// @param _rollbackFee The new fee
  /// @param _rollbackGuardian The new guardian
  function propose(uint256 _rollbackFee, address _rollbackGuardian) external countCall("propose") {
    // Get the rollback transactions
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) = RollbackTransactionGenerator
      .generateRandomRollbackTransactions(_rollbackFee, _rollbackGuardian, targets, selectors);

    // Get the rollback ID
    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, DESCRIPTION);

    // Only propose if it doesn't already exist
    if (_rollbackSet.contains(_rollbackId)) {
      ghost_rollbackExistsReverts++;
      return; // Skip instead of reverting
    }

    vm.prank(admin);
    urm.propose(_targets, _values, _calldatas, DESCRIPTION);

    _rollbackSet.add(
      RollbackProposal({
        targets: _targets,
        values: _values,
        calldatas: _calldatas,
        description: DESCRIPTION,
        rollbackId: _rollbackId
      })
    );
  }

  /// @notice Queue a valid rollback proposal
  /// @param _randomIndex Used to randomly select a queueable proposal
  function queue(uint256 _randomIndex) external countCall("queue") {
    // Only proceed if there are pending proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Pending)) {
      return;
    }

    // Get a random proposed proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Pending, _randomIndex);

    // Queue the proposal
    vm.prank(guardian);
    try urm.queue(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      revert("Unexpected contract revert during valid queue operation");
    }
  }

  function wrapBeforeExpiryAndQueue(uint256 _randomIndex) external countCall("wrapBeforeExpiryAndQueue") {
    // Only proceed if there are expired proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Expired)) {
      return;
    }

    // Get a random expired proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Expired, _randomIndex);

    // Warp to the proposal's queueExpiresAt time
    uint256 _queueExpiresAt = urm.getRollback(_randomProposal.rollbackId).queueExpiresAt;
    vm.warp(_queueExpiresAt - 1);

    // Queue the proposal
    vm.prank(guardian);
    try urm.queue(
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
      return;
    }

    // Get a random executable proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randExecutable(_randomIndex);

    // Execute the proposal
    vm.prank(guardian);
    try urm.execute(
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
      return;
    }

    // Get a random queued proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Warp to the proposal's executableAt time
    uint256 _executableAt = urm.getRollback(_randomProposal.rollbackId).executableAt;
    vm.warp(_executableAt + 1);

    // Execute the proposal
    vm.prank(guardian);
    try urm.execute(
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
      return;
    }

    // Get a random queued proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Cancel the proposal
    vm.prank(guardian);
    try urm.cancel(
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
      return;
    }

    // Get a random proposal from invalid states
    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

    // Attempt to queue the proposal which should revert
    vm.prank(guardian);
    try urm.queue(
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
    // Get invalid states for execution (all states except Executed)
    IGovernor.ProposalState[] memory _invalidStates = new IGovernor.ProposalState[](4);
    _invalidStates[0] = IGovernor.ProposalState.Pending;
    _invalidStates[1] = IGovernor.ProposalState.Canceled;
    _invalidStates[2] = IGovernor.ProposalState.Expired;
    _invalidStates[3] = IGovernor.ProposalState.Executed;

    // Check if we have any invalid proposals or non-executable queued proposals
    bool _hasInvalidProposals = _rollbackSet.hasProposalsInStates(_invalidStates);
    bool _hasNonExecutableQueued = _rollbackSet.hasQueuedProposalsWhichAreNotExecutable();

    if (!_hasInvalidProposals && !_hasNonExecutableQueued) {
      return;
    }

    // Use the index to deterministically choose between invalid states and non-executable queued

    RollbackProposal memory _randomProposal;
    if (_hasInvalidProposals && _hasNonExecutableQueued) {
      if (_randomIndex % 2 == 0) {
        _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);
      } else {
        _randomProposal = _rollbackSet.randQueuedButNotExecutable(_randomIndex);
      }
    } else if (_hasInvalidProposals) {
      _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);
    } else {
      _randomProposal = _rollbackSet.randQueuedButNotExecutable(_randomIndex);
    }

    // Attempt to execute the proposal (should revert)
    vm.prank(guardian);
    try urm.execute(
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
      return;
    }

    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

    // Attempt to cancel the proposal (should revert)
    vm.prank(guardian);
    try urm.cancel(
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
      return;
    }

    // Get a random pending proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Pending, _randomIndex);

    // Attempt to queue with a non-guardian caller (should revert)
    vm.prank(_caller);
    try urm.queue(
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
      return;
    }

    // Get a random executable proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randExecutable(_randomIndex);

    // Attempt to execute with a non-guardian caller (should revert)
    vm.prank(_caller);
    try urm.execute(
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
      return;
    }

    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Queued, _randomIndex);

    // Attempt to cancel with a non-guardian caller (should revert)
    vm.prank(_caller);
    try urm.cancel(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // If we reach here, something is wrong - the cancel should have reverted
      revert("Cancel should have reverted for invalid caller");
    } catch {
      // Expected behavior - revert was caught
      ghost_authorizationReverts++;
    }
  }

  function callSummary() external view {
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
    console.log("-------------------");
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

  function forEachRollback(function(RollbackProposal memory) external _func) external {
    _rollbackSet.forEach(_func);
  }

  function forEachRollbackByState(IGovernor.ProposalState _state, function(RollbackProposal memory) external _func)
    public
  {
    _rollbackSet.forEachByState(_state, _func);
  }

  function forEachRollbackQueuedButNotExecutable(function(RollbackProposal memory) external _func) external {
    _rollbackSet.forEachQueuedButNotExecutable(_func);
  }

  function getRollbackSetCount() external view returns (uint256) {
    return _rollbackSet.count();
  }

  function getRollbackProposal(uint256 _index) external view returns (RollbackProposal memory) {
    return _rollbackSet.proposals[_index];
  }
}
