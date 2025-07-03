// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

// Internal Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";

contract UpgradeRegressionManagerHandler is CommonBase, StdCheats, StdUtils {
  /// @notice Enum to track the state of a rollback proposal
  enum ProposalState {
    NONE, // Not proposed
    PROPOSED, // Proposed but not queued
    QUEUED, // Queued but not executed
    EXECUTED, // Successfully executed
    CANCELLED // Cancelled

  }

  /// @notice Struct to track the state of a rollback proposal
  struct RollbackProposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
    uint256 rollbackId;
    ProposalState state;
  }

  UpgradeRegressionManager public urm;
  FakeProtocolContract public target;

  address public admin;
  address public guardian;

  // Mapping from rollbackId to proposal for O(1) lookup
  mapping(uint256 => RollbackProposal) public proposals;

  // Array to track all rollbackIds for iteration
  uint256[] public rollbackIds;

  string public constant DESCRIPTION = "test rollback";

  constructor(UpgradeRegressionManager _urm, address _admin, address _guardian, FakeProtocolContract _target) {
    // set initial state
    urm = _urm;
    admin = _admin;
    guardian = _guardian;
    target = _target;

    // set up rollback
    address[] memory _rollbackTargets = new address[](1);
    uint256[] memory _rollbackValues = new uint256[](1);
    bytes[] memory _rollbackCalldatas = new bytes[](1);

    _rollbackTargets[0] = address(_target);
    _rollbackValues[0] = 0;
    _rollbackCalldatas[0] = abi.encodeWithSelector(FakeProtocolContract.setFee.selector, 10);

    uint256 _rollbackId = urm.getRollbackId(_rollbackTargets, _rollbackValues, _rollbackCalldatas, DESCRIPTION);

    vm.prank(admin);
    try urm.propose(_rollbackTargets, _rollbackValues, _rollbackCalldatas, DESCRIPTION) {
      proposals[_rollbackId] = RollbackProposal({
        targets: _rollbackTargets,
        values: _rollbackValues,
        calldatas: _rollbackCalldatas,
        description: DESCRIPTION,
        rollbackId: _rollbackId,
        state: ProposalState.PROPOSED
      });
      rollbackIds.push(_rollbackId);
    } catch {}
  }

  /// @notice Propose a rollback
  /// @param _newFee The new fee
  function proposeRollback(uint256 _newFee) public {
    vm.prank(admin);
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);

    _targets[0] = address(target);
    _values[0] = 0;
    _calldatas[0] = abi.encodeWithSelector(FakeProtocolContract.setFee.selector, _newFee);

    uint256 _rollbackId = urm.getRollbackId(_targets, _values, _calldatas, DESCRIPTION);

    try urm.propose(_targets, _values, _calldatas, DESCRIPTION) {
      proposals[_rollbackId] = RollbackProposal({
        targets: _targets,
        values: _values,
        calldatas: _calldatas,
        description: DESCRIPTION,
        rollbackId: _rollbackId,
        state: ProposalState.PROPOSED
      });
      rollbackIds.push(_rollbackId);
    } catch {}
  }

  /// @notice Queue a valid rollback proposal
  /// @param _randomIndex Used to randomly select a queueable proposal
  function queueRollback(uint256 _randomIndex) public {
    uint256 _rollbackId = getRandomQueueableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    RollbackProposal storage _rollbackProposal = proposals[_rollbackId];

    // Check if rollback is eligible to queue
    if (!urm.isRollbackEligibleToQueue(_rollbackProposal.rollbackId)) {
      return;
    }

    vm.prank(guardian);
    try urm.queue(
      _rollbackProposal.targets, _rollbackProposal.values, _rollbackProposal.calldatas, _rollbackProposal.description
    ) {
      _rollbackProposal.state = ProposalState.QUEUED;
    } catch {}
  }

  /// @notice Execute a valid rollback proposal
  /// @param _randomIndex Used to randomly select an executable proposal
  function executeRollback(uint256 _randomIndex) public {
    uint256 _rollbackId = getRandomExecutableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    RollbackProposal storage _rollbackProposal = proposals[_rollbackId];

    // Check if rollback is ready to execute
    if (!urm.isRollbackReadyToExecute(_rollbackProposal.rollbackId)) {
      return;
    }

    vm.prank(guardian);
    try urm.execute(
      _rollbackProposal.targets, _rollbackProposal.values, _rollbackProposal.calldatas, _rollbackProposal.description
    ) {
      _rollbackProposal.state = ProposalState.EXECUTED;
    } catch {}
  }

  /// @notice Cancel a valid rollback proposal
  /// @param _randomIndex Used to randomly select a cancellable proposal
  function cancelRollback(uint256 _randomIndex) public {
    uint256 _rollbackId = getRandomQueueableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    RollbackProposal storage _rollbackProposal = proposals[_rollbackId];

    vm.prank(admin);
    try urm.cancel(
      _rollbackProposal.targets, _rollbackProposal.values, _rollbackProposal.calldatas, _rollbackProposal.description
    ) {
      _rollbackProposal.state = ProposalState.CANCELLED;
    } catch {}
  }

  /// @notice Get a random rollback ID
  /// @param _randomIndex Used to randomly select a proposal
  /// @return The rollback ID of a randomly selected proposal, or 0 if none exist
  function getRandomRollbackId(uint256 _randomIndex) public view returns (uint256) {
    uint256 _index = bound(_randomIndex, 0, rollbackIds.length - 1);
    return rollbackIds[_index];
  }

  /// @notice Get a random queueable rollback ID
  /// @param _randomIndex Used to randomly select a queueable proposal
  /// @return The rollback ID of a randomly selected queueable proposal, or 0 if none exist
  function getRandomQueueableRollbackId(uint256 _randomIndex) public view returns (uint256) {
    uint256[] memory _matchingIds = new uint256[](rollbackIds.length);
    uint256 _matchCount = 0;

    for (uint256 i = 0; i < rollbackIds.length; i++) {
      if (proposals[rollbackIds[i]].state == ProposalState.PROPOSED) {
        _matchingIds[_matchCount] = rollbackIds[i];
        _matchCount++;
      }
    }

    if (_matchCount == 0) {
      return 0;
    }

    uint256 _selectedIndex = _randomIndex % _matchCount;
    return _matchingIds[_selectedIndex];
  }

  /// @notice Get a random executable rollback ID
  /// @param _randomIndex Used to randomly select an executable proposal
  /// @return The rollback ID of a randomly selected executable proposal, or 0 if none exist
  function getRandomExecutableRollbackId(uint256 _randomIndex) public view returns (uint256) {
    uint256[] memory _matchingIds = new uint256[](rollbackIds.length);
    uint256 _matchCount = 0;

    for (uint256 i = 0; i < rollbackIds.length; i++) {
      if (proposals[rollbackIds[i]].state == ProposalState.QUEUED) {
        _matchingIds[_matchCount] = rollbackIds[i];
        _matchCount++;
      }
    }

    if (_matchCount == 0) {
      return 0;
    }

    uint256 _selectedIndex = _randomIndex % _matchCount;
    return _matchingIds[_selectedIndex];
  }

  /// @notice Warp time to expire a proposed rollback
  /// @param _randomIndex Used to randomly select a proposed proposal
  /// @return The rollback ID of the expired rollback, or 0 if none found
  function expireRollback(uint256 _randomIndex) public returns (uint256) {
    uint256 _rollbackId = getRandomQueueableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return 0;
    }

    // Get the expiry time for this rollback
    uint256 _expiresAt = urm.rollbackQueueExpiresAt(_rollbackId);
    if (_expiresAt == 0) {
      return 0; // Not in queueing state
    }

    // Warp time past the expiry window
    vm.warp(_expiresAt + 1);

    return _rollbackId;
  }

  /// @notice Warp time to make a queued rollback executable
  /// @param _randomIndex Used to randomly select a queued proposal
  /// @return The rollback ID of the executable rollback, or 0 if none found
  function makeRollbackExecutable(uint256 _randomIndex) public returns (uint256) {
    uint256 _rollbackId = getRandomExecutableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return 0;
    }

    // Get the ETA for this rollback
    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);
    if (_eta == 0) {
      return 0; // Not queued
    }

    // Warp time past the ETA to make it executable
    vm.warp(_eta + 1);

    return _rollbackId;
  }
}
