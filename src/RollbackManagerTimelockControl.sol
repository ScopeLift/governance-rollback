// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Libraries
import {RollbackManager} from "src/RollbackManager.sol";
import {ITimelockTargetControl} from "interfaces/ITimelockTargetControl.sol";

/// @title RollbackManagerTimelockControl
/// @author [ScopeLift](https://scopelift.co)
/// @notice Integrates RollbackManager with an OpenZeppelin-style TimelockController as the execution target.
/// @dev This contract implements the rollback proposal lifecycle using OpenZeppelin's TimelockController interface.
/// It interacts with the target using batch operations (`scheduleBatch`, `cancelBatch`, `executeBatch`) for efficiency.
///      Usecase:
///        - Use this contract when your system uses OpenZeppelin-style TimelockControllers, often found in more complex
/// governance systems (e.g., OpenZeppelin Governor, Aave, etc.).
///      Key Differences from RollbackManagerTimelockCompound:
///       - Uses batch operations for efficiency (single call per action).
///       - Computes rollback IDs using the timelock's `hashOperationBatch` method.
///       - Uses the `getMinDelay()` function on the target contract to determine delay.
///       - Supports salt-based identifiers for better transaction management.
///      Requirements:
///        - The `TARGET_TIMELOCK` must conform to the `ITimelockTargetControl` interface, compatible with
/// OpenZeppelin's
/// TimelockController.
///        - The `TARGET_TIMELOCK` must grant PROPOSER_ROLE, EXECUTOR_ROLE, and CANCELLER_ROLE to this contract or its
/// admin privileges to propose rollbacks to this RollbackManagerTimelockControl.
/// @dev Source:
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/TimelockController.sol
contract RollbackManagerTimelockControl is RollbackManager {
  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  /// @notice Constructor for RollbackManagerTimelockControl
  /// @param _target The TimelockController that will execute rollback transactions
  /// @param _admin The address that can propose rollbacks (should be the TimelockController in OZ Governor setups)
  /// @param _guardian The address that can queue, cancel, and execute rollbacks
  /// @param _rollbackQueueableDuration Duration after a rollback proposal during which it can be queued for execution
  /// @param _minRollbackQueueableDuration Lower bound enforced on the rollback queueable duration
  /// @dev In OpenZeppelin Governor + TimelockController setups, both _target and _admin should be set to the
  /// TimelockController.
  ///      This is because the TimelockController is the contract that executes scheduled transactions, and it needs
  ///      admin privileges to propose rollbacks to this RollbackManagerTimelockControl.
  constructor(
    address _target,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) RollbackManager(_target, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration) {}

  /*///////////////////////////////////////////////////////////////
                          Overrides
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the rollback id for a given set of parameters.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The rollback ID.
  /// @dev This rollback id can be produced from the rollback data which is part of the {RollbackCreated} event.
  ///      It can even be computed in advance, before the rollback is proposed.
  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public view override returns (uint256) {
    return uint256(_getRollbackHash(_targets, _values, _calldatas, _description));
  }

  /// @notice Returns the minimum delay required by the timelock target before a queued rollback can be executed.
  /// @return The delay in seconds that must elapse between queueing and executing a rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/TimelockController.sol#L224-L226
  function _delay() internal view override returns (uint256) {
    return ITimelockTargetControl(TARGET_TIMELOCK).getMinDelay();
  }

  /// @notice Schedules a rollback to the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockControl.sol#L87-L88
  function _queue(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    ITimelockTargetControl(TARGET_TIMELOCK).scheduleBatch(
      _targets, _values, _calldatas, 0, _timelockSalt(_description), _delay()
    );
  }

  /// @notice Cancels a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockControl.sol#L128
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    ITimelockTargetControl(TARGET_TIMELOCK).cancel(_getRollbackHash(_targets, _values, _calldatas, _description));
  }

  /// @notice Executes a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockControl.sol#L105
  function _execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    ITimelockTargetControl(TARGET_TIMELOCK).executeBatch{value: msg.value}(
      _targets, _values, _calldatas, 0, _timelockSalt(_description)
    );
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the salt for the operation.
  /// @param _description The description of the rollback.
  /// @return The salt for the operation.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockControl.sol#L164C1-L166C6
  function _timelockSalt(string memory _description) internal view returns (bytes32) {
    return bytes20(address(this)) ^ keccak256(bytes(_description));
  }

  /// @notice Returns the hash of the rollback operation.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The hash of the rollback operation.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockControl.sol#L87
  function _getRollbackHash(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal view returns (bytes32) {
    return ITimelockTargetControl(TARGET_TIMELOCK).hashOperationBatch(
      _targets, _values, _calldatas, 0, _timelockSalt(_description)
    );
  }
}
