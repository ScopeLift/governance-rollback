// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Imports
import {RollbackManager} from "src/RollbackManager.sol";
import {RollbackManagerTimelockCompound} from "src/RollbackManagerTimelockCompound.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {RollbackManagerHandlerBase} from "test/helpers/RollbackManagerHandlerBase.sol";

/// @title RollbackManagerTimelockCompoundHandler
/// @notice Handler contract for RollbackManagerTimelockCompound invariant testing
/// @dev This handler extends RollbackManagerHandlerBase and provides Compound-specific functionality
contract RollbackManagerTimelockCompoundHandler is RollbackManagerHandlerBase {
  RollbackManagerTimelockCompound public rollbackManager;

  constructor(
    RollbackManagerTimelockCompound _rollbackManager,
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
    return "test rollback";
  }
}
