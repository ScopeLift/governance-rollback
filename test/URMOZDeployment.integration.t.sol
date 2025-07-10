// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// Internal imports
import {Test} from "forge-std/Test.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";

// Deploy scripts
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {DeployURMOZ} from "script/1_DeployURMOZ.s.sol";
import {GrantRolesToURMOZ} from "script/2_GrantRolesToURMOZ.s.sol";

/// @title Integration Tests for URMOZManager
/// @notice Tests the full deployment and governance lifecycle for OZ-style timelocks
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract URMOZDeploymentIntegrationTest is Test, URMOZDeployInput {
  // Test state
  URMOZManager public urm;

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);
  }

  /*///////////////////////////////////////////////////////////////
                      Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _updateDeployInputAddresses() internal {
    // Update the URMOZDeployInput addresses for the proposal scripts
    URM_OZ_MANAGER = address(urm);
  }

  function runDeployScriptsForIntegrationTest() external returns (address, URMOZManager) {
    setUp();
    _step1_deployURMOZ();
    _step2_grantRolesToURMOZ();
    return (address(urm), urm);
  }

  function onlyDeployURMOZ() external returns (address, URMOZManager) {
    setUp();
    _step1_deployURMOZ();
    return (address(urm), urm);
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
    // TODO: Implement step 2 verification
    // This function is intentionally empty for now as requested
  }

  /// @notice Test the complete governance workflow: deploy → grant roles
  function test_CompleteGovernanceWorkflow() public {
    // Step 1: Deploy contracts
    _step1_deployURMOZ();

    // Verify Step 1
    assertEq(address(urm.TARGET_TIMELOCK()), OZ_TIMELOCK);
    assertEq(urm.admin(), OZ_GOVERNOR);
    assertEq(urm.guardian(), GUARDIAN);
    assertEq(urm.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);
    assertEq(urm.MIN_ROLLBACK_QUEUEABLE_DURATION(), MIN_ROLLBACK_QUEUEABLE_DURATION);

    _step2_grantRolesToURMOZ();

    // Verify Step 2
    // TODO: Add verification for step 2 once implemented
  }

  /// @notice Test only the deployment step
  function test_Step1_DeployURMOZ() public {
    // Step 1: Deploy contracts
    _step1_deployURMOZ();

    // Verify Step 1
    assertEq(address(urm.TARGET_TIMELOCK()), OZ_TIMELOCK);
    assertEq(urm.admin(), OZ_GOVERNOR);
    assertEq(urm.guardian(), GUARDIAN);
    assertEq(urm.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);
    assertEq(urm.MIN_ROLLBACK_QUEUEABLE_DURATION(), MIN_ROLLBACK_QUEUEABLE_DURATION);
  }
}
