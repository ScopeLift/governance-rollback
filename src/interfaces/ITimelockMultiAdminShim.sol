// Inspired by contract lib/openzeppelin-contracts/contracts/vendor/compound/ICompoundTimelock.sol
// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;
import { ICompoundTimelock } from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";


/**
 * @title ITimelockMultiAdminShim
 * @author ScopeLift
 * @notice Interface for a shim contract that wraps Compound's Timelock to support multiple authorized executors.
 * @dev Extends the ICompoundTimelock interface to enable controlled delegation of execution rights while preserving compatibility.
 */
interface ITimelockMultiAdminShim is ICompoundTimelock {
    
    /*///////////////////////////////////////////////////////////////
                            Events
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when the executor status of an address is toggled.
     * @param executor The address whose status was updated.
     * @param status True if the address is now authorized as an executor, false otherwise.
     */
    event ExecutorStatusToggled(address indexed executor, bool status);


    /*///////////////////////////////////////////////////////////////
                            Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Toggle execution rights for a given address.
     * @dev Only callable by the Governor (or an authorized caller).
     * @param executor The address whose executor status is to be toggled.
     */
    function toggleExecutorStatus(address executor) external;

    /**
     * @notice Checks whether an address is authorized to execute transactions.
     * @param executor The address to check.
     * @return True if the address is an authorized executor, false otherwise.
     */
    function isExecutor(address executor) external view returns (bool);

    /**
     * @notice Returns the address of the Upgrade Regression Manager.
     * @return The address of the Upgrade Regression Manager.
     */
    function upgradeRegressionManager() external view returns (address);

    /**
     * @notice Returns the address of the admin.
     * @return The address of the admin.
     */
    function admin() external view returns (address);

    // QUESTIONS:
    //   can we add a function to set the upgrade regression manager ?
}