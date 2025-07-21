// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";

// Internal imports
import {RollbackManagerTimelockControlDeployInput} from "script/RollbackManagerTimelockControlDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";

/// @title DeployRollbackManagerTimelockControl
/// @notice Script to deploy the RollbackManagerTimelockControl contract
/// @dev This script deploys the RollbackManagerTimelockControl with the correct configuration for OZ-style governance
contract DeployRollbackManagerTimelockControl is Script, BaseLogger, RollbackManagerTimelockControlDeployInput {
  function run() public returns (RollbackManagerTimelockControl) {
    vm.startBroadcast();

    RollbackManagerTimelockControl rollbackManager = new RollbackManagerTimelockControl(
      OZ_TIMELOCK, // Target is the OZ TimelockController
      OZ_TIMELOCK, // Admin is the OZ TimelockController
      GUARDIAN, // Address that can queue, cancel and execute rollback
      ROLLBACK_QUEUEABLE_DURATION, // Duration after a rollback proposal during which it can be queued for execution
      MIN_ROLLBACK_QUEUEABLE_DURATION // Lower bound enforced on the rollback queueable duration
    );

    vm.stopBroadcast();

    _log("RollbackManagerTimelockControl", address(rollbackManager));

    return rollbackManager;
  }
}
