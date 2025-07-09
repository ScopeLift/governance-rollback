// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IComp} from "@scopelift/compound-governance-upgrade/contracts/interfaces/IComp.sol";

// Internal imports
import {Test} from "forge-std/Test.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {URMCompoundTimelock} from "src/contracts/urm/URMCompoundTimelock.sol";
import {CompoundGovernorHelper, ICompoundGovernor} from "test/helpers/CompoundGovernorHelper.sol";

// Deploy scripts
import {DeployInput} from "script/DeployInput.sol";
import {DeployShimAndURMCompound} from "script/1_DeployShimAndURMCompound.s.sol";
import {ProposeTransferOwnershipToShim} from "script/2_ProposeTransferOwnershipToShim.s.sol";
import {AcceptAdmin} from "script/3_AcceptAdmin.s.sol";
import {Proposal} from "test/helpers/Proposal.sol";

/// @title Integration Tests for TimelockMultiAdminShim and URMCompoundTimelock
/// @notice Tests the full deployment and governance lifecycle
/// @dev This test suite requires MAINNET_RPC_URL environment variable to be set
contract DeployScriptsIntegrationTest is Test, DeployInput {
  // Test state
  TimelockMultiAdminShim public timelockMultiAdminShim;
  URMCompoundTimelock public urm;

  // Helper contract for governance operations
  CompoundGovernorHelper public governorHelper;

  address public proposer;

  function setUp() public {
    string memory rpcUrl = vm.envString("MAINNET_RPC_URL");
    uint256 forkBlock = 22_781_735;
    // Create fork of mainnet
    vm.createSelectFork(rpcUrl, forkBlock);

    // Initialize the governor helper
    governorHelper = new CompoundGovernorHelper();
    governorHelper.setUp();

    // Set the proposer
    proposer = governorHelper.getMajorDelegate(0);
    governorHelper.setWhitelistedProposer(proposer);
  }

  /*///////////////////////////////////////////////////////////////
                      Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _updateDeployInputAddresses() internal {
    // Update the DeployInput addresses for the proposal scripts
    // Since these are not constants in DeployInput, we can update them directly
    TIMELOCK_MULTI_ADMIN_SHIM = address(timelockMultiAdminShim);
    URM_COMPOUND_TIMELOCK = address(urm);
  }

  function runDeployScriptsForIntegrationTest()
    external
    returns (address, URMCompoundTimelock, CompoundGovernorHelper, address)
  {
    setUp();
    _step1_deployShimAndURM();
    _step2__proposeTransferTimelockAdminToShim(TIMELOCK_MULTI_ADMIN_SHIM);
    _step3_acceptAdminFromShim(TIMELOCK_MULTI_ADMIN_SHIM);
    return (address(timelockMultiAdminShim), urm, governorHelper, proposer);
  }

  function onlyDeployShimAndURM() external returns (address, URMCompoundTimelock, CompoundGovernorHelper, address) {
    setUp();
    _step1_deployShimAndURM();
    return (address(timelockMultiAdminShim), urm, governorHelper, proposer);
  }

  function onlyProposeTransferTimelockAdminToShim(address _timelockMultiAdminShim)
    external
    returns (address, URMCompoundTimelock, CompoundGovernorHelper, address)
  {
    _step2__proposeTransferTimelockAdminToShim(_timelockMultiAdminShim);
    _step3_acceptAdminFromShim(_timelockMultiAdminShim);
    return (address(timelockMultiAdminShim), urm, governorHelper, proposer);
  }

  /*///////////////////////////////////////////////////////////////
                      Test Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Test the complete deployment flow using the actual deployment script
  function _step1_deployShimAndURM() internal {
    // Use the actual deployment script
    DeployShimAndURMCompound _script = new DeployShimAndURMCompound();
    _script.setLoggingSilenced(true); // Silence logging
    (timelockMultiAdminShim, urm) = _script.run();

    // Update DeployInput addresses for the script
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
    _step1_deployShimAndURM();

    // Verify Step 1
    assertEq(address(timelockMultiAdminShim.TIMELOCK()), COMPOUND_TIMELOCK);
    assertEq(timelockMultiAdminShim.admin(), COMPOUND_GOVERNOR);
    assertTrue(timelockMultiAdminShim.isExecutor(address(urm)));
    assertEq(address(urm.TARGET_TIMELOCK()), address(timelockMultiAdminShim));
    assertEq(urm.admin(), COMPOUND_TIMELOCK);
    assertEq(urm.guardian(), GUARDIAN);
    assertEq(urm.rollbackQueueableDuration(), ROLLBACK_QUEUEABLE_DURATION);

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
    assertTrue(timelockMultiAdminShim.isExecutor(address(urm)));
  }
}
