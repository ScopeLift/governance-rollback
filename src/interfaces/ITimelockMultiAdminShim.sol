// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface ITimelockMultiAdminShim {

  /*///////////////////////////////////////////////////////////////
                     External Functions 
  //////////////////////////////////////////////////////////////*/

  function addExecutor(address _newExecutor) external;

  function removeExecutor(address _executor) external;

  function updateAdmin(address _newAdmin) external;

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    returns (bytes32);

  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external;

  function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    external
    payable
    returns (bytes memory);

}
