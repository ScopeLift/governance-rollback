// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal imports
import {DeployInput} from "script/DeployInput.sol";

interface ICompoundGovernor {
  function timelock() external view returns (address);
  function token() external view returns (address);
  function whitelistGuardian() external view returns (address);
  function proposalGuardian() external view returns (address account, uint96 expiration);
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256);
  function castVote(uint256 proposalId, uint8 support) external returns (uint256);
  function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    external
    returns (uint256);
  function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    external
    payable
    returns (uint256);
  function queue(uint256 proposalId) external returns (uint256);
  function execute(uint256 proposalId) external payable returns (uint256);
  function hashProposal(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
  ) external view returns (uint256);
  function setWhitelistAccountExpiration(address account, uint256 expiration) external;
  function isWhitelisted(address account) external view returns (bool);
  function proposalSnapshot(uint256 proposalId) external view returns (uint256);
  function proposalVoteStart(uint256 proposalId) external view returns (uint256);
  function proposalEta(uint256 proposalId) external view returns (uint256);
}

contract CompoundGovernorHelper is Test, DeployInput {
  struct Proposal {
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  ICompoundGovernor public governor;
  ICompoundTimelock public timelock;
  address public whitelistGuardian;
  address public proposalGuardian;

  // Real Compound delegates with significant voting power
  address[] public majorDelegates = [
    0x9AA835Bc7b8cE13B9B0C9764A52FbF71AC62cCF1, // a16z
    0x683a4F9915D6216f73d6Df50151725036bD26C02, // Gauntlet
    0x8169522c2C57883E8EF80C498aAB7820dA539806, // Geoffrey Hayes
    0x8d07D225a769b7Af3A923481E1FdF49180e6A265, // MonetSupply
    0x66cD62c6F8A4BB0Cd8720488BCBd1A6221B765F9, // all the colors
    0x13BDaE8c5F0fC40231F0E6A4ad70196F59138548 // Michigan Blockchain
  ];

  // Compound governance constants
  uint256 constant VOTING_DELAY = 1;
  uint256 constant VOTING_PERIOD = 45_818; // ~6.4 days
  uint256 constant PROPOSAL_THRESHOLD = 100_000e18; // 100k COMP

  function setUp() public {
    governor = ICompoundGovernor(COMPOUND_GOVERNOR);
    timelock = ICompoundTimelock(COMPOUND_TIMELOCK);

    // console2.log("Helper: governor set", COMPOUND_GOVERNOR);
    // console2.log("Helper: timelock set", COMPOUND_TIMELOCK);

    whitelistGuardian = governor.whitelistGuardian();
    (proposalGuardian,) = governor.proposalGuardian();

    // Label important addresses
    vm.label(COMPOUND_GOVERNOR, "CompoundGovernor");
    vm.label(COMPOUND_TIMELOCK, "CompoundTimelock");
    vm.label(whitelistGuardian, "WhitelistGuardian");
    vm.label(proposalGuardian, "ProposalGuardian");
    for (uint256 _i = 0; _i < majorDelegates.length; _i++) {
      vm.label(majorDelegates[_i], string.concat("Delegate", vm.toString(_i)));
    }
  }

  /* Begin CompoundGovernor-related helper methods */

  function _getProposalId(Proposal memory _proposal) internal view returns (uint256) {
    return governor.hashProposal(
      _proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description))
    );
  }

  function _buildProposalData(string memory _signature, bytes memory _calldata) internal pure returns (bytes memory) {
    return abi.encodePacked(bytes4(keccak256(bytes(_signature))), _calldata);
  }

  function _buildAnEmptyProposal() internal pure returns (Proposal memory _proposal) {
    address[] memory _targets = new address[](1);
    uint256[] memory _values = new uint256[](1);
    bytes[] memory _calldatas = new bytes[](1);
    _proposal = Proposal(_targets, _values, _calldatas, "An Empty Proposal");
  }

  function _getRandomProposer() public returns (address) {
    return majorDelegates[vm.randomUint(0, majorDelegates.length - 1)];
  }

  function _setWhitelistedProposer(address _proposer) public {
    vm.prank(whitelistGuardian);
    governor.setWhitelistAccountExpiration(_proposer, block.timestamp + 2_000_000);
  }

  function isWhitelisted(address _proposer) public view returns (bool) {
    return governor.isWhitelisted(_proposer);
  }

  function _submitProposal(Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(_getRandomProposer());
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

    vm.roll(vm.getBlockNumber() + VOTING_DELAY + 1);
  }

  function _submitProposal(address _proposer, Proposal memory _proposal) public returns (uint256 _proposalId) {
    vm.prank(_proposer);
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);

    vm.roll(vm.getBlockNumber() + VOTING_DELAY + 1);
  }

  function _submitProposalWithoutRoll(address _proposer, Proposal memory _proposal)
    public
    returns (uint256 _proposalId)
  {
    vm.prank(_proposer);
    _proposalId = governor.propose(_proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description);
  }

  function _passProposal(uint256 _proposalId) public {
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }
    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
  }

  function _queueProposal(Proposal memory _proposal) public {
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function _queueProposalById(uint256 _proposalId) public {
    governor.queue(_proposalId);
  }

  function _passAndQueueProposal(Proposal memory _proposal, uint256 _proposalId) public {
    uint256 _timeLockDelay = timelock.delay();
    _passProposal(_proposalId);
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));

    vm.warp(block.timestamp + _timeLockDelay + 1);
  }

  function _passQueueAndExecuteProposal(Proposal memory _proposal, uint256 _proposalId) public {
    // Get the actual voting start block for this proposal (Compound Bravo: snapshot + 1)
    uint256 startBlock = governor.proposalSnapshot(_proposalId) + 1;
    vm.roll(startBlock);

    uint256 _timeLockDelay = timelock.delay();
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 1); // 1 = For
    }

    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
    governor.queue(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));

    vm.warp(block.timestamp + _timeLockDelay + 1);
    governor.execute(_proposal.targets, _proposal.values, _proposal.calldatas, keccak256(bytes(_proposal.description)));
  }

  function _failProposal(uint256 _proposalId) public {
    for (uint256 _index = 0; _index < majorDelegates.length; _index++) {
      vm.prank(majorDelegates[_index]);
      governor.castVote(_proposalId, 0); // 0 = Against
    }

    vm.roll(vm.getBlockNumber() + VOTING_PERIOD + 1);
  }

  function _submitAndPassProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = _submitProposal(address(_proposer), _proposal);
    _passProposal(uint256(_proposalId));

    return _proposalId;
  }

  function _submitPassAndQueueProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = _submitProposal(_proposer, _proposal);
    _passAndQueueProposal(_proposal, _proposalId);
    return _proposalId;
  }

  function _submitPassQueueAndExecuteProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = _submitProposal(_proposer, _proposal);
    _passQueueAndExecuteProposal(_proposal, _proposalId);
    return _proposalId;
  }

  function _submitAndFailProposal(address _proposer, Proposal memory _proposal) public returns (uint256) {
    uint256 _proposalId = _submitProposal(_proposer, _proposal);
    _failProposal(_proposalId);
    return _proposalId;
  }

  function getMajorDelegate(uint256 _index) external view returns (address) {
    return majorDelegates[_index];
  }
  /* End CompoundGovernor-related helper methods */
}
