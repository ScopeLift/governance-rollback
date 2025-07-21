// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {RollbackManagerTimelockControl} from "src/RollbackManagerTimelockControl.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

/// @title RollbackManagerTimelockControlHandler
/// @notice Handler contract for RollbackManagerTimelockControl invariant testing
contract RollbackManagerTimelockControlHandler is RollbackManagerHandlerBase {
  RollbackManagerTimelockControl public rollbackManager;

  constructor(
    RollbackManagerTimelockControl _rollbackManager,
    address _admin,
    address _guardian,
    FakeProtocolContract[] memory _targets
  ) RollbackManagerHandlerBase(_admin, _guardian, _targets) {
    rollbackManager = _rollbackManager;
    _setRollbackManagerAddress();
  }

  function _getRollbackManager() internal view override returns (RollbackManager) {
    return rollbackManager;
  }

  function _getDescription() internal pure override returns (string memory) {
    return "Rollback proposal";
  }
}
