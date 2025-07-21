// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {Script} from "forge-std/Script.sol";

// Internal imports
import {RollbackManagerTimelockCompoundDeployInput} from "script/RollbackManagerTimelockCompoundDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";

/// @title DeployShimAndRollbackManagerTimelockCompound
/// @notice Script to deploy the TimelockMultiAdminShim and RollbackManagerTimelockCompound contracts
/// @dev This script deploys both contracts with the correct configuration
contract DeployShimAndRollbackManagerTimelockCompound is
  Script,
  BaseLogger,
  RollbackManagerTimelockCompoundDeployInput
{
  function _computeRollbackManagerAddress() internal view returns (address) {
    address deployer = tx.origin;
    uint256 nextNonce = vm.getNonce(deployer) + 1;
    return vm.computeCreateAddress(deployer, nextNonce);
  }

  function run() public returns (TimelockMultiAdminShim, RollbackManagerTimelockCompound) {
    vm.startBroadcast();

    // Compute the Rollback Manager address
    address[] memory _executors = new address[](1);
    _executors[0] = _computeRollbackManagerAddress();

    TimelockMultiAdminShim timelockMultiAdminShim = new TimelockMultiAdminShim(
      COMPOUND_GOVERNOR, // admin is the compound governor
      ICompoundTimelock(COMPOUND_TIMELOCK), // timelock is the compound timelock
      _executors // executors are the compute Rollback Manager address
    );

    RollbackManagerTimelockCompound rollbackManager = new RollbackManagerTimelockCompound(
      address(timelockMultiAdminShim), // Target is the shim address
      COMPOUND_TIMELOCK, // admin is the compound timelock
      GUARDIAN, // Address that can queue, cancel and execute rollback
      ROLLBACK_QUEUEABLE_DURATION, // Duration after a rollback proposal during which it can be queued for execution
      MIN_ROLLBACK_QUEUEABLE_DURATION // Lower bound enforced on the rollback queueable duration
    );

    vm.stopBroadcast();

    _log("TimelockMultiAdminShim", address(timelockMultiAdminShim));
    _log("RollbackManagerTimelockCompound", address(rollbackManager));

    if (_executors[0] != address(rollbackManager)) {
      _log("Rollback Manager address", address(rollbackManager));
      _log("Computed Rollback Manager address", _executors[0]);
      revert("Rollback Manager is not the first executor. Please check computed Rollback Manager.");
    }

    return (timelockMultiAdminShim, rollbackManager);
  }
}
