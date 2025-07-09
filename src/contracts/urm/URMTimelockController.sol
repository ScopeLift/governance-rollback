// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {URMCore} from "contracts/URMCore.sol";
import {ITimelockControllerTarget} from "interfaces/ITimelockControllerTarget.sol";

/// @title URMTimelockController
/// @author [ScopeLift](https://scopelift.co)
/// @notice Integrates URMCore with an OpenZeppelin-style TimelockController as the execution target.
/// @dev This contract implements the rollback proposal lifecycle using OZ's TimelockController interface.
///      It derives the rollback ID via OZ's `hashOperationBatch` and interacts with the target using `scheduleBatch`,
/// `executeBatch`, and `cancel`.
///      Usecase:
///        - Use this contract when your system uses OpenZeppelin's TimelockController, typically found in
/// Governor-based governance setups.
///      Key Differences from URMCompoundTimelock:
///        - Calls OZ's `scheduleBatch`, `cancel`, and `executeBatch` on the timelock target.
///        - Computes rollback IDs using `hashOperationBatch` with a salt derived from the contract address and
/// description.
///        - Delay is fetched via `getMinDelay()` on the timelock.
///        - No per-transaction queueing — batch is scheduled/executed as a whole.
///      Requirements:
///        - The `TARGET` must conform to the `ITimelockControllerTarget` interface, which mirrors the OZ
/// TimelockController API.
/// @dev Source:
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/TimelockController.sol
contract URMTimelockController is URMCore {
  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  constructor(
    address _target,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) URMCore(_target, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration) {}

  /*///////////////////////////////////////////////////////////////
                          Overrides
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the rollback ID for a given set of parameters.
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

  /// @notice Returns the delay of the timelock target.
  /// @return The delay of the timelock target.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/TimelockController.sol#L224-L226
  function _delay() internal view override returns (uint256) {
    return ITimelockControllerTarget(TARGET).getMinDelay();
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
    ITimelockControllerTarget(TARGET).scheduleBatch(
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
    ITimelockControllerTarget(TARGET).cancel(_getRollbackHash(_targets, _values, _calldatas, _description));
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
    ITimelockControllerTarget(TARGET).executeBatch{value: msg.value}(
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
    return ITimelockControllerTarget(TARGET).hashOperationBatch(
      _targets, _values, _calldatas, 0, _timelockSalt(_description)
    );
  }
}
