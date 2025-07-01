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
import {Rollback} from "interfaces/IURM.sol";
import {RollbackSet, LibRollbackSet, RollbackProposal} from "test/helpers/RollbackSet.sol";

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
  uint256 public ghost_randByStateReverts;
  uint256 public ghost_randByStatesReverts;
  uint256 public ghost_invalidOperationReverts;
  uint256 public ghost_contractReverts;
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

  /// @notice Generate a rollback proposal with random transactions
  /// @param _rollbackFee Fee parameter for randomization
  /// @param _rollbackGuardian Guardian parameter for randomization
  /// @return _targets Array of target addresses
  /// @return _values Array of values
  /// @return _calldatas Array of calldata
  function _generateRollback(uint256 _rollbackFee, address _rollbackGuardian)
    internal
    view
    returns (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas)
  {
    // Randomly decide between 1 or 2 rollback transactions
    uint256 _numTransactions = (_rollbackFee % 2) + 1; // 1 or 2

    // Create rollback transaction arrays
    _targets = new address[](_numTransactions);
    _values = new uint256[](_numTransactions);
    _calldatas = new bytes[](_numTransactions);

    for (uint256 _i = 0; _i < _numTransactions; _i++) {
      // Select a random target for each transaction
      uint256 _targetIndex = bound(_rollbackFee + _i, 0, targets.length - 1);
      FakeProtocolContract _target = targets[_targetIndex];

      // Select a random selector for each transaction
      uint256 _selectorIndex = bound(uint256(uint160(_rollbackGuardian)) + _i, 0, selectors.length - 1);
      bytes4 _selector = selectors[_selectorIndex];

      _targets[_i] = address(_target);
      _values[_i] = 0;

      // Encode the calldata based on the selector
      if (_selector == FakeProtocolContract.setFee.selector) {
        _calldatas[_i] = abi.encodeWithSelector(_selector, _rollbackFee);
      } else {
        _calldatas[_i] = abi.encodeWithSelector(_selector, _rollbackGuardian);
      }
    }
  }

  /// @notice Propose a rollback
  /// @param _rollbackFee The new fee
  /// @param _rollbackGuardian The new guardian
  function propose(uint256 _rollbackFee, address _rollbackGuardian) public countCall("propose") {
    // Get the rollback transactions
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas) =
      _generateRollback(_rollbackFee, _rollbackGuardian);

    // Get the rollback ID
    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, DESCRIPTION);

    // Only propose if it doesn't already exist
    if (_rollbackSet.contains(_rollbackId)) {
      ghost_rollbackExistsReverts++;
      revert("Rollback already exists");
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
  function queue(uint256 _randomIndex) public countCall("queue") {
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
      ghost_contractReverts++;
      revert("Unexpected contract revert during valid queue operation");
    }
  }

  function wrapBeforeExpiryAndQueue(uint256 _randomIndex) public countCall("wrapBeforeExpiryAndQueue") {
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
      ghost_contractReverts++;
      revert("Unexpected contract revert during valid wrapBeforeExpiryAndQueue operation");
    }
  }

  /// @notice Execute a valid rollback proposal
  /// @param _randomIndex Used to randomly select an executable proposal
  function execute(uint256 _randomIndex) public countCall("execute") {
    // Only proceed if there are active proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Active)) {
      return;
    }

    // Get a random active proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Active, _randomIndex);

    // Execute the proposal
    vm.prank(guardian);
    try urm.execute(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      ghost_contractReverts++;
      revert("Unexpected contract revert during valid execute operation");
    }
  }

  function warpAndExecute(uint256 _randomIndex) public countCall("warpAndExecute") {
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
      ghost_contractReverts++;
      revert("Unexpected contract revert during valid warpAndExecute operation");
    }
  }

  /// @notice Cancel a valid rollback proposal
  /// @param _randomIndex Used to randomly select a cancellable proposal
  function cancel(uint256 _randomIndex) public countCall("cancel") {
    IGovernor.ProposalState[] memory _validStates = new IGovernor.ProposalState[](2);
    _validStates[0] = IGovernor.ProposalState.Active;
    _validStates[1] = IGovernor.ProposalState.Queued;

    // Only proceed if there are proposals in valid states for cancellation
    if (!_rollbackSet.hasProposalsInStates(_validStates)) {
      return;
    }

    // Get a random queued/active proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_validStates, _randomIndex);

    // Cancel the proposal
    vm.prank(guardian);
    try urm.cancel(
      _randomProposal.targets, _randomProposal.values, _randomProposal.calldatas, _randomProposal.description
    ) {
      // Success
    } catch {
      ghost_contractReverts++;
      revert("Unexpected contract revert during valid cancel operation");
    }
  }

  /// @notice Attempt to queue a random rollback proposal (should revert if not in correct state)
  /// @param _randomIndex Used to randomly select any proposal
  function invalidQueue(uint256 _randomIndex) public countCall("invalidQueue") {
    // Only proceed if there are any proposals
    if (_rollbackSet.count() == 0) {
      return;
    }

    // Get a random proposal regardless of state
    RollbackProposal memory _randomProposal = _rollbackSet.rand(_randomIndex);

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
  function invalidExecute(uint256 _randomIndex) public countCall("invalidExecute") {
    // Get a random proposal from invalid states for execution
    IGovernor.ProposalState[] memory _invalidStates = new IGovernor.ProposalState[](5);
    _invalidStates[0] = IGovernor.ProposalState.Pending;
    _invalidStates[1] = IGovernor.ProposalState.Queued;
    _invalidStates[2] = IGovernor.ProposalState.Canceled;
    _invalidStates[3] = IGovernor.ProposalState.Executed;
    _invalidStates[4] = IGovernor.ProposalState.Expired;

    // Only proceed if there are proposals in invalid states
    if (!_rollbackSet.hasProposalsInStates(_invalidStates)) {
      return;
    }

    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_invalidStates, _randomIndex);

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
  function invalidCancel(uint256 _randomIndex) public countCall("invalidCancel") {
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
  function invalidCallerOnQueue(uint256 _randomIndex, address _caller) public countCall("invalidCallerOnQueue") {
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
  function invalidCallerOnExecute(uint256 _randomIndex, address _caller) public countCall("invalidCallerOnExecute") {
    // Assume caller is not the guardian
    vm.assume(_caller != guardian);

    // Only proceed if there are active proposals
    if (!_rollbackSet.hasProposalsInState(IGovernor.ProposalState.Active)) {
      return;
    }

    // Get a random active proposal
    RollbackProposal memory _randomProposal = _rollbackSet.randByState(IGovernor.ProposalState.Active, _randomIndex);

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
  function invalidCallerOnCancel(uint256 _randomIndex, address _caller) public countCall("invalidCallerOnCancel") {
    // Assume caller is not the guardian
    vm.assume(_caller != guardian);

    // Get a random active/queued proposal
    IGovernor.ProposalState[] memory _validStates = new IGovernor.ProposalState[](2);
    _validStates[0] = IGovernor.ProposalState.Active;
    _validStates[1] = IGovernor.ProposalState.Queued;

    // Only proceed if there are proposals in valid states for cancellation
    if (!_rollbackSet.hasProposalsInStates(_validStates)) {
      return;
    }

    RollbackProposal memory _randomProposal = _rollbackSet.randByStates(_validStates, _randomIndex);

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
    console.log("ghost_contractReverts", ghost_contractReverts);
    console.log("ghost_randByStateReverts", ghost_randByStateReverts);
    console.log("ghost_randByStatesReverts", ghost_randByStatesReverts);

    // Calculate total expected reverts
    uint256 totalExpectedReverts = ghost_rollbackExistsReverts + ghost_invalidOperationReverts
      + ghost_authorizationReverts + ghost_randByStateReverts + ghost_randByStatesReverts;
    console.log("-------------------");
    console.log("TOTAL EXPECTED REVERTS:", totalExpectedReverts);
    console.log("(includes: duplicate rollbacks, invalid operations, auth failures, random selection errors)");
    console.log("UNEXPECTED REVERTS:", ghost_contractReverts);
    console.log("-------------------");
  }

  function forEachRollback(function(RollbackProposal memory) external _func) public {
    _rollbackSet.forEach(_func);
  }

  function forEachRollbackByState(IGovernor.ProposalState _state, function(RollbackProposal memory) external _func) public {
    _rollbackSet.forEachByState(_state, _func);
  }

  function getRollbackSetCount() public view returns (uint256) {
    return _rollbackSet.count();
  }

  function getRollbackProposal(uint256 _index) public view returns (RollbackProposal memory) {
    require(_index < _rollbackSet.proposals.length, "Index out of bounds");
    return _rollbackSet.proposals[_index];
  }
}
