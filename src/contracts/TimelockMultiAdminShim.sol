// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.26; // TODO: can this be 0.8.20 ? 


contract TimelockMultiAdminShim  {

    // Storage
    // - admin: address with permission to manage executors.
    // - executorStatus: mapping of executor to status


    // Function
    // - isExecutor(address _executor) : returns bool
    // - admin():  just make the admin storage public
    // - transferAdmin(address): optional — allows emergency transfer. (can do pending new admin )

    // - _queueOperations 
        // example:
        // [
        //     {
        //         target: contractA,
        //         calldata: setFee(1e18)
        //     },
        //     {
        //         target: URM,
        //         calldata: queueOperations(proposalId, [contractA], [0], [setFee(0)]) // IS THIS RIGHT ?
        //     }
        // ]

        // - get proposal Id
        // - decode rollback txns (double decoding -> does the second decode happen in the URM ? )
        // - fwd primary txns to Timelock.queueOperations
        // - fwd rollback txns to URM.queueOperations


    // - _executeOperations
        // - get proposal Id
        // - check if it's valid
        // - invoke timelock.executeOperations

    // - implement _executeRollbackOperations
        // - get proposal Id
        // - check if it's valid
        // - invoke URM.executeRollbackOperations

    // QUESTIONS: would rollback txns be taken into account while generating the proposal Id ? 
}