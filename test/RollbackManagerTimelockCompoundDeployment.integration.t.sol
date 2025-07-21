// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal imports
import {Test} from "forge-std/Test.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {GovernorHelperCompound, ICompoundGovernor} from "test/helpers/GovernorHelperCompound.sol";

// Deploy scripts
import {RollbackManagerTimelockCompoundDeployInput} from "script/RollbackManagerTimelockCompoundDeployInput.sol";
import {DeployShimAndRollbackManagerTimelockCompound} from "script/1_DeployShimAndRollbackManagerTimelockCompound.s.sol";
import {ProposeTransferOwnershipToShim} from "script/2_ProposeTransferOwnershipToShim.s.sol";
import {AcceptAdmin} from "script/3_AcceptAdmin.s.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @title Integration Tests for TimelockMultiAdminShim and RollbackManagerTimelockCompound
/// @notice Tests the full deployment and governance lifecycle
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract RollbackManagerTimelockCompoundDeploymentIntegrationTest is Test, RollbackManagerTimelockCompoundDeployInput {
  // Test state
  TimelockMultiAdminShim public timelockMultiAdminShim;
  RollbackManagerTimelockCompound public rollbackManager;

  // Helper contract for governance operations
  GovernorHelperCompound public governorHelper;

  address public proposer;

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);

    // Initialize the governor helper
    governorHelper = new GovernorHelperCompound();
    governorHelper.setUp();

    // Set the proposer
    proposer = governorHelper.getMajorDelegate(0);
    governorHelper.setWhitelistedProposer(proposer);
  }

  /*///////////////////////////////////////////////////////////////
                      Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _updateDeployInputAddresses() internal {
    // Update the RollbackManagerTimelockCompoundDeployInput addresses for the proposal scripts
    // Since these are not constants in DeployInput, we can update them directly
    TIMELOCK_MULTI_ADMIN_SHIM = address(timelockMultiAdminShim);
    ROLLBACK_MANAGER_TIMELOCK_COMPOUND = address(rollbackManager);
  }

  function runDeployScriptsForIntegrationTest()
    external
    returns (address, RollbackManagerTimelockCompound, GovernorHelperCompound, address)
  {
    setUp();
    _step1_deployShimAndRollbackManager();
    _step2__proposeTransferTimelockAdminToShim(TIMELOCK_MULTI_ADMIN_SHIM);
    _step3_acceptAdminFromShim(TIMELOCK_MULTI_ADMIN_SHIM);
    return (address(timelockMultiAdminShim), rollbackManager, governorHelper, proposer);
  }

  function onlyDeployShimAndRollbackManager()
    external
    returns (address, RollbackManagerTimelockCompound, GovernorHelperCompound, address)
  {
    setUp();
    _step1_deployShimAndRollbackManager();
    return (address(timelockMultiAdminShim), rollbackManager, governorHelper, proposer);
  }

  function onlyProposeTransferTimelockAdminToShim(address _timelockMultiAdminShim)
    external
    returns (address, RollbackManagerTimelockCompound, GovernorHelperCompound, address)
  {
    _step2__proposeTransferTimelockAdminToShim(_timelockMultiAdminShim);
    _step3_acceptAdminFromShim(_timelockMultiAdminShim);
    return (address(timelockMultiAdminShim), rollbackManager, governorHelper, proposer);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Test the complete deployment flow using the actual deployment script
  function _step1_deployShimAndRollbackManager() internal {
    // Use the actual deployment script
    DeployShimAndRollbackManagerTimelockCompound _script = new DeployShimAndRollbackManagerTimelockCompound();
    _script.setLoggingSilenced(true); // Silence logging
    (timelockMultiAdminShim, rollbackManager) = _script.run();

    // Update RollbackManagerTimelockCompoundDeployInput addresses for the script
    _updateDeployInputAddresses();
  }

  /// @notice Test the transfer timelock admin proposal using the actual script
  function _step2__proposeTransferTimelockAdminToShim(address _timelockMultiAdminShim) internal {
    ProposeTransferOwnershipToShim _script = new ProposeTransferOwnershipToShim();
    _script.setLoggingSilenced(true); // Silence logging

    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      _script.generateProposal(_timelockMultiAdminShim);

    Proposal memory proposal = Proposal(targets, values, calldatas, description);

    governorHelper.submitPassQueueAndExecuteProposalWithRoll(proposer, proposal);
  }

  function _step3_acceptAdminFromShim(address _timelockMultiAdminShim) internal {
    AcceptAdmin _script = new AcceptAdmin();
    _script.setLoggingSilenced(true); // Silence logging
    _script.invokeAcceptAdmin(_timelockMultiAdminShim);
  }

  /// @notice Test the complete governance workflow: deploy → transfer admin → add executor
  function test_CompleteGovernanceWorkflow() public {
    // Step 1: Deploy contracts
    _step1_deployShimAndRollbackManager();

    // Verify Step 1
    assertEq(address(timelockMultiAdminShim.TIMELOCK()), COMPOUND_TIMELOCK);
    assertEq(timelockMultiAdminShim.admin(), COMPOUND_GOVERNOR);
    assertTrue(timelockMultiAdminShim.isExecutor(address(rollbackManager)));
    assertEq(address(rollbackManager.TARGET_TIMELOCK()), address(timelockMultiAdminShim));
    assertEq(rollbackManager.admin(), COMPOUND_TIMELOCK);
    assertEq(rollbackManager.guardian(), GUARDIAN);
    assertEq(rollbackManager.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);

    _step2__proposeTransferTimelockAdminToShim(TIMELOCK_MULTI_ADMIN_SHIM);

    // Verify Step 2
    assertEq(ICompoundTimelock(COMPOUND_TIMELOCK).pendingAdmin(), TIMELOCK_MULTI_ADMIN_SHIM);
    assertEq(ICompoundTimelock(COMPOUND_TIMELOCK).admin(), COMPOUND_GOVERNOR);
    assertEq(address(ICompoundGovernor(COMPOUND_GOVERNOR).timelock()), TIMELOCK_MULTI_ADMIN_SHIM);

    _step3_acceptAdminFromShim(TIMELOCK_MULTI_ADMIN_SHIM);

    // Verify Step 3
    assertEq(ICompoundTimelock(COMPOUND_TIMELOCK).pendingAdmin(), address(0));
    assertEq(ICompoundTimelock(COMPOUND_TIMELOCK).admin(), TIMELOCK_MULTI_ADMIN_SHIM);

    // Verify final state
    assertEq(address(ICompoundGovernor(COMPOUND_GOVERNOR).timelock()), TIMELOCK_MULTI_ADMIN_SHIM);
    assertEq(ICompoundTimelock(COMPOUND_TIMELOCK).admin(), address(timelockMultiAdminShim));
    assertTrue(timelockMultiAdminShim.isExecutor(address(rollbackManager)));
  }
}
