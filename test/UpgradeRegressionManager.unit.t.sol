// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockTimelockMultiAdminShim} from "test/mocks/MockTimelockMultiAdminShim.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";

contract UpgradeRegressionManagerTest is Test {
  UpgradeRegressionManager public upgradeRegressionManager;

  MockCompoundTimelock public queuer;
  MockTimelockMultiAdminShim public shim;
  
  address public guardian = makeAddr("guardian");
  
  function setUp() external {
    queuer = new MockCompoundTimelock();
    shim = new MockTimelockMultiAdminShim();

    upgradeRegressionManager = new UpgradeRegressionManager(
      shim,
      guardian,
      queuer,
      1 days
    );
  }

  function _assumeSafeAdmin(address _admin) internal {
    vm.assume(_admin != address(0));
  }

  function _assumeSafeGuardian(address _guardian) internal {
    vm.assume(_guardian != address(0));
  }

  function _assumeSafeQueuer(address _queuer) internal {
    vm.assume(_queuer != address(0));
  }

  function _assumeSafeShim(address _shim) internal {
    vm.assume(_shim != address(0));
  }


}

contract Constructor is UpgradeRegressionManagerTest {
  function testFuzz_SetsIntializeParameters(address _shim, address _guardian, address _queuer, uint256 _executionWindowDuration) external {
    _assumeSafeShim(_shim);
    _assumeSafeGuardian(_guardian);
    _assumeSafeQueuer(_queuer);

    UpgradeRegressionManager _upgradeRegressionManager = new UpgradeRegressionManager(
      shim,
      guardian,
      queuer,
      executionWindowDuration
    );
    
    assertEq(address(_upgradeRegressionManager.shim()), _shim);
    assertEq(_upgradeRegressionManager.guardian(), _guardian);
    assertEq(address(_upgradeRegressionManager.QUEUER()), address(_queuer));
    assertEq(_upgradeRegressionManager.executionWindowDuration(), _executionWindowDuration);
  }
}


