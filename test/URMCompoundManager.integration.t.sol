// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// External imports
import {Test} from "forge-std/Test.sol";
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal imports
import {URMCompoundDeploymentIntegrationTest} from "test/URMCompoundDeployment.integration.t.sol";
import {CompoundGovernorHelper} from "test/helpers/CompoundGovernorHelper.sol";
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";
import {URMCompoundDeployInput} from "script/URMCompoundDeployInput.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {URMIntegrationTestBase} from "test/helpers/URMIntegrationTestBase.sol";
import {Proposal} from "test/helpers/Proposal.sol";
import {URMCore} from "src/contracts/URMCore.sol";

contract URMCompoundManagerIntegrationTest is URMIntegrationTestBase, URMCompoundDeployInput {
  CompoundGovernorHelper public govHelper;
  URMCompoundDeploymentIntegrationTest public deployScripts;
  address public timelockMultiAdminShim;
  URMCompoundManager public urm;

  function _getURM() internal view override returns (URMCore) {
    return urm;
  }

  function _getTimelockAddress() internal view override returns (address) {
    return urm.admin(); // Compound timelock is the admin
  }

  function _getGovernorHelper() internal view override returns (address) {
    return address(govHelper);
  }

  function _setupDeployment() internal override {
    deployScripts = new URMCompoundDeploymentIntegrationTest();
    (timelockMultiAdminShim, urm, govHelper, proposer) = deployScripts.runDeployScriptsForIntegrationTest();
  }

  function _executeProposal(address _proposer, Proposal memory _proposal) internal override {
    govHelper.submitPassQueueAndExecuteProposalWithRoll(_proposer, _proposal);
  }

  function _getTimelockDelay() internal view override returns (uint256) {
    return ICompoundTimelock(payable(urm.TARGET_TIMELOCK())).delay();
  }

  function _getGuardian() internal pure override returns (address) {
    return GUARDIAN;
  }
}

contract ProposeWithRollback is URMCompoundManagerIntegrationTest {
// All test functions are now inherited from URMIntegrationTestBase
}
