// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUpgradeRegressionManager {
  /**
   * @notice Queues a rollback transaction for execution.
   * @param proposalId The unique identifier of the associated proposal.
   * @param _rollbackTargets The targets of the rollback transactions.
   * @param _rollbackValues The values of the rollback transactions.
   * @param _rollbackCalldatas The calldatas of the rollback transactions.
   */
  function queueRollbackOperations(
    bytes32 proposalId,
    address[] memory _rollbackTargets,
    uint256[] memory _rollbackValues,
    bytes[] memory _rollbackCalldatas
  ) external;
}
