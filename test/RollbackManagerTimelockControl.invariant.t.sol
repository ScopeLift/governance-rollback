// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {MockTimelockTargetControl} from "test/mocks/MockTimelockTargetControl.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackManagerTimelockControlHandler} from "test/handlers/RollbackManagerTimelockControl.handler.sol";
import {RollbackManagerInvariantTestBase} from "test/helpers/RollbackManagerInvariantTestBase.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

contract RollbackManagerTimelockControlInvariantTest is RollbackManagerInvariantTestBase {
  RollbackManagerTimelockControl public rollbackManager;
  MockTimelockTargetControl public timelockTarget;
  RollbackManagerHandlerBase public handler;

  function _setupHandler() internal override {
    timelockTarget = new MockTimelockTargetControl();
    timelockTarget.setMinDelay(delay);

    rollbackProposalTargets = new FakeProtocolContract[](3);
    rollbackProposalTargets[0] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[1] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[2] = new FakeProtocolContract(address(timelockTarget));

    rollbackManager = new RollbackManagerTimelockControl(address(timelockTarget), admin, guardian, delay, delay);

    handler = new RollbackManagerTimelockControlHandler(rollbackManager, admin, guardian, rollbackProposalTargets);
  }

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _getHandler() internal view override returns (RollbackManagerHandlerBase) {
    return handler;
  }
}
