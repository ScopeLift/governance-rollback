// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

interface ITimelockMultiAdminShim {
  /*///////////////////////////////////////////////////////////////
                     Public Storage 
  //////////////////////////////////////////////////////////////*/

  function TIMELOCK() external view returns (ICompoundTimelock);

  function admin() external view returns (address);

  function isExecutor(address) external view returns (bool);

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  function addExecutor(address _newExecutor) external;

  function removeExecutor(address _executor) external;

  function setAdmin(address _newAdmin) external;

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  function GRACE_PERIOD() external view returns (uint256);

  function MINIMUM_DELAY() external view returns (uint256);

  function MAXIMUM_DELAY() external view returns (uint256);

  function queueTransaction(address _target, uint256 _value, string memory _signature, bytes memory _data, uint256 _eta)
    external
    returns (bytes32);

  function cancelTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external;

  function executeTransaction(
    address _target,
    uint256 _value,
    string memory _signature,
    bytes memory _data,
    uint256 _eta
  ) external payable returns (bytes memory);

  function delay() external view returns (uint256);

  function acceptAdmin() external;
}
