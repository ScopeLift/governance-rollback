// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal imports
import {Test} from "forge-std/Test.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";
import {OZGovernorHelper} from "test/helpers/OZGovernorHelper.sol";

// Deploy scripts
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {DeployURMOZ} from "script/1_DeployURMOZ.s.sol";
import {GrantRolesToURMOZ} from "script/2_GrantRolesToURMOZ.s.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @title Integration Tests for URMOZManager
/// @notice Tests the full deployment and governance lifecycle for OZ-style timelocks
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract URMOZDeploymentIntegrationTest is Test, URMOZDeployInput {
  // Test state
  URMOZManager public urm;

  // Helper contract for governance operations
  OZGovernorHelper public governorHelper;

  address public proposer;

  bytes32 public proposerRole;
  bytes32 public executorRole;
  bytes32 public cancellerRole;

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);

    // Initialize the governor helper
    governorHelper = new OZGovernorHelper();
    governorHelper.setUp();

    // Set the proposer
    proposer = governorHelper.getMajorDelegate(0);

    proposerRole = TimelockController(OZ_TIMELOCK).PROPOSER_ROLE();
    executorRole = TimelockController(OZ_TIMELOCK).EXECUTOR_ROLE();
    cancellerRole = TimelockController(OZ_TIMELOCK).CANCELLER_ROLE();
  }

  /*///////////////////////////////////////////////////////////////
                      Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _updateDeployInputAddresses() internal {
    // Update the URMOZDeployInput addresses for the proposal scripts
    URM_OZ_MANAGER = address(urm);
  }

  function runDeployScriptsForIntegrationTest() external returns (URMOZManager) {
    setUp();
    _step1_deployURMOZ();
    _step2_grantRolesToURMOZ();
    return (urm);
  }

  function onlyDeployURMOZ() external returns (URMOZManager) {
    setUp();
    _step1_deployURMOZ();
    return (urm);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Test the complete deployment flow using the actual deployment script
  function _step1_deployURMOZ() internal {
    // Use the actual deployment script
    DeployURMOZ _script = new DeployURMOZ();
    _script.setLoggingSilenced(true); // Silence logging
    urm = _script.run();

    // Update URMOZDeployInput addresses for the script
    _updateDeployInputAddresses();
  }

  /// @notice Test the grant roles proposal using the actual script
  function _step2_grantRolesToURMOZ() internal {
    // Generate the proposal using the script
    GrantRolesToURMOZ grantRolesScript = new GrantRolesToURMOZ();
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      grantRolesScript.generateProposal(address(urm));

    Proposal memory proposal = Proposal(targets, values, calldatas, description);

    // Submit, pass, schedule, and execute the proposal
    governorHelper.submitPassScheduleAndExecuteProposalWithRoll(proposer, proposal);
  }

  /// @notice Test the complete governance workflow: deploy → grant roles
  function test_CompleteOZGovernanceWorkflow() public {
    // Step 1: Deploy contracts
    _step1_deployURMOZ();

    assertEq(address(urm.TARGET_TIMELOCK()), OZ_TIMELOCK);
    assertEq(urm.admin(), OZ_GOVERNOR);
    assertEq(urm.guardian(), GUARDIAN);
    assertEq(urm.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);
    assertEq(urm.MIN_ROLLBACK_QUEUEABLE_DURATION(), MIN_ROLLBACK_QUEUEABLE_DURATION);

    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(proposerRole, address(urm)));
    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(executorRole, address(urm)));
    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(cancellerRole, address(urm)));

    // Step 2: Grant roles to URM
    _step2_grantRolesToURMOZ();

    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(proposerRole, address(urm)));
    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(executorRole, address(urm)));
    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(cancellerRole, address(urm)));
  }
}
