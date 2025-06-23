// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

contract DeployInput {
  // Compound DAO Timelock contract
  address payable public constant COMPOUND_TIMELOCK = payable(0x6d903f6003cca6255D85CcA4D3B5E5146dC33925);
  // Compound Governor contract
  address public constant COMPOUND_GOVERNOR = 0x309a862bbC1A00e45506cB8A802D1ff10004c8C0;

  // Address that can queue, cancel and execute rollback
  address public constant GUARDIAN = 0x309a862bbC1A00e45506cB8A802D1ff10004c8C0;

  // Time window within which a rollback can be queued after it is proposed by admin
  uint256 public constant ROLLBACK_QUEUE_WINDOW = 7 days;

  // Deployed TimelockMultiAdminShim contract
  address public TIMELOCK_MULTI_ADMIN_SHIM = address(0);

  // Deployed UpgradeRegressionManager contract
  address public UPGRADE_REGRESSION_MANAGER = address(0);
}
