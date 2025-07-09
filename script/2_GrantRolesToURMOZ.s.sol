// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal imports
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";

/// @title GrantRolesToURMOZ
/// @notice Script to create a governance proposal to grant roles to URMOZManager
/// @dev This script creates a proposal to grant PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE
///      to the URMOZManager on the OZ TimelockController
contract GrantRolesToURMOZ is Script, BaseLogger, URMOZDeployInput {
  function run() public returns (uint256) {
    vm.startBroadcast();
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      generateProposal(URM_OZ_MANAGER);

    uint256 proposalId = IGovernor(OZ_GOVERNOR).propose(targets, values, calldatas, description);
    vm.stopBroadcast();

    _log("Submitted proposal to grant roles to URMOZManager.");
    _log("Proposal ID", proposalId);

    return proposalId;
  }

  function generateProposal(address urmOZManager)
    public
    view
    returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
  {
    targets = new address[](3);
    values = new uint256[](3);
    calldatas = new bytes[](3);

    // Target 1: Grant PROPOSER_ROLE
    targets[0] = OZ_TIMELOCK;
    values[0] = 0;
    calldatas[0] = abi.encodeWithSelector(
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).PROPOSER_ROLE(), urmOZManager
    );

    // Target 2: Grant EXECUTOR_ROLE
    targets[1] = OZ_TIMELOCK;
    values[1] = 0;
    calldatas[1] = abi.encodeWithSelector(
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).EXECUTOR_ROLE(), urmOZManager
    );

    // Target 3: Grant CANCELLER_ROLE
    targets[2] = OZ_TIMELOCK;
    values[2] = 0;
    calldatas[2] = abi.encodeWithSelector(
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).CANCELLER_ROLE(), urmOZManager
    );

    // NOTE: This should be updated to a more descriptive description.
    description = "Grant PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE to URMOZManager for rollback functionality";
  }
}
