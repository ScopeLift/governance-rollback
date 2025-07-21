// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {RollbackManager} from "src/RollbackManager.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {FakeProtocolRollbackTestHelper} from "test/fakes/FakeProtocolRollbackTestHelper.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @title RollbackManagerIntegrationTestBase
/// @notice Contains common setup and test functions for both RollbackManagerTimelockControl and
/// RollbackManagerTimelockCompound
/// @dev This abstract class provides common functionality for integration tests of both Rollback Manager variants
abstract contract RollbackManagerIntegrationTestBase is Test {
  FakeProtocolContract public fakeProtocolContract;
  FakeProtocolRollbackTestHelper public rollbackHelper;
  address public proposer;

  // Test addresses
  address public feeGuardianWhenProposalIsExecuted = makeAddr("feeGuardianWhenProposalIsExecuted");
  uint256 public feeWhenProposalIsExecuted = 50;

  address public feeGuardianWhenRollbackIsExecuted = makeAddr("feeGuardianWhenRollbackIsExecuted");
  uint256 public feeWhenRollbackIsExecuted = 1;

  /// @notice Abstract method to get the RollbackManager contract instance
  /// @return The RollbackManager contract instance
  function _getRollbackManager() internal view virtual returns (RollbackManager);
  function _getTimelockAddress() internal view virtual returns (address);
  function _getGovernorHelper() internal view virtual returns (address);
  function _setupDeployment() internal virtual;
  function _executeProposal(address _proposer, Proposal memory _proposal) internal virtual;
  function _getTimelockDelay() internal view virtual returns (uint256);
  function _getGuardian() internal view virtual returns (address);

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);

    // Setup deployment (implemented by child contracts)
    _setupDeployment();

    // Deploy FakeProtocolContract with the appropriate timelock as owner
    fakeProtocolContract = new FakeProtocolContract(_getTimelockAddress());

    // Setup rollback helper
    rollbackHelper = new FakeProtocolRollbackTestHelper(fakeProtocolContract, _getRollbackManager()); // This line was
      // removed as per the new_code
  }

  /// @notice Helper function to assert that a rollback state equals an expected state.
  /// @param _rollbackId The rollback ID to check.
  /// @param _expectedState The expected ProposalState.
  function _assertEqState(uint256 _rollbackId, IGovernor.ProposalState _expectedState) internal view {
    assertEq(uint8(_getRollbackManager().state(_rollbackId)), uint8(_expectedState));
  }

  /*///////////////////////////////////////////////////////////////
                      Common Test Functions
  //////////////////////////////////////////////////////////////*/

  function testFork_ProposalExecutionAddsRollbackTransactionsToRollbackManagerWhichExpireAfterExecutionWindow() public {
    // 1. Create proposal to change fee and feeGuardian
    Proposal memory proposal = rollbackHelper.generateProposalWithRollback(
      feeWhenProposalIsExecuted,
      feeGuardianWhenProposalIsExecuted,
      feeWhenRollbackIsExecuted,
      feeGuardianWhenRollbackIsExecuted
    );

    // 2. Execute proposal using governance helper
    _executeProposal(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 4. Verify rollback is proposed to Rollback Manager and is in pending state
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    _assertEqState(_rollbackId, IGovernor.ProposalState.Pending);

    // 5. Verify rollback is in expired state
    vm.warp(block.timestamp + _getRollbackManager().rollbackQueueableDuration() + 1);
    _assertEqState(_rollbackId, IGovernor.ProposalState.Expired);
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
    _executeProposal(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 4. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 5. Queue rollback
    vm.prank(_getGuardian());
    uint256 _rollbackId = _getRollbackManager().queue(targets, values, calldatas, description);

    // 6. Wait for timelock delay and execute rollback
    uint256 timelockDelay = _getTimelockDelay();
    vm.warp(block.timestamp + timelockDelay + 1);

    // 7. Execute rollback
    vm.prank(_getGuardian());
    _getRollbackManager().execute(targets, values, calldatas, description);

    // 8. Verify rollback was successfully executed
    assertEq(fakeProtocolContract.fee(), feeWhenRollbackIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenRollbackIsExecuted);
    _assertEqState(_rollbackId, IGovernor.ProposalState.Executed);
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
    vm.deal(_getTimelockAddress(), 1 ether);
    // 2. Execute proposal using governance helper
    _executeProposal(proposer, proposal);

    // Verify FakeProtocolContract received the ETH
    assertEq(address(fakeProtocolContract).balance, 1 ether);

    // Execute rollback
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 3. Queue rollback
    vm.prank(_getGuardian());
    _getRollbackManager().queue(targets, values, calldatas, description);

    // 4. Wait for timelock delay and execute rollback
    uint256 timelockDelay = _getTimelockDelay();
    vm.warp(block.timestamp + timelockDelay + 1);

    // 5. Execute rollback
    vm.prank(_getGuardian());
    _getRollbackManager().execute(targets, values, calldatas, description);

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
    _executeProposal(proposer, proposal);

    // 3. Verify updated state
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);

    // 4. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 5. Queue rollback
    vm.prank(_getGuardian());
    _getRollbackManager().queue(targets, values, calldatas, description);

    // 6. Cancel rollback
    vm.prank(_getGuardian());
    _getRollbackManager().cancel(targets, values, calldatas, description);

    // 7. Verify rollback was successfully cancelled
    assertEq(fakeProtocolContract.fee(), feeWhenProposalIsExecuted);
    assertEq(fakeProtocolContract.feeGuardian(), feeGuardianWhenProposalIsExecuted);
    _assertEqState(_rollbackId, IGovernor.ProposalState.Canceled);
  }

  function testFork_RevertIf_UnauthorizedCallToCancelRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to cancel rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    _getRollbackManager().cancel(targets, values, calldatas, description);
  }

  function testFork_RevertIf_UnauthorizedCallToQueueRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to queue rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    _getRollbackManager().queue(targets, values, calldatas, description);
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
    _executeProposal(proposer, proposal);

    // 3. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 4. Wait for rollback queueable duration to expire
    vm.warp(block.timestamp + _getRollbackManager().rollbackQueueableDuration() + 1);

    // 5. Attempt to queue rollback
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__Expired.selector, _rollbackId));
    vm.prank(_getGuardian());
    _getRollbackManager().queue(targets, values, calldatas, description);
  }

  function testFork_RevertIf_UnauthorizedCallToExecuteRollback() public {
    // 1. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    // 2. Attempt to execute rollback
    vm.prank(makeAddr("nonGuardian"));
    vm.expectRevert(RollbackManager.RollbackManager__Unauthorized.selector);
    _getRollbackManager().execute(targets, values, calldatas, description);
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
    _executeProposal(proposer, proposal);

    // 3. Generate rollback data
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      rollbackHelper.generateRollbackData(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);

    // 4. Queue rollback
    vm.prank(_getGuardian());
    _getRollbackManager().queue(targets, values, calldatas, description);

    // 5. Attempt to execute rollback
    uint256 _rollbackId = rollbackHelper.getRollbackId(feeWhenRollbackIsExecuted, feeGuardianWhenRollbackIsExecuted);
    vm.expectRevert(abi.encodeWithSelector(RollbackManager.RollbackManager__ExecutionTooEarly.selector, _rollbackId));
    vm.prank(_getGuardian());
    _getRollbackManager().execute(targets, values, calldatas, description);
  }
}
