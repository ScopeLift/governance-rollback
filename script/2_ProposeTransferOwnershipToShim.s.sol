// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {IGovernor} from "lib/openzeppelin-contracts/contracts/governance/IGovernor.sol";
import {Script} from "forge-std/Script.sol";

// Internal imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {DeployInput} from "script/DeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";

// Simple interface for the updateTimelock method
interface Timelock {
  function updateTimelock(ICompoundTimelock newTimelock) external;
}

/// @title ProposeTransferOwnershipToShim
/// @notice Script to propose transferring timelock admin to TimelockMultiAdminShim
/// @dev This script creates a governance proposal to transfer the timelock admin
///      from the current governor to the TimelockMultiAdminShim contract
contract ProposeTransferOwnershipToShim is Script, BaseLogger, DeployInput {
  function run() public returns (uint256) {
    vm.startBroadcast();
    (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description) =
      generateProposal(TIMELOCK_MULTI_ADMIN_SHIM);

    uint256 proposalId = IGovernor(COMPOUND_GOVERNOR).propose(targets, values, calldatas, description);
    vm.stopBroadcast();

    _log("Submitted proposal to transfer timelock admin to the timelock multi admin shim.");
    _log("Proposal ID", proposalId);

    return proposalId;
  }

  function generateProposal(address timelockMultiAdminShim)
    public
    pure
    returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
  {
    targets = new address[](2);
    values = new uint256[](2);
    calldatas = new bytes[](2);

    // Set pending admin on the Compound Timelock
    targets[0] = COMPOUND_TIMELOCK;
    calldatas[0] = abi.encodeWithSelector(ICompoundTimelock.setPendingAdmin.selector, timelockMultiAdminShim);

    // Set governor timelock to the shim
    targets[1] = address(COMPOUND_GOVERNOR);
    calldatas[1] = abi.encodeWithSelector(Timelock.updateTimelock.selector, timelockMultiAdminShim);

    description =
      "Set TimelockMultiAdminShim as pending owner of CompoundTimelock and set TimelockMultiAdminShim as the timelock of the CompoundGovernor";
  }
}
