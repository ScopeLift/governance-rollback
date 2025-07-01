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

  /// @notice A rollback cannot exist in both `rollbackQueueExpiresAt` and `rollbackExecutableAt` simultaneously
  /// @dev Rationale: Ensures rollback is in exactly one state at a time
  function invariant_rollbackStateMutualExclusion() public view {
    uint256 rollbackId = handler.getRollbackId();

    bool inQueueingState = urm.rollbackQueueExpiresAt(rollbackId) != 0;
    bool inExecutionState = urm.rollbackExecutableAt(rollbackId) != 0;

    assertFalse(inQueueingState && inExecutionState, "Rollback cannot exist in both queueing and execution state");
  }

  /*///////////////////////////////////////////////////////////////
                        Timing Invariant
  //////////////////////////////////////////////////////////////*/

  /// @notice `rollbackQueueWindow` must always be greater than 0
  /// @dev Ensures valid queue window for rollbacks
  function invariant_rollbackQueueWindowPositive() public view {
    uint256 _rollbackQueueWindow = urm.rollbackQueueWindow();
    assertGt(_rollbackQueueWindow, 0, "Rollback queue window must be greater than 0");
  }

  /// @notice When a rollback is queued, its ETA must be in the future
  /// @dev Ensures proper timing for execution
  function invariant_etaInFutureAfterQueue() public view {
    uint256 _rollbackId = handler.getRollbackId();
    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);
    uint256 _currentTime = block.timestamp;

    // nothing to test — either not proposed or still within queue window
    if (_eta == 0) {
      return;
    }

    assertGt(_eta, _currentTime, "Rollback ETA must be in the future");
  }

  /// @notice Cannot queue a rollback after its `rollbackQueueExpiresAt` has passed
  /// @dev Enforces queue window constraints
  function invariant_queueFailsAfterExpiry() public {
    uint256 _rollbackId = handler.getRollbackId();
    uint256 _expiresAt = urm.rollbackQueueExpiresAt(_rollbackId);

    // nothing to test — either not proposed or still within queue window
    if (_expiresAt == 0 || block.timestamp < _expiresAt) {
      return;
    }

    try handler.queueRollback() {
      // If the call succeeds, check it didn't reinsert anything
      // We expect rollbackExecutableAt to still be 0
      uint256 _eta = urm.rollbackExecutableAt(_rollbackId);
      assertEq(_eta, 0, "Should not have been able to queue rollback after expiry");
    } catch {
      // revert is expected — test passes
    }
  }

  /// @notice Cannot execute a rollback before its `rollbackExecutableAt` has been reached
  /// @dev Enforces execution timing constraints
  function invariant_executeFailsBeforeEta() public {
    uint256 _rollbackId = handler.getRollbackId();
    uint256 _eta = urm.rollbackExecutableAt(_rollbackId);

    // nothing to test — either not proposed or still within queue window
    if (_eta == 0) {
      return;
    }

    // nothing to test - as eta has been reached
    if (block.timestamp >= _eta) {
      return;
    }

    try handler.executeRollback() {
      // If it does not revert, then rollbackExecutableAt should still be set (i.e., nothing executed)
      assertEq(urm.rollbackExecutableAt(_rollbackId), _eta, "Rollback should not be executable before ETA");
    } catch {
      // revert is expected — test passes
    }
  }
}
