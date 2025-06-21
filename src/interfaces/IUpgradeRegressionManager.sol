// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Libraries
import {ITimelockTarget} from "interfaces/ITimelockTarget.sol";

interface IUpgradeRegressionManager {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  function TARGET() external view returns (ITimelockTarget);

  function admin() external view returns (address);

  function guardian() external view returns (address);

  function rollbackQueueWindow() external view returns (uint256);

  function rollbackQueueExpiresAt(uint256 _rollbackId) external view returns (uint256);

  function rollbackExecutableAt(uint256 _rollbackId) external view returns (uint256);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  function isRollbackEligibleToQueue(uint256 _rollbackId) external view returns (bool);

  function isRollbackReadyToExecute(uint256 _rollbackId) external view returns (bool);

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
}
