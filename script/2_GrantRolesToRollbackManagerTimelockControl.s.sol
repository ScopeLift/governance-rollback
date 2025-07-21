// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal imports
import {RollbackManagerTimelockControlDeployInput} from "script/RollbackManagerTimelockControlDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";

/// @title GrantRolesToRollbackManagerTimelockControl
/// @notice Script to create a governance proposal to grant roles to RollbackManagerTimelockControl
/// @dev This script creates a proposal to grant PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE
///      to the RollbackManagerTimelockControl on the OZ TimelockController
contract GrantRolesToRollbackManagerTimelockControl is Script, BaseLogger, RollbackManagerTimelockControlDeployInput {
  function run() public returns (uint256) {
    vm.startBroadcast();
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      generateProposal(ROLLBACK_MANAGER_TIMELOCK_CONTROL);

    uint256 proposalId = IGovernor(OZ_GOVERNOR).propose(targets, values, calldatas, description);
    vm.stopBroadcast();

    _log("Submitted proposal to grant roles to RollbackManagerTimelockControl.");
    _log("Proposal ID", proposalId);

    return proposalId;
  }

  function generateProposal(address rollbackManagerOZManager)
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
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).PROPOSER_ROLE(), rollbackManagerOZManager
    );

    // Target 2: Grant EXECUTOR_ROLE
    targets[1] = OZ_TIMELOCK;
    values[1] = 0;
    calldatas[1] = abi.encodeWithSelector(
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).EXECUTOR_ROLE(), rollbackManagerOZManager
    );

    // Target 3: Grant CANCELLER_ROLE
    targets[2] = OZ_TIMELOCK;
    values[2] = 0;
    calldatas[2] = abi.encodeWithSelector(
      AccessControl.grantRole.selector, TimelockController(OZ_TIMELOCK).CANCELLER_ROLE(), rollbackManagerOZManager
    );

    // NOTE: This should be updated to a more descriptive description.
    description =
      "Grant PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE to RollbackManagerTimelockControl for rollback functionality";
  }
}
