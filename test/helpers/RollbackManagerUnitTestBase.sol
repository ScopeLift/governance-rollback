// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Contract Imports
import {RollbackManager} from "src/RollbackManager.sol";

// Test Imports
import {Test} from "forge-std/Test.sol";

/// @title Base contract for Rollback Manager unit tests
/// @notice Contains common setup and helper functions for both RollbackManagerTimelockControl and
/// RollbackManagerTimelockCompound
/// @dev This base contract reduces code duplication between the two unit test suites
abstract contract RollbackManagerUnitTestBase is Test {
  RollbackManager public rollbackManager;

  address public guardian = makeAddr("guardian");
  address public admin = makeAddr("admin");
  uint256 public rollbackQueueableDuration = 1 days;
  uint256 public minRollbackQueueableDuration = 5 minutes;

  // Abstract functions that must be implemented by child contracts
  function _getRollbackManagerType() internal view virtual returns (RollbackManager);
  function _deployRollbackManager(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) internal virtual returns (RollbackManager);

  function setUp() public virtual;
  // Child classes should override this method and call _deployRollbackManager with their specific mock timelock

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
    _rollbackId = rollbackManager.propose(_targets, _values, _calldatas, _description);
  }

  function _queueRollback(
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    string memory _description
  ) internal returns (uint256 _rollbackId) {
    _proposeRollback(_targets, _values, _calldatas, _description);
    vm.prank(guardian);
    _rollbackId = rollbackManager.queue(_targets, _values, _calldatas, _description);
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

abstract contract ConstructorBase is RollbackManagerUnitTestBase {
  function testFuzz_SetsInitialParameters(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    RollbackManager _rollbackManager = _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    assertEq(address(_rollbackManager.TARGET_TIMELOCK()), _targetTimelock);
    assertEq(_rollbackManager.MIN_ROLLBACK_QUEUEABLE_DURATION(), _minRollbackQueueableDuration);
    assertEq(_rollbackManager.admin(), _admin);
    assertEq(_rollbackManager.guardian(), _guardian);
    assertEq(_rollbackManager.rollbackQueueableDuration(), _rollbackQueueableDuration);
  }

  function testFuzz_EmitsRollbackQueueableDurationSet(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit RollbackManager.RollbackQueueableDurationSet(0, _rollbackQueueableDuration);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_EmitsGuardianSet(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (_minRollbackQueueableDuration, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );

    vm.expectEmit();
    emit RollbackManager.GuardianSet(address(0), _guardian);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_TargetTimelockIsZeroAddress(
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(address(0), _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration);
  }

  function testFuzz_RevertIf_AdminIsZeroAddress(
    address _targetTimelock,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(
      _targetTimelock, address(0), _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_GuardianIsZeroAddress(
    address _targetTimelock,
    address _admin,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeAdmin(_admin);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);
    _rollbackQueueableDuration =
      _boundToRealisticRollbackQueueableDuration(_rollbackQueueableDuration, _minRollbackQueueableDuration);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidAddress.selector);
    _deployRollbackManager(
      _targetTimelock, _admin, address(0), _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_DurationLessThanMin(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    _assumeSafeTargetTimelock(_targetTimelock);
    _assumeSafeAdmin(_admin);
    _assumeSafeGuardian(_guardian);
    _minRollbackQueueableDuration = _boundToRealisticMinRollbackQueueableDuration(_minRollbackQueueableDuration);

    // The rollback queueable duration is bound to be less than the min rollback queueable duration.
    uint256 _invalidRollbackQueueableDuration = bound(_rollbackQueueableDuration, 0, _minRollbackQueueableDuration - 1);

    vm.expectRevert(RollbackManager.RollbackManager__InvalidRollbackQueueableDuration.selector);
    _deployRollbackManager(
      _targetTimelock, _admin, _guardian, _invalidRollbackQueueableDuration, _minRollbackQueueableDuration
    );
  }

  function testFuzz_RevertIf_MinRollbackQueueableDurationIsZero(
    address _targetTimelock,
    address _admin,
    address _guardian,
    uint256 _rollbackQueueableDuration,
    uint256 _minRollbackQueueableDuration
  ) external {
    (, _rollbackQueueableDuration) = _assumeSafeInitParams(
      _targetTimelock, _admin, _guardian, _rollbackQueueableDuration, _minRollbackQueueableDuration
    );
    vm.expectRevert(RollbackManager.RollbackManager__InvalidRollbackQueueableDuration.selector);
    _deployRollbackManager(_targetTimelock, _admin, _guardian, _rollbackQueueableDuration, 0);
  }
}
