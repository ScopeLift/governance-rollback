// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// External imports
import {Test} from "forge-std/Test.sol";
// Internal imports
import {RollbackManagerTimelockCompoundDeploymentIntegrationTest} from
  "test/RollbackManagerTimelockCompoundDeployment.integration.t.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {GovernorHelperCompound} from "test/helpers/GovernorHelperCompound.sol";
import {FakeProtocolRollbackTestHelper} from "test/fakes/FakeProtocolRollbackTestHelper.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";
import {RollbackManagerTimelockCompoundDeployInput} from "script/RollbackManagerTimelockCompoundDeployInput.sol";
import {ProposeTransferOwnershipToShim} from "script/2_ProposeTransferOwnershipToShim.s.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @notice Integration tests to verify the impact of the governance upgrade on existing proposals at different
/// lifecycle stages
/// @dev - docs/COMPOUND_GOVERNANCE_UPGRADE_IMPACT.md
contract CompoundGovernanceUpgradeImpactIntegrationTest is Test, RollbackManagerTimelockCompoundDeployInput {
  FakeProtocolContract public fakeProtocolContract;
  GovernorHelperCompound public govHelper;
  FakeProtocolRollbackTestHelper public rollbackHelper;
  RollbackManagerTimelockCompoundDeploymentIntegrationTest public deployScripts;
  address public timelockMultiAdminShim;
  RollbackManagerTimelockCompound public rollbackManager;
  Proposal public proposalBeforeUpgrade;
  Proposal public proposalAfterUpgrade;

  // Test addresses
  address public proposer;

  address public feeGuardianWhenProposalIsExecuted = makeAddr("feeGuardianWhenProposalIsExecuted");
  uint256 public feeWhenProposalIsExecuted = 50;

  address public feeGuardianWhenRollbackIsExecuted = makeAddr("feeGuardianWhenRollbackIsExecuted");
  uint256 public feeWhenRollbackIsExecuted = 1;

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);
    deployScripts = new RollbackManagerTimelockCompoundDeploymentIntegrationTest();

    (timelockMultiAdminShim, rollbackManager, govHelper, proposer) = deployScripts.onlyDeployShimAndRollbackManager();
    // Deploy FakeProtocolContract with Compound Timelock as owner
    fakeProtocolContract = new FakeProtocolContract(COMPOUND_TIMELOCK);
    // Setup rollback helper and generate proposal before upgrade
    rollbackHelper = new FakeProtocolRollbackTestHelper(fakeProtocolContract, rollbackManager);

    proposalBeforeUpgrade =
      rollbackHelper.generateProposalWithoutRollback(feeWhenProposalIsExecuted, feeGuardianWhenProposalIsExecuted);
  }

  function _proposeUpgradeAndExecuteProposalWithRoll() internal {
    (timelockMultiAdminShim, rollbackManager, govHelper, proposer) =
      deployScripts.onlyProposeTransferTimelockAdminToShim(timelockMultiAdminShim);
  }

  function _proposeAndQueueRollbackUpgrade(address _shimAddress) private returns (Proposal memory _upgradeProposal) {
    ProposeTransferOwnershipToShim _script = new ProposeTransferOwnershipToShim();
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, string memory _description) =
      _script.generateProposal(_shimAddress);

    _upgradeProposal = Proposal(_targets, _values, _calldatas, _description);

    // Propose, vote, and queue using the helper (but do NOT execute)
    govHelper.submitPassAndQueue(proposer, _upgradeProposal);

    // Roll to the block after the timelock delay
    uint256 _timeLockDelay = govHelper.timelock().delay();
    vm.warp(block.timestamp + _timeLockDelay + 1);

    return _upgradeProposal;
  }

  function onlyProposeAndQueueTransferTimelockAdminToShim(address _timelockMultiAdminShim)
    internal
    returns (address, RollbackManagerTimelockCompound, GovernorHelperCompound, address)
  {
    ProposeTransferOwnershipToShim _script = new ProposeTransferOwnershipToShim();
    _script.setLoggingSilenced(true); // Silence logging

    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      _script.generateProposal(_timelockMultiAdminShim);

    Proposal memory proposal = Proposal(targets, values, calldatas, description);

    govHelper.submitPassAndQueue(proposer, proposal);
    return (address(timelockMultiAdminShim), rollbackManager, govHelper, proposer);
  }

  /// @notice Test that a proposal queued before the upgrade executes via the Shim
  function test_ProposalQueuedBeforeUpgrade_ExecutesViaShim() public {
    // 0. Verify initial state
    assertNotEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertNotEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 1. Submit, vote, and queue proposal (before upgrade)
    govHelper.submitPassAndQueue(proposer, proposalBeforeUpgrade);

    // 2. Upgrade to Shim
    _proposeUpgradeAndExecuteProposalWithRoll();

    // 3. Execute via Shim
    govHelper.executeQueuedProposal(proposalBeforeUpgrade);

    // 4. Verify execution
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }

  /// @notice Test that a proposal queued after the upgrade executes via the Shim
  function test_ProposalQueuedAfterUpgrade_ExecutesViaShim() external {
    // 0. Verify initial state
    assertNotEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertNotEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 1. Upgrade to Shim
    _proposeUpgradeAndExecuteProposalWithRoll();

    // 2. Submit, vote, queue, and execute all through Governor → Shim
    govHelper.submitPassAndQueue(proposer, proposalBeforeUpgrade);

    // 3. Execute via Shim
    govHelper.executeQueuedProposal(proposalBeforeUpgrade);

    // 4. Verify execution
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }

  /// @notice Test that a proposal that was proposed and passed voting before the upgrade
  /// can be queued and executed after the upgrade
  function test_ProposalSucceededBeforeUpgrade_CanQueuePostUpgrade() external {
    // 0. Verify initial state
    assertNotEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertNotEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 1. Propose → Vote (succeeds, not queued)
    govHelper.submitAndPassProposal(proposer, proposalBeforeUpgrade);

    // 2. Upgrade to Shim
    _proposeUpgradeAndExecuteProposalWithRoll();

    // 3. Queue → Execute via Shim
    govHelper.queueProposal(proposalBeforeUpgrade);
    govHelper.executeQueuedProposal(proposalBeforeUpgrade);

    // 4. ✅ Execution works
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }

  function test_ProposalVotingDuringUpgrade_ContinuesAndExecutes() external {
    // 0. Verify initial state
    assertNotEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertNotEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    Proposal memory _upgradeProposal = _proposeAndQueueRollbackUpgrade(timelockMultiAdminShim);

    // 2. Propose and start voting on the normal proposal
    uint256 normalProposalId = govHelper.submitProposalWithRoll(proposer, proposalBeforeUpgrade);
    vm.roll(govHelper.governor().proposalSnapshot(normalProposalId) + 1);
    govHelper.castVotesViaDelegates(normalProposalId, 0, 3);

    // 3. Execute the upgrade proposal (timelock admin changes)
    govHelper.executeProposal(_upgradeProposal);

    // 4. Accept Admin role to the shim
    TimelockMultiAdminShim(payable(timelockMultiAdminShim)).acceptAdmin();

    // 5. Add remaining votes and queue and execute the normal proposal
    govHelper.passProposalWithRoll(normalProposalId, 3, 6);
    govHelper.queueProposal(proposalBeforeUpgrade);
    govHelper.executeQueuedProposal(proposalBeforeUpgrade);

    // 6. ✅ Execution works
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }

  /// @notice Test that a proposal requiring ETH works when timelock has ETH
  /// @dev This test demonstrates that the current implementation works for proposals
  ///      that require ETH to be sent FROM the timelock (not WITH the execute call)
  function test_ProposalRequiringEth_WorksWhenTimelockHasEth() external {
    uint256 requiredEthAmount = 1 ether;

    // 0. Record initial balance
    uint256 initialBalance = address(fakeProtocolContract).balance;

    // 1. Send ETH to the Compound Timelock so it has funds to spend
    vm.deal(COMPOUND_TIMELOCK, requiredEthAmount);
    assertEq(COMPOUND_TIMELOCK.balance, requiredEthAmount);

    // 2. Create a proposal that requires ETH to be sent
    address[] memory targets = new address[](1);
    targets[0] = address(fakeProtocolContract);

    uint256[] memory values = new uint256[](1);
    values[0] = requiredEthAmount;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(fakeProtocolContract.setFeeWithEth.selector, requiredEthAmount);

    string memory description = "Test proposal requiring ETH";
    Proposal memory ethProposal = Proposal(targets, values, calldatas, description);

    // 3. Upgrade to Shim
    _proposeUpgradeAndExecuteProposalWithRoll();

    // 4. Submit, vote, queue, and execute the ETH proposal
    govHelper.submitPassAndQueue(proposer, ethProposal);
    govHelper.executeQueuedProposal(ethProposal);

    // 5. Verify execution - the proposal should work because timelock has ETH
    assertEq(address(fakeProtocolContract).balance, initialBalance + requiredEthAmount);
    assertEq(COMPOUND_TIMELOCK.balance, 0); // ETH should be spent
  }

  /// @notice Test that a proposal requiring ETH works when we send ETH along with the execute call
  /// @dev This test demonstrates the scenario where ETH is sent WITH the execute call (not FROM the timelock)
  function test_ProposalRequiringEth_WorksWhenEthIsSentAlongWithExecuteCall() external {
    uint256 requiredEthAmount = 1 ether;

    // 0. Verify initial state - contract should have no ETH initially
    uint256 initialBalance = address(fakeProtocolContract).balance;
    uint256 initialTimelockBalance = COMPOUND_TIMELOCK.balance;

    // 1. Create a proposal that requires ETH to be sent
    address[] memory targets = new address[](1);
    targets[0] = address(fakeProtocolContract);

    uint256[] memory values = new uint256[](1);
    values[0] = requiredEthAmount;

    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSelector(fakeProtocolContract.setFeeWithEth.selector, requiredEthAmount);

    string memory description = "Test proposal requiring ETH";
    Proposal memory ethProposal = Proposal(targets, values, calldatas, description);

    // 2. Upgrade to Shim
    _proposeUpgradeAndExecuteProposalWithRoll();

    // 3. Submit, vote, and queue the ETH proposal
    govHelper.submitPassAndQueue(proposer, ethProposal);

    // 4. Execute with ETH
    govHelper.executeQueuedProposal{value: requiredEthAmount}(ethProposal);
    assertEq(address(fakeProtocolContract).balance, initialBalance + requiredEthAmount);
    assertEq(COMPOUND_TIMELOCK.balance, initialTimelockBalance);
  }
}
