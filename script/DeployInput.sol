// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

contract DeployInput {
  // Compound DAO Timelock contract
  address payable public constant COMPOUND_TIMELOCK = payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);
  // Compound Governor contract
  address public constant COMPOUND_GOVERNOR = 0x309a862bbC1A00e45506cB8A802D1ff10004c8C0;

  // Address that can queue, cancel and execute rollback
  // The GUARDIAN is set to the "Compound Community multisig," summarized here:
  // https://docs.google.com/document/d/19-GFwd34UlPHIx-AjlGlI3BQcWq71UKe/
  address public constant GUARDIAN = 0xbbf3f1421D886E9b2c5D716B5192aC998af2012c;

  // Time duration during which a proposed rollback can be queued for execution.
  uint256 public constant ROLLBACK_QUEUEABLE_DURATION = 4 weeks;

  // Lower bound for rollback queue duration (set to same value as COMPOUND_GOVERNOR.votingDelay)
  uint256 public constant MIN_ROLLBACK_QUEUEABLE_DURATION = 13_140;

  // Deployed TimelockMultiAdminShim contract
  address public TIMELOCK_MULTI_ADMIN_SHIM = address(0);

  // Deployed UpgradeRegressionManager contract
  address public UPGRADE_REGRESSION_MANAGER = address(0);
}
