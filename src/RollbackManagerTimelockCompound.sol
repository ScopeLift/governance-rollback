// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Libraries
import {RollbackManager} from "src/RollbackManager.sol";
import {ITimelockTargetCompound} from "interfaces/ITimelockTargetCompound.sol";

/// @title RollbackManagerTimelockCompound
/// @author [ScopeLift](https://scopelift.co)
/// @notice Integrates RollbackManager with a Compound-style Timelock contract as the execution target.
/// @dev This contract implements the rollback proposal lifecycle using Compound's Timelock interface.
/// It interacts with the target using individual `queueTransaction`, `cancelTransaction`, and `executeTransaction`
/// calls for each action.
///      Usecase:
///        - Use this contract when your system uses Compound-style Timelocks, often found in simpler or more minimal
/// governance systems (e.g., Compound, Fuse, etc.).
///      Key Differences from RollbackManagerTimelockControl:
///       - Queues, cancels, and executes each transaction individually (per `queueTransaction`).
///       - Computes rollback IDs using `keccak256(abi.encode(...))` of the batch parameters.
///       - Uses the `delay()` function on the target contract to determine delay.
///       - No batch operation support or salt-based identifiers — relies purely on encoded parameters and ETA.
///      Requirements:
///        - The `TARGET_TIMELOCK` must conform to the `ITimelockTargetCompound` interface, compatible with Compound's
/// Timelock.
/// @dev Source:
/// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/vendor/compound/ICompoundTimelock.sol
contract RollbackManagerTimelockCompound is RollbackManager {
  /*///////////////////////////////////////////////////////////////
                          Constructor
  //////////////////////////////////////////////////////////////*/

  constructor(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) RollbackManager(_targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration) {}

  /*///////////////////////////////////////////////////////////////
                          Overrides
  //////////////////////////////////////////////////////////////*/

  /// @notice Returns the rollback id for a given set of parameters.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The rollback ID.
  /// @dev This rollback id can be produced from the rollback data which is part of the {RollbackProposed} event.
  ///      It can even be computed in advance, before the rollback is proposed.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/governance/extensions/GovernorTimelockCompound.sol#L75
  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) public pure override returns (uint256) {
    return uint256(keccak256(abi.encode(_targets, _values, _calldatas, _description)));
  }

  /// @notice Returns the minimum delay required by the timelock target before a queued rollback can be executed.
  /// @return The delay of the timelock target.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/vendor/compound/ICompoundTimelock.sol#L53
  function _delay() internal view override returns (uint256) {
    return ITimelockTargetCompound(TARGET_TIMELOCK).delay();
  }

  /// @notice Queues a rollback to the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/vendor/compound/ICompoundTimelock.sol#L63-L69
  function _queue(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    uint256 _executableAt = _getRollbackExecutableAt(_targets, _values, _calldatas, _description);

    for (uint256 _i = 0; _i < _targets.length; _i++) {
      ITimelockTargetCompound(TARGET_TIMELOCK).queueTransaction(
        _targets[_i], _values[_i], "", _calldatas[_i], _executableAt
      );
    }
  }

  /// @notice Cancels a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/vendor/compound/ICompoundTimelock.sol#L71-L77
  function _cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    uint256 _executableAt = _getRollbackExecutableAt(_targets, _values, _calldatas, _description);

    for (uint256 _i = 0; _i < _targets.length; _i++) {
      ITimelockTargetCompound(TARGET_TIMELOCK).cancelTransaction(
        _targets[_i], _values[_i], "", _calldatas[_i], _executableAt
      );
    }
  }

  /// @notice Executes a rollback on the timelock target.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @dev Source:
  /// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/ba35d580f47ba90494eb9f3d26f58f7949b10c67/contracts/vendor/compound/ICompoundTimelock.sol#L79-L85
  function _execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal override {
    uint256 _executableAt = _getRollbackExecutableAt(_targets, _values, _calldatas, _description);

    for (uint256 _i = 0; _i < _targets.length; _i++) {
      ITimelockTargetCompound(TARGET_TIMELOCK).executeTransaction(
        _targets[_i], _values[_i], "", _calldatas[_i], _executableAt
      );
    }
  }

  /*///////////////////////////////////////////////////////////////
                          Internal Functions
  //////////////////////////////////////////////////////////////*/

  /// @notice Utility to return the executableAt timestamp for a rollback.
  /// @param _targets The targets of the transactions.
  /// @param _values The values of the transactions.
  /// @param _calldatas The calldatas of the transactions.
  /// @param _description The description of the rollback.
  /// @return The executableAt timestamp for the rollback.
  function _getRollbackExecutableAt(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal view returns (uint256) {
    uint256 _rollbackId = getRollbackId(_targets, _values, _calldatas, _description);
    return rollbacks[_rollbackId].executableAt;
  }
}
