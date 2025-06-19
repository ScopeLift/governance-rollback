// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// External Imports
import {ICompoundTimelock} from "@openzeppelin/contracts/vendor/compound/ICompoundTimelock.sol";

// Internal Imports
import {ITimelockMultiAdminShim} from "interfaces/ITimelockMultiAdminShim.sol";

contract TimelockMultiAdminShim is ITimelockMultiAdminShim {
  /*///////////////////////////////////////////////////////////////
                            Storage
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ITimelockMultiAdminShim
  address public governor;

  /// @inheritdoc ITimelockMultiAdminShim
  ICompoundTimelock public immutable TIMELOCK;

  /// @inheritdoc ITimelockMultiAdminShim
  mapping(address => bool) public isExecutor;

  /*///////////////////////////////////////////////////////////////
                            Constructor
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Constructor for the TimelockMultiAdminShim contract.
   * @param _governor The address of the Governor contract.
   * @param _timelock The address of the Compound Timelock contract.
   */
  constructor(address _governor, ICompoundTimelock _timelock) {
    // Validate inputs
    if (_governor == address(0)) {
      revert TimelockMultiAdminShim__InvalidGovernor();
    }
    if (address(_timelock) == address(0)) {
      revert TimelockMultiAdminShim__InvalidTimelock();
    }

    // Initialize storage
    governor = _governor;
    TIMELOCK = _timelock;

    // ASK-TEAM: Add event for initialization ?
  }

  /*///////////////////////////////////////////////////////////////
                    Proxy Timelock Functions 
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ITimelockMultiAdminShim
  function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    public
    returns (bytes32)
  {
    _revertIfCannotQueue(target);
    return TIMELOCK.queueTransaction(target, value, signature, data, eta);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function cancelTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    public
  {
    TIMELOCK.cancelTransaction(target, value, signature, data, eta);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta)
    public
    payable
    returns (bytes memory)
  {
    return TIMELOCK.executeTransaction(target, value, signature, data, eta);
  }

  /*///////////////////////////////////////////////////////////////
                      External Functions
  //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ITimelockMultiAdminShim
  function addExecutor(address _newExecutor) external {
    _revertIfNotTimelock();
    isExecutor[_newExecutor] = true;
    emit ExecutorAdded(_newExecutor);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function removeExecutor(address _executor) external {
    _revertIfNotTimelock();
    isExecutor[_executor] = false;
    emit ExecutorRemoved(_executor);
  }

  /// @inheritdoc ITimelockMultiAdminShim
  function updateGovernor(address _newGovernor) external {
    _revertIfNotTimelock();
    governor = _newGovernor;
    emit GovernorUpdated(_newGovernor);
  }

  /*///////////////////////////////////////////////////////////////
                        Internal Functions
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Validates authorization for queueing transactions to the timelock.
   * @param target The address of the contract that the function call targets.
   * @dev Reverts with TimelockMultiAdminShim__Unauthorized if:
   *      - The target is this contract and the caller is not the governor.
   *      - Allows any caller to queue transactions targeting external contracts.
   */
  function _revertIfCannotQueue(address target) internal view {
    if (target == address(this) && msg.sender != governor) {
      revert TimelockMultiAdminShim__Unauthorized();
    }
  }

  /**
   * @notice Reverts if the caller is not the timelock.
   */
  function _revertIfNotTimelock() internal view {
    if (msg.sender != address(TIMELOCK)) {
      revert TimelockMultiAdminShim__Unauthorized();
    }
  }
}

/*///////////////////////////////////////////////////////////////
                      Team Notes
//////////////////////////////////////////////////////////////*/

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
