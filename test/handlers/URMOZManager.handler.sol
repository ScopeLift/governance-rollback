// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {URMCore} from "src/contracts/URMCore.sol";
import {URMOZManager} from "src/contracts/urm/URMOZManager.sol";
import {MockOZTargetTimelock} from "test/mocks/MockOZTargetTimelock.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {URMHandlerBase} from "test/helpers/URMHandlerBase.sol";

/// @title URMOZManagerHandler
/// @notice Handler contract for URMOZManager invariant testing
contract URMOZManagerHandler is URMHandlerBase {
  URMOZManager public urm;
  MockOZTargetTimelock public timelockTarget;

  constructor(URMOZManager _urm, address _admin, address _guardian, FakeProtocolContract[] memory _targets)
    URMHandlerBase(_admin, _guardian, _targets)
  {
    urm = _urm;
    _setURMAddress();
  }

  function _getURM() internal view override returns (URMCore) {
    return urm;
  }

  function _getDescription() internal pure override returns (string memory) {
    return "Rollback proposal";
  }
}
