// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {TimelockMultiAdminShim} from "src/contracts/TimelockMultiAdminShim.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";
import {MockCompoundTimelock} from "test/mocks/MockCompoundTimelock.sol";

contract TimelockMultiAdminShimTest is Test {
  TimelockMultiAdminShim public timelockMultiAdminShim;
  MockCompoundTimelock public timelock;

  function setUp() external {
    timelock = new MockCompoundTimelock();
   
    timelockMultiAdminShim = new TimelockMultiAdminShim(
      address(this),
      timelock
    );
  }
}