// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Libraries
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal Libraries
import {IUpgradeRegressionManager} from "interfaces/IUpgradeRegressionManager.sol";

contract TimelockMultiAdminShim {
  error TimelockMultiAdminShim_Unauthorized();

  // TODO: add an interface for the Governor
  address public immutable GOVERNOR;

  ICompoundTimelock public immutable TIMELOCK;
  IUpgradeRegressionManager public immutable URM;

  mapping(address => bool) public isExecutor;

  // mapping to track all function signatures that are allowed to be called by the Governor
  mapping(bytes4 => bool) internal _governorAuthorizedSelectors;

  modifier onlyTimelock() {
    if (msg.sender != address(TIMELOCK)) revert TimelockMultiAdminShim_Unauthorized();
    _;
  }

  /**
   * @notice Constructor for the TimelockMultiAdminShim contract.
   * @param _governor The address of the Governor contract.
   * @param _timelock The address of the Compound Timelock contract.
   * @param _upgradeRegressionManager The address of the Upgrade Regression Manager contract.
   */
  constructor(address _governor, ICompoundTimelock _timelock, IUpgradeRegressionManager _upgradeRegressionManager) {
    
    // TODO: Add zero address checks

    GOVERNOR = _governor;
    TIMELOCK = _timelock;
    URM = _upgradeRegressionManager;

    _setGovernorAuthorizedFunctions();
  }

  ///// Proxy for the timelock /////

  function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta ) public returns (bytes32) {

    _isAuthorized(target, signature);
    
    // ASK-TEAM: would the timelock be updated to have shim be the admin ? 

    if (target == address(URM)) {

      // example: { target: URM, calldata: queueOperations(proposalId, [contractA], [0], [setFee(0)]) }
      // ASK-TEAM: 
      // When the target == URM, we're actually passing encoded rollback data in data. 
      // That’s the “double-encoded” part in the proposal docs.
      // So what we'd need to do 
      //  - decode data into its actual inputs b
      //  - call URM.queueRollbackOperations(...)
      (
        bytes32 proposalId, // ASK-TEAM: how do i get proposalId ? I think we need to pass it in the data
        address[] memory rollbackTargets,
        uint256[] memory rollbackValues,
        bytes[] memory rollbackCalldatas
      ) = abi.decode(data, (bytes32, address[], uint256[], bytes[]));

      URM.queueRollbackOperations(
        proposalId,
        rollbackTargets,
        rollbackValues,
        rollbackCalldatas
      );

      return proposalId;
    }

    // example: { target: contractA,  calldata: setFee(1e18) }
    return TIMELOCK.queueTransaction(target, value, signature, data, eta);
  }

  function cancelTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public {
    TIMELOCK.cancelTransaction(target, value, signature, data, eta);
  }

  function executeTransaction(address target, uint value, string memory signature, bytes memory data, uint eta) public payable returns (bytes memory) {
    return TIMELOCK.executeTransaction(target, value, signature, data, eta);
  }

  // ASK-TEAM:Functions ignored cause governor doesn't call them
  // setDelay(uint delay_)
  // acceptAdmin
  // setPendingAdmin


  ///// Core Management /////

  function addExecutor(address _newExecutor) public onlyTimelock {
    isExecutor[_newExecutor] = true;
  }

  function removeExecutor(address _executor) public onlyTimelock {
    isExecutor[_executor] = false;
  }

  /**
   * @notice Registers function selectors that the governor is allowed to call on this contract.
   */
  function _setGovernorAuthorizedFunctions() internal {
    string[2] memory authorizedSignatures = [
      "addExecutor(address)",
      "removeExecutor(address)"
    ];

    for (uint256 i = 0; i < authorizedSignatures.length; i++) {
      _governorAuthorizedSelectors[bytes4(keccak256(bytes(authorizedSignatures[i])))] = true;
    }
  }

  /**
   * @notice Checks if the caller is authorized to queue a specific function call via the TimelockShim.
   * @param target The address of the contract that the function call targets.
   * @param signature The function signature (e.g., "setAdmin(address)").
   * @return True if the call is authorized, otherwise reverts.
   */
  function _isAuthorized(address target, string memory signature) internal view returns (bool) {
    // Case 1: The call is targeting this contract (the shim itself)
    if (target == address(this)) {
      // Compute the function selector from the signature string
      bytes4 selector = bytes4(keccak256(bytes(signature)));

      // Check if the selector is authorized and the sender is the GOVERNOR
      if (_governorAuthorizedSelectors[selector] && msg.sender == GOVERNOR) {
        return true;
      }

      revert TimelockMultiAdminShim_Unauthorized();
    }

    // Case 2:The call targets an external contract (not this one),
    // allow it by default — assumed safe/external logic.
    return true;
  }
}


// This method should only be callable by the TIMELOCK *when the transaction originated from the Governor*
// Ways we might be able to do this:
// * In the shim, before forwarding to the timelock, cache the address that is making the call,
// and remember it when the Timelock calls it. Are there timing issues here where we can't know for sure
// that the transaction executing is the most recently cached executor? This would probably look like the
// OZ Governor protection that puts operations on the Governor itself into a `_governanceCall` queue. This
// method would allow the transaction to flow through the timelock, experience the timelock delay, execute
// from the timelock after the delay, and yet only be executable if the transaction came originally from
// Governor. ACTUALLY: Aditya points out we don't need a queue. In the `queueTransaction` method, if the
// sender is not the Governor, but the target is this contract, just revert.
// * In the queueTransaction method that calls the Timelock, have it observe the target/calldata and use some
// specific target/calldata combo as a "special" code that can configure the shim but only if sent from
// the Governor. For example, if the target address is this contract, execute immediately and remove from
// the list forwarded to the Timelock. This version would skip the time delay for transactions that configure
// the shim.