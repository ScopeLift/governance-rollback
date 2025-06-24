# Invariant Testing Documentation

This document outlines the key invariants identified for the `TimelockMultiAdminShim` and `UpgradeRegressionManager` contracts. Each invariant includes a rationale and a corresponding test function name.

---

## 🧱 Contract: TimelockMultiAdminShim  
**Total Invariants: 7**

### Purpose

Wraps a Compound Timelock to add:
- A mutable `admin`
- Support for multiple `executor`s
- Controlled access for queueing and executing transactions

### ✅ Core Invariants

#### **Authorization Invariants**

1. **Admin Never Zero**  
   - **Property**: `admin` must never be `address(0)`  
   - **Rationale**: Admin is critical for contract management and authorization  
   - **Test**: `invariant_adminNeverZero()`

2. **Only Timelock Can Manage Executors**  
   - **Property**: Only `TIMELOCK` can call `addExecutor()`, `removeExecutor()`, `setAdmin()`  
   - **Rationale**: Prevents unauthorized changes to authorization structure  
   - **Test**: `invariant_onlyTimelockCanManageExecutors()`

3. **Only Admin Can Queue Internal Calls**  
   - **Property**: Only `admin` can queue transactions targeting `address(this)`  
   - **Rationale**: Prevents unauthorized configuration changes  
   - **Test**: `invariant_onlyAdminCanQueueInternalCalls()`

4. **Admin or Executor Can Queue External Calls**  
   - **Property**: Only `admin` or authorized `executor` can queue transactions targeting external contracts  
   - **Rationale**: Maintains controlled access to external operations  
   - **Test**: `invariant_adminOrExecutorCanQueueExternalCalls()`

5. **Admin or Executor Can Cancel/Execute**  
   - **Property**: Only `admin` or authorized `executor` can cancel or execute transactions  
   - **Rationale**: Maintains controlled access to transaction lifecycle  
   - **Test**: `invariant_adminOrExecutorCanCancelExecute()`

#### **State Consistency Invariants**

6. **Executor State Consistency**  
   - **Property**: `isExecutor` mapping must be consistent with actual executor status  
   - **Rationale**: Ensures authorization state is accurate  
   - **Test**: `invariant_executorStateConsistency()`

---

## 🧱 Contract: UpgradeRegressionManager  
**Total Invariants: 13**

### Purpose

Manages multi-phase rollback flow:
1. Admin proposes rollback
2. Guardian queues it for execution (before expiry)
3. Guardian executes or cancels it (after ETA)

### ✅ Core Invariants

#### **Authorization Invariants**

1. **Guardian Never Zero**  
   - **Property**: `guardian` must never be `address(0)`  
   - **Rationale**: Guardian is required for rollback operations  
   - **Test**: `invariant_guardianNeverZero()`

2. **Only Admin Can Propose**  
   - **Property**: Only `ADMIN` can call `propose()`  
   - **Rationale**: Maintains controlled rollback proposal  
   - **Test**: `invariant_onlyAdminCanPropose()`

3. **Only Guardian Can Queue/Cancel/Execute**  
   - **Property**: Only `guardian` can call `queue()`, `cancel()`, `execute()`  
   - **Rationale**: Maintains controlled rollback lifecycle  
   - **Test**: `invariant_onlyGuardianCanQueueCancelExecute()`

#### **Rollback State Invariants**

4. **Rollback State Mutual Exclusion**  
   - **Property**: A rollback cannot exist in both `rollbackQueueExpiresAt` and `rollbackExecutableAt` simultaneously  
   - **Rationale**: Ensures rollback is in exactly one state at a time  
   - **Test**: `invariant_rollbackStateMutualExclusion()`

5. **Rollbacks Cleared On Cancel/Execute**  
   - **Property**: After `cancel()` or `execute()`, both mappings for that rollbackId must be cleared  
   - **Rationale**: Prevents rollback from being reused  
   - **Test**: `invariant_rollbacksClearedOnCancelOrExecute()`

6. **Cannot Propose Same Rollback Twice**  
   - **Property**: Cannot propose a rollback that already exists in either mapping  
   - **Rationale**: Prevents duplicate rollback proposals  
   - **Test**: `invariant_cannotProposeSameRollbackTwice()`

7. **Cannot Execute/Cancel Rollback Twice**  
   - **Property**: Cannot `execute()` or `cancel()` a rollback that has already been executed or cancelled  
   - **Rationale**: Prevents double execution/cancellation of the same rollback  
   - **Test**: `invariant_cannotExecuteCancelRollbackTwice()`

#### **Timing Invariants**

8. **Queue Window Positive**  
   - **Property**: `rollbackQueueWindow` must always be greater than 0  
   - **Rationale**: Ensures valid queue window for rollbacks  
   - **Test**: `invariant_rollbackQueueWindowPositive()`

9. **ETA In Future After Queue**  
   - **Property**: When a rollback is queued, its ETA must be in the future  
   - **Rationale**: Ensures proper timing for execution  
   - **Test**: `invariant_etaInFutureAfterQueue()`

10. **Queue Fails After Expiry**  
   - **Property**: Cannot queue a rollback after its `rollbackQueueExpiresAt` has passed  
   - **Rationale**: Enforces queue window constraints  
   - **Test**: `invariant_queueFailsAfterExpiry()`

11. **Execute Fails Before ETA**  
   - **Property**: Cannot execute a rollback before its `rollbackExecutableAt` has been reached  
   - **Rationale**: Enforces execution timing constraints  
   - **Test**: `invariant_executeFailsBeforeEta()`