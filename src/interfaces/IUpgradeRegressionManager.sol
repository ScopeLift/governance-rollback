// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Internal Libraries
import {ITimelockTarget} from "interfaces/ITimelockTarget.sol";
import {Rollback, ProposalState} from "types/GovernanceTypes.sol";

interface IUpgradeRegressionManager {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  function TARGET() external view returns (ITimelockTarget);

  function admin() external view returns (address);

  function guardian() external view returns (address);

  function rollbackQueueableDuration() external view returns (uint256);

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

  function setRollbackQueueableDuration(uint256 _newRollbackQueueableDuration) external;

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

  function state(uint256 _rollbackId) external view returns (ProposalState);
}
