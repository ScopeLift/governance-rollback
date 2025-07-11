// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";

// Internal imports
import {URMOZDeployInput} from "script/URMOZDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";

/// @title DeployURMOZ
/// @notice Script to deploy the URMOZManager contract
/// @dev This script deploys the URMOZManager with the correct configuration for OZ-style governance
contract DeployURMOZ is Script, BaseLogger, URMOZDeployInput {
  function run() public returns (URMOZManager) {
    vm.startBroadcast();

    URMOZManager urm = new URMOZManager(
      OZ_TIMELOCK, // Target is the OZ TimelockController
      OZ_TIMELOCK, // Admin is the OZ TimelockController
      GUARDIAN, // Address that can queue, cancel and execute rollback
      ROLLBACK_QUEUEABLE_DURATION, // Duration after a rollback proposal during which it can be queued for execution
      MIN_ROLLBACK_QUEUEABLE_DURATION // Lower bound enforced on the rollback queueable duration
    );

    vm.stopBroadcast();

    _log("URMOZManager", address(urm));

    return urm;
  }
}
