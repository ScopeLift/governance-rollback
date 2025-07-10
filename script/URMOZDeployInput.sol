// SPDX-License-Identifier: MIT
// slither-disable-start reentrancy-benign

pragma solidity 0.8.30;

contract URMOZDeployInput {
  // OpenZeppelin-style TimelockController contract
  address payable public constant OZ_TIMELOCK = payable(0xCdBf527842Ab04Da548d33EB09d03DB831381Fb0);

  // OpenZeppelin Governor contract
  address public constant OZ_GOVERNOR = 0xcB1622185A0c62A80494bEde05Ba95ef29Fbf85c;

  // Address that can queue, cancel and execute rollback
  // NOTE: This is the address which deployed the obol. This should be updated to Obol's trusted multisig.
  address public constant GUARDIAN = 0x02b5D1Fd67246c0513223D320901474aA20Bf973;

  // Time duration during which a proposed rollback can be queued for execution.
  uint256 public constant ROLLBACK_QUEUEABLE_DURATION = 4 weeks;

  // Lower bound for rollback queue duration
  uint256 public constant MIN_ROLLBACK_QUEUEABLE_DURATION = 13_140;

  // Deployed URMOZManager contract
  address public URM_OZ_MANAGER = address(0);
}
