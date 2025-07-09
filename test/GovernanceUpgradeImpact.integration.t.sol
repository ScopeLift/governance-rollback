// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// External imports
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
// Internal imports
import {DeployScriptsIntegrationTest} from "test/DeployScripts.integration.t.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {CompoundGovernorHelper} from "test/helpers/CompoundGovernorHelper.sol";
import {FakeProtocolRollbackTestHelper} from "test/fakes/FakeProtocolRollbackTestHelper.sol";
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {DeployInput} from "script/DeployInput.sol";
import {ProposeTransferOwnershipToShim} from "script/2_ProposeTransferOwnershipToShim.s.sol";

/// @notice Integration tests to verify the impact of the governance upgrade on existing proposals at different
/// lifecycle stages
/// @dev - docs/GOVERNANCE_UPGRADE_IMPACT.md
contract GovernanceUpgradeImpactIntegrationTest is Test, DeployInput {
  FakeProtocolContract public fakeProtocolContract;
  CompoundGovernorHelper public govHelper;
  FakeProtocolRollbackTestHelper public rollbackHelper;
  DeployScriptsIntegrationTest public deployScripts;
  address public timelockMultiAdminShim;
  UpgradeRegressionManager public upgradeRegressionManager;
  CompoundGovernorHelper.Proposal public proposalBeforeUpgrade;
  CompoundGovernorHelper.Proposal public proposalAfterUpgrade;

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
    deployScripts = new DeployScriptsIntegrationTest();

    (timelockMultiAdminShim, upgradeRegressionManager, govHelper, proposer) = deployScripts.onlyDeployShimAndURM();
    // Deploy FakeProtocolContract with Compound Timelock as owner
    fakeProtocolContract = new FakeProtocolContract(COMPOUND_TIMELOCK);
    // Setup rollback helper and generate proposal before upgrade
    rollbackHelper = new FakeProtocolRollbackTestHelper(fakeProtocolContract, upgradeRegressionManager);

    proposalBeforeUpgrade =
      rollbackHelper.generateProposalWithoutRollback(feeWhenProposalIsExecuted, feeGuardianWhenProposalIsExecuted);
  }

  function _proposeUpgradeAndExecuteProposalWithRoll() internal {
    (timelockMultiAdminShim, upgradeRegressionManager, govHelper, proposer) =
      deployScripts.onlyProposeTransferTimelockAdminToShim(timelockMultiAdminShim);
  }

  function _proposeAndQueueRollbackUpgrade(address _shimAddress)
    private
    returns (CompoundGovernorHelper.Proposal memory _upgradeProposal)
  {
    ProposeTransferOwnershipToShim _script = new ProposeTransferOwnershipToShim();
    (address[] memory _targets, uint256[] memory _values, bytes[] memory _calldatas, string memory _description) =
      _script.generateProposal(_shimAddress);

    _upgradeProposal = CompoundGovernorHelper.Proposal(_targets, _values, _calldatas, _description);

    // Propose, vote, and queue using the helper (but do NOT execute)
    govHelper.submitPassAndQueue(proposer, _upgradeProposal);

    // Roll to the block after the timelock delay
    uint256 _timeLockDelay = govHelper.timelock().delay();
    vm.warp(block.timestamp + _timeLockDelay + 1);

    return _upgradeProposal;
  }

  function onlyProposeAndQueueTransferTimelockAdminToShim(address _timelockMultiAdminShim)
    internal
    returns (address, UpgradeRegressionManager, CompoundGovernorHelper, address)
  {
    ProposeTransferOwnershipToShim _script = new ProposeTransferOwnershipToShim();
    _script.setLoggingSilenced(true); // Silence logging

    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      _script.generateProposal(_timelockMultiAdminShim);

    CompoundGovernorHelper.Proposal memory proposal =
      CompoundGovernorHelper.Proposal(targets, values, calldatas, description);

    govHelper.submitPassAndQueue(proposer, proposal);
    return (address(timelockMultiAdminShim), upgradeRegressionManager, govHelper, proposer);
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

    CompoundGovernorHelper.Proposal memory _upgradeProposal = _proposeAndQueueRollbackUpgrade(timelockMultiAdminShim);

    // 2. Propose and start voting on the normal proposal
    uint256 normalProposalId = govHelper.submitProposalWithRoll(proposer, proposalBeforeUpgrade);
    vm.roll(govHelper.governor().proposalSnapshot(normalProposalId) + 1);
    govHelper.castVotesViaDelegates(normalProposalId, 0, 3);

    // 3. Execute the upgrade proposal (timelock admin changes)
    govHelper.executeProposal(_upgradeProposal);

    // 4. Accept Admin role to the shim
    TimelockMultiAdminShim(timelockMultiAdminShim).acceptAdmin();

    // 5. Add remaining votes and queue and execute the normal proposal
    govHelper.passProposalWithRoll(normalProposalId, 3, 6);
    govHelper.queueProposal(proposalBeforeUpgrade);
    govHelper.executeQueuedProposal(proposalBeforeUpgrade);

    // 6. ✅ Execution works
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }
}
