// SPDX-License-Identifier: UNLICENSED
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

// External imports
import {Script} from "forge-std/Script.sol";
import {AccessManager} from "@openzeppelin/contracts/access/manager/AccessManager.sol";

// Internal imports
import {BaseLogger} from "script/BaseLogger.sol";
import {CouncilExecutor} from "src/CouncilExecutor.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";

/// @title DeployCouncilExecutor
/// @notice Deploys a CouncilExecutor using an existing AccessManager.
/// @dev After deployment, configure allowed (target, selector) pairs.
///
///      Via Etherscan (AccessManager contract → Write Contract):
///      1. Call `grantRole(roleId, councilGovernor, 0)`
///         - roleId: uint64, e.g. 1 for COUNCIL_ROLE
///         - account: address of the council governor
///         - executionDelay: 0 (no delay)
///
///      2. Call `setTargetFunctionRole(target, selectors, roleId)`
///         - target: address of contract the council can call (e.g. Token)
///         - selectors: bytes4[] array of function selectors, e.g. ["0x40c10f19"] for mint(address,uint256)
///         - roleId: uint64, same role granted to the governor
///
///      To get a function selector: bytes4(keccak256("functionName(argType1,argType2)"))
contract DeployCouncilExecutor is Script, BaseLogger {
  /// @notice Deploys CouncilExecutor with an existing AccessManager
  /// @param _councilVetoGovernor Address of the council veto governor contract
  /// @param _shim Address of the TimelockMultiAdminShim
  /// @param _accessManager Address of the shared AccessManager (deployed via script 4)
  /// @return executor The deployed CouncilExecutor
  function run(address _councilVetoGovernor, address payable _shim, address _accessManager)
    public
    returns (CouncilExecutor executor)
  {
    vm.startBroadcast();

    executor = new CouncilExecutor(_councilVetoGovernor, TimelockMultiAdminShim(_shim), _accessManager);

    vm.stopBroadcast();

    _log("CouncilExecutor deployed", address(executor));
    _log("Council Veto Governor", _councilVetoGovernor);
    _log("Shim", _shim);
    _log("AccessManager", _accessManager);

    return executor;
  }
}
