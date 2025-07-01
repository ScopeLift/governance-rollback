// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {console} from "forge-std/console.sol";

// Internal Imports
import {URMCore} from "src/contracts/URMCore.sol";
import {URMCompoundManager} from "src/contracts/urm/URMCompoundManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {URMHandlerBase} from "test/helpers/URMHandlerBase.sol";

/// @title URMCompoundManagerHandler
/// @notice Handler contract for URMCompoundManager invariant testing
/// @dev This handler extends URMHandlerBase and provides Compound-specific functionality
contract URMCompoundManagerHandler is URMHandlerBase {
  URMCompoundManager public urm;

  constructor(URMCompoundManager _urm, address _admin, address _guardian, FakeProtocolContract[] memory _targets)
    URMHandlerBase(_admin, _guardian, _targets)
  {
    urm = _urm;
    _setURMAddress();
  }

  function _getURM() internal view override returns (URMCore) {
    return urm;
  }

  function _getDescription() internal pure override returns (string memory) {
    return "test rollback";
  }
}
