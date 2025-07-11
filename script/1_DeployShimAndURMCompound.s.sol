// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {Script} from "forge-std/Script.sol";

// Internal imports
import {URMCompoundDeployInput} from "script/URMCompoundDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";

/// @title DeployShimAndURMCompound
/// @notice Script to deploy the TimelockMultiAdminShim and URMCompoundManager contracts
/// @dev This script deploys both contracts with the correct configuration
contract DeployShimAndURMCompound is Script, BaseLogger, URMCompoundDeployInput {
  function _computeURMAddress() internal view returns (address) {
    address deployer = tx.origin;
    uint256 nextNonce = vm.getNonce(deployer) + 1;
    return vm.computeCreateAddress(deployer, nextNonce);
  }

  function run() public returns (TimelockMultiAdminShim, URMCompoundManager) {
    vm.startBroadcast();

    // Compute the URM address
    address[] memory _executors = new address[](1);
    _executors[0] = _computeURMAddress();

    TimelockMultiAdminShim timelockMultiAdminShim = new TimelockMultiAdminShim(
      COMPOUND_GOVERNOR, // admin is the compound governor
      ICompoundTimelock(COMPOUND_TIMELOCK), // timelock is the compound timelock
      _executors // executors are the compute URM address
    );

    URMCompoundManager urm = new URMCompoundManager(
      address(timelockMultiAdminShim), // Target is the shim address
      COMPOUND_TIMELOCK, // admin is the compound timelock
      GUARDIAN, // Address that can queue, cancel and execute rollback
      ROLLBACK_QUEUEABLE_DURATION, // Duration after a rollback proposal during which it can be queued for execution
      MIN_ROLLBACK_QUEUEABLE_DURATION // Lower bound enforced on the rollback queueable duration
    );

    vm.stopBroadcast();

    _log("TimelockMultiAdminShim", address(timelockMultiAdminShim));
    _log("URMCompoundManager", address(urm));

    if (_executors[0] != address(urm)) {
      _log("URM address", address(urm));
      _log("Computed URM address", _executors[0]);
      revert("URM is not the first executor. Please check computed URM.");
    }

    return (timelockMultiAdminShim, urm);
  }
}
