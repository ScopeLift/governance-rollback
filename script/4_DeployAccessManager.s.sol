// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

// Internal imports
import {BaseLogger} from "script/BaseLogger.sol";

/// @title DeployAccessManager
/// @notice Deploys a shared AccessManager for CouncilExecutor(s).
/// @dev This AccessManager controls which (target, selector) pairs each council governor can schedule.
contract DeployAccessManager is Script, BaseLogger {
  /// @notice Deploys AccessManager with the given admin
  /// @param _admin Address that will be the AccessManager admin (can configure roles and targets)
  /// @return manager The deployed AccessManager
  function run(address _admin) public returns (AccessManager manager) {
    vm.startBroadcast();

    manager = new AccessManager(_admin);

    vm.stopBroadcast();

    _log("AccessManager deployed", address(manager));
    _log("Admin", _admin);

    return manager;
  }
}
