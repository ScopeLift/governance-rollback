// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {URMOZDeploymentIntegrationTest} from "test/URMOZDeployment.integration.t.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {FakeProtocolRollbackTestHelper} from "test/fakes/FakeProtocolRollbackTestHelper.sol";
import {OZGovernorHelper} from "test/helpers/OZGovernorHelper.sol";
import {ProposalState} from "src/types/GovernanceTypes.sol";
import {URMCore} from "src/contracts/URMCore.sol";
import {Proposal} from "test/helpers/Proposal.sol";
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {ITimelockControllerTarget} from "src/interfaces/ITimelockControllerTarget.sol";

contract URMOZManagerIntegrationTest is Test, URMOZDeployInput {
  FakeProtocolContract public fakeProtocolContract;
  OZGovernorHelper public govHelper;
  FakeProtocolRollbackTestHelper public rollbackHelper;
  URMOZDeploymentIntegrationTest public deployScripts;
  URMOZManager public urm;

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

    deployScripts = new URMOZDeploymentIntegrationTest();
    (urm, govHelper, proposer) = deployScripts.runDeployScriptsForIntegrationTest();

    // Deploy FakeProtocolContract with OZ Timelock as owner
    fakeProtocolContract = new FakeProtocolContract(OZ_TIMELOCK);

    // Setup rollback helper
    rollbackHelper = new FakeProtocolRollbackTestHelper(fakeProtocolContract, urm);
  }
}

contract ProposeWithRollback is URMOZManagerIntegrationTest {
  function testFork_ProposalExecutionAddsRollbackTransactionsToUrmWhichExpireAfterExecutionWindow() public {
    // 1. Create proposal to change fee and feeGuardian
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 4. Verify rollback is proposed to URM and is in pending state
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    assertEq(uint8(urm.state(_rollbackId)), uint8(ProposalState.Pending));

    // 5. Verify rollback is in expired state
    vm.warp(block.timestamp + urm.rollbackQueueableDuration() + 1);
    assertEq(uint8(urm.state(_rollbackId)), uint8(ProposalState.Expired));
  }

  function testFork_RollbackExecutionFlow() public {
    // 1. Create proposal to change fee to 100
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
  }

  function testFork_RollbackExecutionWithNativeTokenProposal() public {
    // Ensure FakeProtocolContract starts with 0 balance
    vm.deal(address(fakeProtocolContract), 0);
    assertEq(address(fakeProtocolContract).balance, 0 ether);

    // 1. Create proposal to change fee to 100 with 1 ether
    Proposal memory proposal = rollbackHelper.generateProposalWithRollbackAndAmount(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      1 ether,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    vm.deal(address(proposer), 1 ether);
    // Give ETH to the timelock so it can execute the transaction
    vm.deal(OZ_TIMELOCK, 1 ether);
    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // Verify FakeProtocolContract received the ETH
    assertEq(address(fakeProtocolContract).balance, 1 ether);

    // Execute rollback
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 3. Queue rollback
    vm.prank(GUARDIAN);
    urm.queue(targets, values, calldatas, description);

    // 4. Wait for timelock delay and execute rollback
    uint256 timelockDelay = ITimelockControllerTarget(payable(urm.TARGET_TIMELOCK())).getMinDelay();
    vm.warp(block.timestamp + timelockDelay + 1);

    // 5. Execute rollback
    vm.prank(GUARDIAN);
    urm.execute(targets, values, calldatas, description);

    // Check balance of FakeProtocolContract - should still have 1 ether after rollback
    // (rollback only changes fee/feeGuardian, doesn't send ETH)
    assertEq(address(fakeProtocolContract).balance, 1 ether);
  }

  function testFork_RollbackCancellation() public {
    // 1. Create proposal to change fee to 100
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 4. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 5. Queue rollback
    vm.prank(GUARDIAN);
    urm.queue(targets, values, calldatas, description);

    // 6. Cancel rollback
    vm.prank(GUARDIAN);
    urm.cancel(targets, values, calldatas, description);

    // 7. Verify rollback was successfully cancelled
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
    assertEq(uint8(urm.state(_rollbackId)), uint8(ProposalState.Canceled));
  }

  function testFork_RevertIf_UnauthorizedCallToCancelRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to cancel rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    urm.cancel(targets, values, calldatas, description);
  }

  function testFork_RevertIf_UnauthorizedCallToQueueRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to queue rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    urm.queue(targets, values, calldatas, description);
  }

  function testFork_RevertIf_RollbackQueueableDurationHasExpired() public {
    // 1. Create proposal to change fee to 100
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // 3. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 4. Wait for rollback queueable duration to expire
    vm.warp(block.timestamp + urm.rollbackQueueableDuration() + 1);

    // 5. Attempt to queue rollback
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__Expired.selector, _rollbackId));
    vm.prank(GUARDIAN);
    urm.queue(targets, values, calldatas, description);
  }

  function testFork_RevertIf_UnauthorizedCallToExecuteRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to execute rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(URMCore.URM__Unauthorized.selector);
    urm.execute(targets, values, calldatas, description);
  }

  function testFork_RevertIf_RollbackExecutionCalledTooEarly() public {
    // 1. Create proposal to change fee to 100
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    govHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);

    // 3. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 4. Queue rollback
    vm.prank(GUARDIAN);
    urm.queue(targets, values, calldatas, description);

    // 5. Attempt to execute rollback
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    vm.expectRevert(abi.encodeWithSelector(URMCore.URM__ExecutionTooEarly.selector, _rollbackId));
    vm.prank(GUARDIAN);
    urm.execute(targets, values, calldatas, description);
  }
}
