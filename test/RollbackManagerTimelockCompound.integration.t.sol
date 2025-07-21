// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal imports
import {RollbackManagerTimelockCompoundDeploymentIntegrationTest} from
  "test/RollbackManagerTimelockCompoundDeployment.integration.t.sol";
import {GovernorHelperCompound} from "test/helpers/GovernorHelperCompound.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {RollbackManagerTimelockCompoundDeployInput} from "script/RollbackManagerTimelockCompoundDeployInput.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";
import {RollbackManagerIntegrationTestBase} from "test/helpers/RollbackManagerIntegrationTestBase.sol";
import {Proposal} from "test/helpers/Proposal.sol";
import {RollbackManager} from "src/RollbackManager.sol";

contract RollbackManagerTimelockCompoundIntegrationTest is
  RollbackManagerIntegrationTestBase,
  RollbackManagerTimelockCompoundDeployInput
{
  GovernorHelperCompound public govHelper;
  RollbackManagerTimelockCompoundDeploymentIntegrationTest public deployScripts;
  address public timelockMultiAdminShim;
  RollbackManagerTimelockCompound public rollbackManager;

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _getTimelockAddress() internal view override returns (address) {
    return rollbackManager.admin(); // Compound timelock is the admin
  }

  function _getGovernorHelper() internal view override returns (address) {
    return address(govHelper);
  }

  function _setupDeployment() internal override {
    deployScripts = new RollbackManagerTimelockCompoundDeploymentIntegrationTest();
    (timelockMultiAdminShim, rollbackManager, govHelper, proposer) = deployScripts.runDeployScriptsForIntegrationTest();
  }

  function _executeProposal(address _proposer, Proposal memory _proposal) internal override {
    govHelper.submitPassQueueAndExecuteProposalWithRoll(_proposer, _proposal);
  }

  function _getTimelockDelay() internal view override returns (uint256) {
    return ICompoundTimelock(payable(rollbackManager.TARGET_TIMELOCK())).delay();
  }

  function _getGuardian() internal pure override returns (address) {
    return GUARDIAN;
  }
}

contract ProposeWithRollback is RollbackManagerTimelockCompoundIntegrationTest {
// All test functions are now inherited from RollbackManagerIntegrationTestBase
}
