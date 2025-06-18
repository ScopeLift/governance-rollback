// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;


/**
 * @title IUpgradeRegressionManager
 * @author ScopeLift
 * @notice Interface for the Upgrade Regression Manager, which manages conditional rollback transactions
 */
interface IUpgradeRegressionManager {

    /*///////////////////////////////////////////////////////////////
                            Errors
    //////////////////////////////////////////////////////////////*/

    error URM_NotAuthorized();
    error URM_InvalidProposalId();

    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a rollback is queued by ITimelockMultiAdminShim.
     * @param proposalId The unique identifier of the associated proposal.
     */
    event RollbackQueued(bytes32 indexed proposalId);

    /**
     * @notice Emitted when a rollback is executed by ITimelockMultiAdminShim.
     * @param proposalId The unique identifier of the associated proposal.
     */
    event RollbackExecuted(bytes32 indexed proposalId);


    /**
     * @notice Emitted when the guardian is updated.
     * @param oldGuardian The old guardian.
     * @param newGuardian The new guardian.
     */
    event GuardianUpdated(address oldGuardian, address newGuardian);


    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

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

    /**
     * @notice Executes a rollback transaction.
     * @dev This function should be called by guardian
     * @param proposalId The unique identifier of the associated proposal.
     */
    function executeRollbackOperations(bytes32 proposalId) external;

    /**
     * @notice Returns the expiry time of a rollback proposal.
     * @param proposalId The unique identifier of the associated proposal.
     * @return Expiry time of the rollback proposal.
     */
    function rollbackExpiry(bytes32 proposalId) external view returns (uint256);
    
    /**
     * @notice Returns the guardian.
     * @return The guardian.
     */
    function guardian() external view returns (address);

    /**
     * @notice Updates the guardian.
     * @dev This function should be called by the current guardian.
     * @param newGuardian The new guardian.
     */
    function updateGuardian(address newGuardian) external;

    /**
     * @notice Returns the duration of the rollback execution window, in seconds.
     * @dev This is the amount of time after proposal execution during which a rollback can be triggered.
     * @return Duration in seconds of the rollback execution window.
     */
    function executionWindow() external view returns (uint256);

    /**
     * @notice Returns the address of the TimelockMultiAdminShim contract.
     * @return The address of the TimelockMultiAdminShim contract.
     */
    function timelockMultiAdminShim() external view returns (address);


    // QUESTIONS:
    //   function isRollbackQueued(bytes32 proposalId) external view returns (bool);
    //   function isRollbackExecuted(bytes32 proposalId) external view returns (bool);
    //   function getRollbackOperations(bytes32 proposalId) external view returns (bytes32);
    //   once we set the shim contract as the authorized caller, can this be updated ?
}