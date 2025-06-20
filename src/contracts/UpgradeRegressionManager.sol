pragma solidity 0.8.30;

import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";
import { ITimelockMultiAdminShim } from "interfaces/ITimelockMultiAdminShim.sol";

contract UpgradeRegressionManager {

    ITimelockMultiAdminShim public shim;

    // Address that execute transactions which would invoke timelockMultiAdminShim.executeTransaction()
    address public guardian; 

    // Address that can add things to the timelockMultiAdminShim.enqueueForExecution()
    // this would be CompoundTimelock
    ICompoundTimelock public immutable QUEUER; 

    // The duration of the execution window (added to block.timestamp)
    uint256 public executionWindowDuration; 

    // Tracks the time before which the rollback can be queued
    // QUESTION: Is this right ?
    mapping (uint256 rollbackId => uint256 expiration) rollbackExpirations;
    
    // Tracks the time after which the rollback can be executed
    // QUESTION: Is this right ?
    mapping (uint256 rollbackId => uint256 eta) pendingRollbackExecutions;


    // Do basic setup of the URM
    constructor(
        ITimelockMultiAdminShim _shim,
        address _guardian,
        ICompoundTimelock _queuer,
        uint256 _executionWindowDuration
    ) {
        QUEUER = _queuer; 
        shim = _shim;
        guardian = _guardian;
        executionWindowDuration = _executionWindowDuration;
        // ..blah blah
    }

    // This is called by queuer (AKA timelock) when it executes the actual proposal 
    // and the rollback part is proposed to the URM contract
    function propose(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external {
        if (msg.sender != address(QUEUER)) {
            revert();
        }

        uint256 _rollbackId = hashRollback(_targets, _values, _calldatas, keccak256(bytes(_description)));
        rollbackExpirations[_rollbackId] = block.timestamp + executionWindowDuration;
        // emit an event etc
    }

    // Once the rollback is proposed, within the executionWindowDuration, 
    // the executor can queue the rollback for execution
    function queue(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns (uint256 rollbackId) {
        // Ensure this is callable only by guardian
        uint256 _rollbackId = hashRollback(_targets, _values, _calldatas, keccak256(bytes(_description)));
        
        // Make sure rollbackId is in rollbackExpirations
        if (rollbackExpirations[_rollbackId] == 0) {
            revert();
        }

        // Lookup rollbackExpirations to make sure the guardian can queue the rollback
        if (
            rollbackExpirations[_rollbackId] > block.timestamp
        ) {
            revert();
        }


        // QUESTION : similar to GovernorTimelockCompoundUpgradeable._queueOperations ? Is this basically calling shim.queueOperation() ?
        // Iterate through targets and calldatas queueing them to the "Timelockable" executionTarget
       
        // Remove from the rollbackExpirations mapping so it can't be replayed
        delete rollbackExpirations[_rollbackId];

        // Add to a queue of expirations pending execution based on the timelock delay to know after when it can be executed
        pendingRollbackExecutions[_rollbackId] = block.timestamp + QUEUER.delay();
        // QUESTION: is this logic right ? because once queued -> we want to add the timelock delay to know after what perid can we do the execution

        return _rollbackId;
    }

    function executeRollback(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external {
        // Calculate the rollback ID
        uint256 _rollbackId = hashRollback(_targets, _values, _calldatas, keccak256(bytes(_description)));

        // Look up in the pending executions and make sure the time is elapsed (not strictly required but probably advisable)
        if (pendingRollbackExecutions[_rollbackId] < block.timestamp) {
            revert();
        }

        // iterate through the targets & calldatas & call shim.executeTransaction()

        // delete from the pendingRollbacks mapping to prevent replay
        delete pendingRollbackExecutions[_rollbackId];

        // emit event 
    }


    function cancelRollback(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external {
        // Calculate the rollback ID
        // Check if the rollback is in pendingRollbackExecutions
        // QUESTION: Should we allow cancelling? and if yes do we remove it from queue mapping or execution mapping ? 
        // If it is, cancel it
        // Delete from pendingRollbackExecutions
        // emit event
    }

    // UPDATE FUNCTIONS  (all callable only by the QUEUER (aka timelock))

    function updateExecutionWindowDuration(uint256 _newDuration) external {
        // can be called by the QUEUER (aka timelock)
        // QUESTION: How do restrict only the guardian to call this function ? 
        // update the executionWindowDuration
        // emit an event
    }

    function updateGuardian(address _newGuardian) external {
        // can be called by the QUEUER (aka timelock)
        // QUESTION: How do restrict only the guardian to call this function ? 
        // update the guardian
        // emit an event
    }

    // Should we able to change the shim ? 


    function hashRollback(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));

    }

    function getRollbackId(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) external pure returns (uint256) {
        // similar to hashRollback but checks if the proposal is in the pendingRollbackExecutions mapping
        // returns the rollbackId for a given proposal
        return hashRollback(targets, values, calldatas, descriptionHash);
    }

}