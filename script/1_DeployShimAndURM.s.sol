// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import {Script} from "forge-std/Script.sol";

// Internal imports
import {DeployInput} from "script/DeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";
import {ITimelockTarget} from "src/interfaces/ITimelockTarget.sol";
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";

/// @title DeployShimAndURM
/// @notice Script to deploy the TimelockMultiAdminShim and UpgradeRegressionManager contracts
/// @dev This script deploys both contracts with the correct configuration
contract DeployShimAndURM is Script, BaseLogger, DeployInput {
  function _computeURMAddress() internal view returns (address) {
    address deployer = tx.origin;
    uint256 nextNonce = vm.getNonce(deployer) + 1;
    return vm.computeCreateAddress(deployer, nextNonce);
  }

  function run() public returns (TimelockMultiAdminShim, UpgradeRegressionManager) {
    vm.startBroadcast();

    // Compute the URM address
    address[] memory _executors = new address[](1);
    _executors[0] = _computeURMAddress();

    TimelockMultiAdminShim timelockMultiAdminShim = new TimelockMultiAdminShim(
      COMPOUND_GOVERNOR, // admin is the compound governor
      ICompoundTimelock(COMPOUND_TIMELOCK), // timelock is the compound timelock
      _executors // executors are the compute URM address
    );

    UpgradeRegressionManager upgradeRegressionManager = new UpgradeRegressionManager(
      ITimelockTarget(address(timelockMultiAdminShim)), // Target is the shim address
      COMPOUND_TIMELOCK, // admin is the compound timelock
      GUARDIAN, // Address that can queue, cancel and execute rollback
      ROLLBACK_QUEUE_WINDOW // Time window within which a rollback can be queued after it is proposed by admin
    );

    vm.stopBroadcast();

    _log("TimelockMultiAdminShim", address(timelockMultiAdminShim));
    _log("UpgradeRegressionManager", address(upgradeRegressionManager));

    if (_executors[0] != address(upgradeRegressionManager)) {
      _log("URM address", address(upgradeRegressionManager));
      _log("Computed URM address", _executors[0]);
      revert("URM is not the first executor. Please check computed URM.");
    }

    return (timelockMultiAdminShim, upgradeRegressionManager);
  }
}
