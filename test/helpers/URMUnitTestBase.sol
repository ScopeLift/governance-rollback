// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {URMCore} from "src/contracts/URMCore.sol";
import {Rollback, ProposalState} from "src/types/GovernanceTypes.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";

/// @title Base contract for URM unit tests
/// @notice Contains common setup and helper functions for both URMOZManager and URMCompoundManager
/// @dev This base contract reduces code duplication between the two unit test suites
abstract contract URMUnitTestBase is Test {
  URMCore public urm;

  address public guardian = makeAddr("guardian");
  address public admin = makeAddr("admin");
  uint256 public rollbackQueueableDuration = 1 days;
  uint256 public minRollbackQueueableDuration = 5 minutes;

  // Abstract functions that must be implemented by child contracts
  function _getURMType() internal view virtual returns (URMCore);
  function _getMockTimelock() internal view virtual returns (address);
  function _deployURM(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal virtual returns (URMCore);

  function setUp() public {
    urm = _deployURM(_getMockTimelock(), admin, guardian, rollbackQueueableDuration, minRollbackQueueableDuration);
  }

  /*///////////////////////////////////////////////////////////////
                      Common Helper Functions
  //////////////////////////////////////////////////////////////*/

  function _assumeSafeAdmin(address _admin) internal pure {
    vm.assume(_admin != address(0));
  }

  function _assumeSafeGuardian(address _guardian) internal pure {
    vm.assume(_guardian != address(0));
  }

  function _assumeSafeTargetTimelock(address _targetTimelock) internal pure {
    vm.assume(_targetTimelock != address(0));
  }

  function _boundToRealisticMinRollbackQueueableDuration(uint256 _minRollbackQueueableDuration)
    internal
    pure
    returns (uint256)
  {
    return bound(_minRollbackQueueableDuration, 1 hours, 20 days);
  }

  function _boundToRealisticRollbackQueueableDuration(
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal pure returns (uint256) {
    return bound(_rollbackQueueableDuration, _minRollbackQueueableDuration, 10 * 365 days);
  }

  function _assumeSafeInitParams(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal pure returns (uint256, uint256) {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    return (
      _minRollbackQueueableDuration,
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration)
    );
  }

  function _proposeRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    vm.prank(admin);
    _rollbackId = urm.propose(_targets, _values, _calldatas, _description);
  }

  function _proposeAndQueueRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    _proposeRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    _rollbackId = urm.queue(_targets, _values, _calldatas, _description);
  }

  function toDynamicArrays(
    address[2] memory _fixedTargets,
    uint256[2] memory _fixedValues,
    bytes[2] memory _fixedCalldatas
  ) internal pure returns (address[] memory targets, uint256[] memory values, bytes[] memory calldatas) {
    targets = new address[](2);
    values = new uint256[](2);
    calldatas = new bytes[](2);

    for (uint256 _i = 0; _i < 2; _i++) {
      targets[_i] = _fixedTargets[_i];
      values[_i] = _fixedValues[_i];
      calldatas[_i] = _fixedCalldatas[_i];
    }
  }
}
