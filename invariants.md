# Invariant Testing Documentation

This document outlines the key invariants identified for the `TimelockMultiAdminShim` and `UpgradeRegressionManager` contracts. Each invariant includes a rationale and a corresponding test function name.

---

## 🧱 Contract: TimelockMultiAdminShim  
**Total Invariants: 0**

### Purpose

Wraps a Compound Timelock to add:
- A mutable `admin`
- Support for multiple `executor`s
- Controlled access for queueing and executing transactions

**No variants identified which are not already handled by unit testing**
---

## 🧱 Contract: UpgradeRegressionManager  
**Total Invariants: 5**

### Purpose

Manages multi-phase rollback flow:
1. Admin proposes rollback
2. Guardian queues it for execution (before expiry)
3. Guardian executes or cancels it (after ETA)

### ✅ Core Invariants

#### **Rollback State Invariants**

1. **Rollback State Mutual Exclusion**  
   - **Property**: A rollback cannot exist in both `rollbackQueueExpiresAt` and `rollbackExecutableAt` simultaneously  
   - **Rationale**: Ensures rollback is in exactly one state at a time  
   - **Test**: `invariant_rollbackStateMutualExclusion()`


#### **Timing Invariants**

2. **Queue Window Positive**  
   - **Property**: `rollbackQueueWindow` must always be greater than 0  
   - **Rationale**: Ensures valid queue window for rollbacks  
   - **Test**: `invariant_rollbackQueueWindowPositive()`

3. **ETA In Future After Queue**  
   - **Property**: When a rollback is queued, its ETA must be in the future  
   - **Rationale**: Ensures proper timing for execution  
   - **Test**: `invariant_etaInFutureAfterQueue()`

4. **Queue Fails After Expiry**  
   - **Property**: Cannot queue a rollback after its `rollbackQueueExpiresAt` has passed  
   - **Rationale**: Enforces queue window constraints  
   - **Test**: `invariant_queueFailsAfterExpiry()`

5. **Execute Fails Before ETA**  
   - **Property**: Cannot execute a rollback before its `rollbackExecutableAt` has been reached  
   - **Rationale**: Enforces execution timing constraints  
   - **Test**: `invariant_executeFailsBeforeEta()`