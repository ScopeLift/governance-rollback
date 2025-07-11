# Compound Governance Upgrade Impact Analysis

> **⚠️ Important**: This document analyzes the impact of upgrading to the TimelockMultiAdminShim on existing governance proposals at various stages of their lifecycle.

## Overview

When the proposal to upgrade the DAO governance contracts goes live (adopting the TimelockMultiAdminShim), existing proposals may be at different stages of their lifecycle. This document analyzes how these proposals will be affected and provides integration tests to verify the expected behavior.

## Upgrade Architecture

The upgrade involves:

1. **Deploying:** 
    - `TimelockMultiAdminShim` (Shim) with  
      - `admin` = Governor
      - `timelock` = Compound Timelock
      - `executor` = URM
    - `URMCompoundManager` (URM) with 
       - `admin` = Compound Timelock
       - `guardian` = Compound trusted multisig
       - `target` = `TimelockMultiAdminShim`
2. **Proposal & Executing an Upgrade:** 
   - Set Governor's `timelock` to `TimelockMultiAdminShim`
   - Set Timelock’s `admin` to `TimelockMultiAdminShim`

After this, all `queue()`, `execute()`, `cancel()` calls go through the Shim — even for proposals queued before the upgrade.

## Lifecycle Scenarios

### 1. **Proposed but Not Yet Active**
- **State**: Proposal is created, still in proposal delay period
- **Effect**: **No Impact** ✅
- **Reason**: Shim is not involved until the queue() phase. Governor handles proposal lifecycle normally.

### 2. **Voting In Progress**
- **State**: Proposal is active and undergoing voting.
- **Effect**: **No Impact** ✅
- **Reason**: Voting is governed by the Governor, not the timelock. Shim is not involved yet.


### 3. **Succeeded but Not Yet Queued**
- **State**: Voting complete, proposal has succeeded, but queue() not yet called.
- **Effect**: **No Impact** ✅
- **Change**: queue() now routes through the Shim, which forwards to the Timelock with the same same proposal hash

### 4. **Queued Before Upgrade**
- **State**: Proposal was already queued in Timelock before the upgrade.
- **Effect**: **Compatible** ✅
- **Change**: execute() must now go through the Shim, since the Governor’s timelock is now the Shim.


### 5. **Queued After Upgrade**
- **State**: Proposal is queued after the upgrade and is still in the timelock delay
- **Effect**: **Expected behavior** ✅
- **Changes**: Both `queue()` and `execute()` go through Shim → Timelock.

## Integration Test Matrix

| Scenario                       | Proposal State | Action Pre-Upgrade  | Action Post-Upgrade | Shim Used? | Expected |
| ------------------------------ | -------------- | ------------------- | ------------------- | ---------- | -------- |
| Proposal not yet active        | `Pending`      | Governor only       | Governor            | ❌          | ✅ Works  |
| Proposal in voting             | `Active`       | Governor only       | Governor            | ❌          | ✅ Works  |
| Proposal succeeded, not queued | `Succeeded`    | Governor            | Governor → Shim     | ✅          | ✅ Works  |
| Proposal queued before upgrade | `Queued`       | Governor → Timelock | Governor → Shim     | ✅          | ✅ Works  |
| Proposal queued after upgrade  | `Queued`       | —                   | Governor → Shim     | ✅          | ✅ Works  |

These scenarios are covered in the integration test suite at [GovernanceUpgradeImpact.integration.t.sol](../test/GovernanceUpgradeImpact.integration.t.sol)

The governance upgrade to `TimelockMultiAdminShim` is designed to be fully **backward compatible**, ensuring that all existing proposals—regardless of their current stage—continue to function as expected.