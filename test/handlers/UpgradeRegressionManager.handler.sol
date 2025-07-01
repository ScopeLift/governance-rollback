// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

// Internal Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";

contract UpgradeRegressionManagerHandler is CommonBase, StdCheats, StdUtils {
  UpgradeRegressionManager public urm;
  FakeProtocolContract public target;

  address public admin;
  address public guardian;

  address[] public rollbackTargets;
  uint256[] public rollbackValues;
  bytes[] public rollbackCalldatas;

  string public constant DESCRIPTION = "test rollback";

  constructor(UpgradeRegressionManager _urm, address _admin, address _guardian, FakeProtocolContract _target) {
    // set initial state
    urm = _urm;
    admin = _admin;
    guardian = _guardian;
    target = _target;

    // set up rollback
    rollbackTargets = new address[](1);
    rollbackValues = new uint256[](1);
    rollbackCalldatas = new bytes[](1);

    rollbackTargets[0] = address(_target);
    rollbackValues[0] = 0;
    rollbackCalldatas.push(abi.encodeWithSelector(FakeProtocolContract.setFee.selector, 10));
  }

  function proposeRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public {
    vm.prank(admin);
    try urm.propose(_targets, _values, _calldatas, _description) {} catch {}
  }

  function queueRollback() public {
    vm.prank(guardian);
    try urm.queue(rollbackTargets, rollbackValues, rollbackCalldatas, DESCRIPTION) {} catch {}
  }

  function executeRollback() public {
    vm.prank(guardian);
    try urm.execute(rollbackTargets, rollbackValues, rollbackCalldatas, DESCRIPTION) {} catch {}
  }

  function cancelRollback() public {
    vm.prank(admin);
    try urm.cancel(rollbackTargets, rollbackValues, rollbackCalldatas, DESCRIPTION) {} catch {}
  }

  function getRollbackId() public view returns (uint256) {
    return urm.getRollbackId(rollbackTargets, rollbackValues, rollbackCalldatas, DESCRIPTION);
  }
}
