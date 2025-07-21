// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {RollbackManagerTimelockControlDeploymentIntegrationTest} from
  "test/RollbackManagerTimelockControlDeployment.integration.t.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {GovernorHelperOZ} from "test/helpers/GovernorHelperOZ.sol";
import {RollbackManagerTimelockControlDeployInput} from "script/RollbackManagerTimelockControlDeployInput.sol";
import {ITimelockTargetControl} from "src/interfaces/ITimelockTargetControl.sol";
import {RollbackManagerIntegrationTestBase} from "test/helpers/RollbackManagerIntegrationTestBase.sol";
import {Proposal} from "test/helpers/Proposal.sol";
import {RollbackManager} from "src/RollbackManager.sol";

contract RollbackManagerTimelockControlIntegrationTest is
  RollbackManagerIntegrationTestBase,
  RollbackManagerTimelockControlDeployInput
{
  GovernorHelperOZ public govHelper;
  RollbackManagerTimelockControlDeploymentIntegrationTest public deployScripts;
  RollbackManagerTimelockControl public rollbackManager;

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _getTimelockAddress() internal pure override returns (address) {
    return OZ_TIMELOCK;
  }

  function _getGovernorHelper() internal view override returns (address) {
    return address(govHelper);
  }

  function _setupDeployment() internal override {
    deployScripts = new RollbackManagerTimelockControlDeploymentIntegrationTest();
    (rollbackManager, govHelper, proposer) = deployScripts.runDeployScriptsForIntegrationTest();
  }

  function _executeProposal(address _proposer, Proposal memory _proposal) internal override {
    govHelper.submitPassQueueAndExecuteProposalWithRoll(_proposer, _proposal);
  }

  function _getTimelockDelay() internal view override returns (uint256) {
    return ITimelockTargetControl(payable(rollbackManager.TARGET_TIMELOCK())).getMinDelay();
  }

  function _getGuardian() internal pure override returns (address) {
    return GUARDIAN;
  }
}

contract ProposeWithRollback is RollbackManagerTimelockControlIntegrationTest {
// All test functions are now inherited from RollbackManagerIntegrationTestBase
}
