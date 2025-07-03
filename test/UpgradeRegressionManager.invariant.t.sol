// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// External Imports
import {Test} from "forge-std/Test.sol";

// Internal Imports
import {UpgradeRegressionManager} from "src/contracts/UpgradeRegressionManager.sol";
import {MockTimelockTarget} from "test/mocks/MockTimelockTarget.sol";
import {FakeProtocolContract} from "test/fakes/FakeProtocolContract.sol";
import {UpgradeRegressionManagerHandler} from "test/handlers/UpgradeRegressionManager.handler.sol";
import {ITimelockTarget} from "src/interfaces/ITimelockTarget.sol";

contract UpgradeRegressionManagerInvariantTest is Test {
  UpgradeRegressionManager public urm;
  MockTimelockTarget public timelockTarget;
  FakeProtocolContract public target;
  UpgradeRegressionManagerHandler public handler;

  address public admin = makeAddr("admin");
  address public guardian = makeAddr("guardian");

  function setUp() public {
    timelockTarget = new MockTimelockTarget();
    timelockTarget.setDelay(5 seconds);

    target = new FakeProtocolContract(admin);

    urm = new UpgradeRegressionManager(ITimelockTarget(timelockTarget), admin, guardian, 5 seconds);

    handler = new UpgradeRegressionManagerHandler(urm, admin, guardian, target);

    // target the handler for invariant testing
    targetContract(address(handler));
  }

  /*///////////////////////////////////////////////////////////////
                        Rollback State Invariant
  //////////////////////////////////////////////////////////////*/

  /// @notice A rollback cannot be in both proposed and queued states simultaneously
  /// @dev Ensures proper state transitions
  function invariant_proposedAndQueuedMutualExclusion() public view {
    uint256 _randomIndex = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao)));
    uint256 _rollbackId = handler.getRandomRollbackId(_randomIndex);

    bool isProposed = urm.rollbackQueueExpiresAt(_rollbackId) != 0;
    bool isQueued = urm.rollbackExecutableAt(_rollbackId) != 0;

    // A rollback can be proposed OR queued, but not both
    assertFalse(isProposed && isQueued, "Rollback cannot be both proposed and queued");
  }

  /*///////////////////////////////////////////////////////////////
                        Timing Invariant
  //////////////////////////////////////////////////////////////*/

  /// @notice When a rollback is queued, its ETA must be in the future (unless time has been warped)
  /// @dev Ensures proper timing for execution
  function invariant_etaInFutureAfterQueue() public view {
    uint256 _randomIndex = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao)));
    uint256 _rollbackId = handler.getRandomExecutableRollbackId(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);
    uint256 _currentTime = block.timestamp;

    // If ETA is set, it should either be in the future OR we should have warped past it
    // (which means the rollback is ready to execute)
    assertTrue(
      _eta > _currentTime || urm.isRollbackReadyToExecute(_rollbackId),
      "Rollback ETA must be in the future unless ready to execute"
    );
  }

  /// @notice If a rollback has expired from queue, it should not be executable
  /// @dev Enforces queue window constraints
  function invariant_expiredRollbackNotExecutable() public {
    uint256 _randomIndex = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao)));
    uint256 _rollbackId = handler.expireRollback(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);

    // If rollback has expired from queue, it should not be executable
    assertEq(_eta, 0, "Expired rollback should not be executable");
  }

  /// @notice If a rollback is executable, its ETA must have been reached
  /// @dev Enforces execution timing constraints
  function invariant_executableRollbackEtaReached() public {
    uint256 _randomIndex = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao)));
    uint256 _rollbackId = handler.makeRollbackExecutable(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }
    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);
    // After makeRollbackExecutable, block.timestamp >= _eta must always hold
    assertGe(block.timestamp, _eta, "Executable rollback ETA must have been reached");
  }

  /// @notice A rollback that has passed its ETA should be ready to execute
  /// @dev Ensures execution readiness after timelock delay
  function invariant_executableRollbackIsReady() public {
    uint256 _randomIndex = uint256(keccak256(abi.encode(block.timestamp, block.prevrandao)));
    uint256 _rollbackId = handler.makeRollbackExecutable(_randomIndex);
    if (_rollbackId == 0) {
      return;
    }

    // After warping past ETA, the rollback should be ready to execute
    assertTrue(urm.isRollbackReadyToExecute(_rollbackId), "Executable rollback should be ready to execute");
  }
}
