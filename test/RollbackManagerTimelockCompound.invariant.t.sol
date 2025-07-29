// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackManagerTimelockCompoundHandler} from "test/handlers/RollbackManagerTimelockCompound.handler.sol";
import {RollbackManagerInvariantTestBase} from "test/helpers/RollbackManagerInvariantTestBase.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

contract RollbackManagerTimelockCompoundInvariantTest is RollbackManagerInvariantTestBase {
  RollbackManagerTimelockCompound public rollbackManager;
  MockCompoundTimelock public timelockTarget;
  RollbackManagerHandlerBase public handler;

  function _setupHandler() internal override {
    timelockTarget = new MockCompoundTimelock();
    timelockTarget.setDelay(delay);

    rollbackProposalTargets = new FakeProtocolContract[](3);
    rollbackProposalTargets[0] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[1] = new FakeProtocolContract(address(timelockTarget));
    rollbackProposalTargets[2] = new FakeProtocolContract(address(timelockTarget));

    rollbackManager = new RollbackManagerTimelockCompound(address(timelockTarget), admin, guardian, delay, delay);

    handler = new RollbackManagerTimelockCompoundHandler(rollbackManager, admin, guardian, rollbackProposalTargets);
  }

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _getHandler() internal view override returns (RollbackManagerHandlerBase) {
    return handler;
  }
}
