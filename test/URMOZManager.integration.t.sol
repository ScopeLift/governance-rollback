// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";

// Internal imports
import {URMOZDeploymentIntegrationTest} from "test/URMOZDeployment.integration.t.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";
import {OZGovernorHelper} from "test/helpers/OZGovernorHelper.sol";
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {ITimelockControllerTarget} from "src/interfaces/ITimelockControllerTarget.sol";
import {URMIntegrationTestBase} from "test/helpers/URMIntegrationTestBase.sol";
import {Proposal} from "test/helpers/Proposal.sol";
import {URMCore} from "src/contracts/URMCore.sol";

contract URMOZManagerIntegrationTest is URMIntegrationTestBase, URMOZDeployInput {
  OZGovernorHelper public govHelper;
  URMOZDeploymentIntegrationTest public deployScripts;
  URMOZManager public urm;

  function _getURM() internal view override returns (URMCore) {
    return urm;
  }

  function _getTimelockAddress() internal pure override returns (address) {
    return OZ_TIMELOCK;
  }

  function _getGovernorHelper() internal view override returns (address) {
    return address(govHelper);
  }

  function _setupDeployment() internal override {
    deployScripts = new URMOZDeploymentIntegrationTest();
    (urm, govHelper, proposer) = deployScripts.runDeployScriptsForIntegrationTest();
  }

  function _executeProposal(address _proposer, Proposal memory _proposal) internal override {
    govHelper.submitPassQueueAndExecuteProposalWithRoll(_proposer, _proposal);
  }

  function _getTimelockDelay() internal view override returns (uint256) {
    return ITimelockControllerTarget(payable(urm.TARGET_TIMELOCK())).getMinDelay();
  }

  function _getGuardian() internal pure override returns (address) {
    return GUARDIAN;
  }
}

contract ProposeWithRollback is URMOZManagerIntegrationTest {
// All test functions are now inherited from URMIntegrationTestBase
}
