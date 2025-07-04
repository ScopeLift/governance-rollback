// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Libraries
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// Internal Libraries
import {ITimelockTarget} from "interfaces/ITimelockTarget.sol";

/// @notice Struct to store rollback data.
/// @param queueExpiresAt The timestamp before which the rollback must be queued for execution.
/// @param executableAt The timestamp after which the rollback can be executed.
/// @param executed Whether the rollback has been executed.
/// @param canceled Whether the rollback has been canceled.
/// @dev executed and canceled are mutually exclusive - both cannot be true
///      queueExpiresAt must be > block.timestamp when rollback is proposed
///      executableAt must be > block.timestamp when rollback is queued
struct Rollback {
  uint48 queueExpiresAt;
  uint48 executableAt;
  bool executed;
  bool canceled;
}

interface IUpgradeRegressionManager {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  function TARGET() external view returns (ITimelockTarget);

  function admin() external view returns (address);

  function guardian() external view returns (address);

  function rollbackQueueWindow() external view returns (uint256);

  function getRollback(uint256 _rollbackId) external view returns (Rollback memory);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  function propose(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId);

  function queue(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId);

  function cancel(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId);

  function execute(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external returns (uint256 _rollbackId);

  function setGuardian(address _newGuardian) external;

  function setRollbackQueueWindow(uint256 _newRollbackQueueWindow) external;

  function setAdmin(address _newAdmin) external;

  /*///////////////////////////////////////////////////////////////
                     Public Functions 
  //////////////////////////////////////////////////////////////*/

  function getRollbackId(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) external view returns (uint256 _rollbackId);

  function state(uint256 _rollbackId) external view returns (IGovernor.ProposalState);
}
