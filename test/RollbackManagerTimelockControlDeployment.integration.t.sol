// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal imports
import {Test} from "forge-std/Test.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {GovernorHelperOZ} from "test/helpers/GovernorHelperOZ.sol";

// Deploy scripts
import {RollbackManagerTimelockControlDeployInput} from "script/RollbackManagerTimelockControlDeployInput.sol";
import {DeployRollbackManagerTimelockControl} from "script/1_DeployRollbackManagerTimelockControl.s.sol";
import {GrantRolesToRollbackManagerTimelockControl} from "script/2_GrantRolesToRollbackManagerTimelockControl.s.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @title Integration Tests for RollbackManagerTimelockControl
/// @notice Tests the full deployment and governance lifecycle for OZ-style timelocks
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract RollbackManagerTimelockControlDeploymentIntegrationTest is Test, RollbackManagerTimelockControlDeployInput {
  // Test state
  RollbackManagerTimelockControl public rollbackManager;

  // Helper contract for governance operations
  GovernorHelperOZ public governorHelper;

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
    governorHelper = new GovernorHelperOZ();
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
    // Update the RollbackManagerTimelockControlDeployInput addresses for the proposal scripts
    ROLLBACK_MANAGER_TIMELOCK_CONTROL = address(rollbackManager);
  }

  function runDeployScriptsForIntegrationTest()
    external
    returns (RollbackManagerTimelockControl, GovernorHelperOZ, address)
  {
    setUp();
    _step1_deployRollbackManagerTimelockControl();
    _step2_grantRolesToRollbackManagerTimelockControl();
    return (rollbackManager, governorHelper, proposer);
  }

  function onlyDeployRollbackManagerTimelockControl() external returns (RollbackManagerTimelockControl) {
    setUp();
    _step1_deployRollbackManagerTimelockControl();
    return (rollbackManager);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Test the complete deployment flow using the actual deployment script
  function _step1_deployRollbackManagerTimelockControl() internal {
    // Use the actual deployment script
    DeployRollbackManagerTimelockControl _script = new DeployRollbackManagerTimelockControl();
    _script.setLoggingSilenced(true); // Silence logging
    rollbackManager = _script.run();

    // Update RollbackManagerTimelockControlDeployInput addresses for the script
    _updateDeployInputAddresses();
  }

  /// @notice Test the grant roles proposal using the actual script
  function _step2_grantRolesToRollbackManagerTimelockControl() internal {
    // Generate the proposal using the script
    GrantRolesToRollbackManagerTimelockControl grantRolesScript = new GrantRolesToRollbackManagerTimelockControl();
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      grantRolesScript.generateProposal(address(rollbackManager));

    Proposal memory proposal = Proposal(targets, values, calldatas, description);

    // Submit, pass, schedule, and execute the proposal
    governorHelper.submitPassScheduleAndExecuteProposalWithRoll(proposer, proposal);
  }

  /// @notice Test the complete governance workflow: deploy → grant roles
  function test_CompleteOZGovernanceWorkflow() public {
    // Step 1: Deploy contracts
    _step1_deployRollbackManagerTimelockControl();

    assertEq(address(rollbackManager.TARGET_TIMELOCK()), OZ_TIMELOCK);
    assertEq(rollbackManager.admin(), OZ_TIMELOCK);
    assertEq(rollbackManager.guardian(), GUARDIAN);
    assertEq(rollbackManager.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);
    assertEq(rollbackManager.MIN_ROLLBACK_QUEUEABLE_DURATION(), MIN_ROLLBACK_QUEUEABLE_DURATION);

    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(proposerRole, address(rollbackManager)));
    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(executorRole, address(rollbackManager)));
    assertFalse(TimelockController(OZ_TIMELOCK).hasRole(cancellerRole, address(rollbackManager)));

    // Step 2: Grant roles to Rollback Manager
    _step2_grantRolesToRollbackManagerTimelockControl();

    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(proposerRole, address(rollbackManager)));
    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(executorRole, address(rollbackManager)));
    assertTrue(TimelockController(OZ_TIMELOCK).hasRole(cancellerRole, address(rollbackManager)));
  }
}
