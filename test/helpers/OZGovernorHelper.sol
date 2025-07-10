// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal imports
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {Proposal} from "test/helpers/Proposal.sol";

contract OZGovernorHelper is Test, URMOZDeployInput {
  IGovernor public governor;
  TimelockController public timelock;

  // Real delegates with significant voting power (these would be specific to your OZ governance)
  address[] public majorDelegates = [
    0x7C4b6f39D62Ca59ED3a4EFD4c347E23417ec5d5f, // scopelift
    0x3Af2b57b8c7499a163e93a20698A41338963c379, // pumper
    0x49Df3CCa2670eB0D591146B16359fe336e476F29, // stefa2k.rocklogic.eth
    0x556fedf2213A31c7Ab9F8bc8Db5B2254261A5B0b, // Dmitry Gusakov
    0xF4880975728EE25A96C701c225c9EF58Eebe5a5b, // 🦍🦍🦍🦍
    0x00De4B13153673BCAE2616b67bf822500d325Fc3, // kev.eth
    0x1B686eE8E31c5959D9F5BBd8122a58682788eeaD // L2 beat
  ];

  // OZ governance constants (Obol-specific)
  uint256 constant VOTING_DELAY = 7200;
  uint256 constant VOTING_PERIOD = 36_000; // ~6.4 days
  uint256 constant PROPOSAL_THRESHOLD = 30_000e18; // 30k tokens (Obol threshold)

  function setUp() public {
    governor = IGovernor(OZ_GOVERNOR);
    timelock = TimelockController(OZ_TIMELOCK);

    // Label important addresses
    vm.label(OZ_GOVERNOR, "OZGovernor");
    vm.label(OZ_TIMELOCK, "OZTimelock");
    for (uint256 _i = 0; _i < majorDelegates.length; _i++) {
      vm.label(majorDelegates[_i], string.concat("Delegate", vm.toString(_i)));
    }
  }

  /* Begin OZGovernor-related helper methods */

  function getRandomProposer() public returns (address) {
    return majorDelegates[vm.randomUint(0, majorDelegates.length - 1)];
  }

  function submitProposalWithRoll(Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(getRandomProposer());
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

    vm.roll(vm.getBlockNumber() + VOTING_DELAY + 1);
  }

  function submitProposalWithRoll(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(_proposer);
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

    vm.roll(vm.getBlockNumber() + VOTING_DELAY + 1);
  }

  function rollToVotingStart(uint256 _proposalId) public {
    uint256 startBlock = governor.proposalSnapshot(_proposalId) + 1;
    vm.roll(startBlock);
  }

  function submitProposalWithoutRoll(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(_proposer);
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);
  }

  function passProposalWithRoll(uint256 _proposalId) public {
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }
    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
  }

  function passProposalWithRoll(uint256 _proposalId, uint256 _startDelegateIndex, uint256 _endDelegateIndex) public {
    for (uint256 _index = _startDelegateIndex; _index < _endDelegateIndex; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }
    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
  }

  function castVotesViaDelegates(uint256 _proposalId, uint256 _startDelegateIndex, uint256 _endDelegateIndex) public {
    for (uint256 _index = _startDelegateIndex; _index < _endDelegateIndex; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }
  }

  function queueProposal(Proposal memory _proposal) public {
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function queueProposalWithWarp(Proposal memory _proposal) public {
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
    uint256 delay = timelock.getMinDelay();
    vm.warp(block.timestamp + delay + 1);
  }

  function passAndQueueProposalWithRoll(uint256 _proposalId, Proposal memory _proposal) public {
    uint256 _timeLockDelay = timelock.getMinDelay();
    passProposalWithRoll(_proposalId);
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));

    vm.warp(block.timestamp + _timeLockDelay + 1);
  }

  function passQueueAndExecuteProposalWithRoll(uint256 _proposalId, Proposal memory _proposal) public {
    // Get the actual voting start block for this proposal
    uint256 startBlock = governor.proposalSnapshot(_proposalId) + 1;
    vm.roll(startBlock);

    uint256 _timeLockDelay = timelock.getMinDelay();
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }

    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));

    vm.warp(block.timestamp + _timeLockDelay + 1);
    governor.execute(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function failProposalWithRoll(uint256 _proposalId) public {
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 0); // 0 = Against
    }

    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
  }

  function submitAndPassProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = submitProposalWithoutRoll(_proposer, _proposal);

    // Wait for voting to start
    uint256 startBlock = governor.proposalSnapshot(_proposalId) + 1;
    vm.roll(startBlock);

    passProposalWithRoll(_proposalId);

    return _proposalId;
  }

  function submitPassAndQueue(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
    // 1. Submit proposal (without rolling)
    _proposalId = submitProposalWithoutRoll(_proposer, _proposal);

    // 2. Wait for voting to start
    uint256 startBlock = governor.proposalSnapshot(_proposalId) + 1;
    vm.roll(startBlock);

    // 3. Vote on proposal
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }

    // 4. Wait for voting to end
    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);

    // 5. Queue proposal
    queueProposalWithWarp(_proposal);

    return _proposalId;
  }

  function submitPassQueueAndExecuteProposalWithRoll(address _proposer, Proposal memory _proposal)
    public
    returns (uint256)
  {
    uint256 _proposalId = submitProposalWithRoll(_proposer, _proposal);
    passQueueAndExecuteProposalWithRoll(_proposalId, _proposal);
    return _proposalId;
  }

  function submitPassScheduleAndExecuteProposalWithRoll(address _proposer, Proposal memory _proposal)
    public
    returns (uint256)
  {
    // 1. Submit proposal
    uint256 _proposalId = submitProposalWithRoll(_proposer, _proposal);

    // 2. Pass proposal (vote for)
    passProposalWithRoll(_proposalId);

    // 3. Schedule (queue) proposal
    queueProposalWithWarp(_proposal);

    // 4. Execute proposal
    governor.execute(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));

    return _proposalId;
  }

  function submitAndFailProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = submitProposalWithRoll(_proposer, _proposal);
    failProposalWithRoll(_proposalId);
    return _proposalId;
  }

  function getMajorDelegate(uint256 _index) external view returns (address) {
    return majorDelegates[_index];
  }

  function executeQueuedProposal(Proposal memory _proposal) public {
    uint256 _timeLockDelay = timelock.getMinDelay();
    vm.warp(block.timestamp + _timeLockDelay + 1);
    governor.execute(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function executeProposal(Proposal memory _proposal) public {
    governor.execute(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function cancelProposal(Proposal memory _proposal) public {
    governor.cancel(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  /* End OZGovernor-related helper methods */
}
