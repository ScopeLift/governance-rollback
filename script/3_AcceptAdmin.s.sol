// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {TimelockMultiAdminShim} from "src/TimelockMultiAdminShim.sol";
import {RollbackManagerTimelockCompoundDeployInput} from "script/RollbackManagerTimelockCompoundDeployInput.sol";
import {BaseLogger} from "script/BaseLogger.sol";

/// @title AcceptAdmin
/// @notice Script to accept the admin role from the TimelockMultiAdminShim
/// @dev This script calls acceptAdmin on the legacy Compound-style Timelock
contract AcceptAdmin is Script, BaseLogger, RollbackManagerTimelockCompoundDeployInput {
  function run() public {
    vm.startBroadcast();

    if (TIMELOCK_MULTI_ADMIN_SHIM == address(0)) {
      revert("TIMELOCK_MULTI_ADMIN_SHIM is not set");
    }

    // Accept admin
    TimelockMultiAdminShim(TIMELOCK_MULTI_ADMIN_SHIM).acceptAdmin();

    vm.stopBroadcast();
  }

  function invokeAcceptAdmin(address timelockMultiAdminShim) public {
    TimelockMultiAdminShim(timelockMultiAdminShim).acceptAdmin();
  }
}
