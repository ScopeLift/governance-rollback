// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.30;

import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {URMCore} from "../../src/contracts/URMCore.sol";

struct RollbackProposal {
  address[] targets;
  uint256[] values;
  bytes[] calldatas;
  string description;
  uint256 rollbackId;
}

struct RollbackSet {
  RollbackProposal[] proposals;
  mapping(uint256 => bool) saved; // rollbackId => exists
  address urm; // URM contract address for state queries
}

library LibRollbackSet {
  function setURM(RollbackSet storage _s, address _urm) internal {
    _s.urm = _urm;
  }

  function add(RollbackSet storage _s, RollbackProposal memory _proposal) internal {
    if (!_s.saved[_proposal.rollbackId]) {
      _s.proposals.push(_proposal);
      _s.saved[_proposal.rollbackId] = true;
    }
  }

  function contains(RollbackSet storage _s, uint256 _rollbackId) internal view returns (bool) {
    return _s.saved[_rollbackId];
  }

  function count(RollbackSet storage _s) internal view returns (uint256) {
    return _s.proposals.length;
  }

  function countByState(RollbackSet storage _s, IGovernor.ProposalState _state) internal view returns (uint256) {
    uint256 _count = 0;
    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      if (URMCore(_s.urm).state(_s.proposals[_i].rollbackId) == _state) {
        _count++;
      }
    }
    return _count;
  }

  function countQueuedButExecutable(RollbackSet storage _s) internal view returns (uint256) {
    // Get all queued proposals
    RollbackProposal[] memory _queuedProposals = getByState(_s, IGovernor.ProposalState.Queued);
    uint256 _count = 0;

    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _count++;
      }
    }

    return _count;
  }

  function countQueuedButNotExecutable(RollbackSet storage _s) internal view returns (uint256) {
    // Get all queued proposals
    RollbackProposal[] memory _queuedProposals = getByState(_s, IGovernor.ProposalState.Queued);
    uint256 _count = 0;

    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (!URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _count++;
      }
    }

    return _count;
  }

  function getByState(RollbackSet storage _s, IGovernor.ProposalState _state)
    internal
    view
    returns (RollbackProposal[] memory)
  {
    // Count matching proposals first
    uint256 _count = 0;
    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      if (URMCore(_s.urm).state(_s.proposals[_i].rollbackId) == _state) {
        _count++;
      }
    }

    // Create result array and populate
    RollbackProposal[] memory _result = new RollbackProposal[](_count);
    uint256 _index = 0;
    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      if (URMCore(_s.urm).state(_s.proposals[_i].rollbackId) == _state) {
        _result[_index] = _s.proposals[_i];
        _index++;
      }
    }

    return _result;
  }

  function rand(RollbackSet storage _s, uint256 _seed) internal view returns (RollbackProposal memory) {
    if (_s.proposals.length > 0) {
      return _s.proposals[_seed % _s.proposals.length];
    } else {
      revert("No proposals available");
    }
  }

  function randByState(RollbackSet storage _s, IGovernor.ProposalState _state, uint256 _seed)
    internal
    view
    returns (RollbackProposal memory)
  {
    RollbackProposal[] memory _matching = getByState(_s, _state);
    if (_matching.length > 0) {
      return _matching[_seed % _matching.length];
    }
    revert("No proposals available in requested state");
  }

  function randQueuedButNotExecutable(RollbackSet storage _s, uint256 _seed)
    internal
    view
    returns (RollbackProposal memory)
  {
    // Get all queued proposals
    RollbackProposal[] memory _queuedProposals = getByState(_s, IGovernor.ProposalState.Queued);

    if (_queuedProposals.length == 0) {
      revert("No queued proposals available");
    }

    // Count how many are not executable
    uint256 _count = 0;
    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (!URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _count++;
      }
    }

    if (_count == 0) {
      revert("No queued proposals available which are not executable");
    }

    // Create array for non-executable proposals
    RollbackProposal[] memory _nonExecutableProposals = new RollbackProposal[](_count);
    uint256 _index = 0;

    // Populate the array with non-executable proposals
    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (!URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _nonExecutableProposals[_index] = _queuedProposals[_i];
        _index++;
      }
    }

    // Use seed to get a random one
    return _nonExecutableProposals[_seed % _count];
  }

  function randExecutable(RollbackSet storage _s, uint256 _seed) internal view returns (RollbackProposal memory) {
    // Get all queued proposals
    RollbackProposal[] memory _queuedProposals = getByState(_s, IGovernor.ProposalState.Queued);

    if (_queuedProposals.length == 0) {
      revert("No queued proposals available");
    }

    // Count how many are executable
    uint256 _count = 0;
    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _count++;
      }
    }

    if (_count == 0) {
      revert("No queued proposals available for execution");
    }

    // Create array for executable proposals
    RollbackProposal[] memory _executableProposals = new RollbackProposal[](_count);
    uint256 _index = 0;

    // Populate the array with executable proposals
    for (uint256 _i = 0; _i < _queuedProposals.length; _i++) {
      if (URMCore(_s.urm).isRollbackExecutable(_queuedProposals[_i].rollbackId)) {
        _executableProposals[_index] = _queuedProposals[_i];
        _index++;
      }
    }

    // Use seed to get a random one
    return _executableProposals[_seed % _count];
  }

  function randByStates(RollbackSet storage _s, IGovernor.ProposalState[] memory _states, uint256 _seed)
    internal
    view
    returns (RollbackProposal memory)
  {
    // Collect all proposals that match any of the requested states
    RollbackProposal[] memory _matching = new RollbackProposal[](_s.proposals.length);
    uint256 _count = 0;

    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      IGovernor.ProposalState _proposalState = URMCore(_s.urm).state(_s.proposals[_i].rollbackId);

      // Check if this proposal's state is in our target states
      for (uint256 _j = 0; _j < _states.length; _j++) {
        if (_proposalState == _states[_j]) {
          _matching[_count] = _s.proposals[_i];
          _count++;
          break; // Found a match, move to next proposal
        }
      }
    }

    if (_count > 0) {
      return _matching[_seed % _count];
    }
    revert("No proposals available in any of the requested states");
  }

  function hasProposalsInState(RollbackSet storage _s, IGovernor.ProposalState _state) internal view returns (bool) {
    return countByState(_s, _state) > 0;
  }

  function hasProposalsInStates(RollbackSet storage _s, IGovernor.ProposalState[] memory _states)
    internal
    view
    returns (bool)
  {
    for (uint256 i = 0; i < _states.length; i++) {
      if (countByState(_s, _states[i]) > 0) {
        return true;
      }
    }
    return false;
  }

  function hasQueuedProposalsWhichAreExecutable(RollbackSet storage _s) internal view returns (bool) {
    return countQueuedButExecutable(_s) > 0;
  }

  function hasQueuedProposalsWhichAreNotExecutable(RollbackSet storage _s) internal view returns (bool) {
    return countQueuedButNotExecutable(_s) > 0;
  }

  function hasExecutableProposals(RollbackSet storage _s) internal view returns (bool) {
    return countQueuedButExecutable(_s) > 0;
  }

  function forEach(RollbackSet storage _s, function(RollbackProposal memory) external _func) internal {
    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      _func(_s.proposals[_i]);
    }
  }

  function forEachByState(
    RollbackSet storage _s,
    IGovernor.ProposalState _state,
    function(RollbackProposal memory) external _func
  ) internal {
    RollbackProposal[] memory _proposals = getByState(_s, _state);
    for (uint256 _i = 0; _i < _proposals.length; _i++) {
      _func(_proposals[_i]);
    }
  }

  function forEachQueuedButNotExecutable(RollbackSet storage _s, function(RollbackProposal memory) external _func)
    internal
  {
    RollbackProposal[] memory _queued = getByState(_s, IGovernor.ProposalState.Queued);
    for (uint256 i = 0; i < _queued.length; i++) {
      if (!URMCore(_s.urm).isRollbackExecutable(_queued[i].rollbackId)) {
        _func(_queued[i]);
      }
    }
  }

  function reduce(
    RollbackSet storage _s,
    uint256 _acc,
    function(uint256, RollbackProposal memory) external returns (uint256) _func
  ) internal returns (uint256) {
    for (uint256 _i = 0; _i < _s.proposals.length; _i++) {
      _acc = _func(_acc, _s.proposals[_i]);
    }
    return _acc;
  }

  function reduceByState(
    RollbackSet storage _s,
    IGovernor.ProposalState _state,
    uint256 _acc,
    function(uint256, RollbackProposal memory) external returns (uint256) _func
  ) internal returns (uint256) {
    RollbackProposal[] memory _proposals = getByState(_s, _state);
    for (uint256 _i = 0; _i < _proposals.length; _i++) {
      _acc = _func(_acc, _proposals[_i]);
    }
    return _acc;
  }
}
