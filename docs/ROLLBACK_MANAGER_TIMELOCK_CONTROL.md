# OpenZeppelin Governance Rollback Manager Implementation

This document describes the OpenZeppelin-specific implementation of the Rollback Manager for DAOs using OpenZeppelin Governor systems.

## Overview

For DAOs using OpenZeppelin Governor systems, the Rollback Manager integrates directly with the existing multi-executor timelock infrastructure. This upgrade path is simpler than the Compound version: since OpenZeppelin Governor already supports multiple executors, there's no need to deploy a shim.

## Architecture

### Before Architecture

#### Original Production Flow (Without Rollback System)

```mermaid
sequenceDiagram
    participant P as Proposer
    participant G as Governor
    participant T as Timelock
    participant C as Target Contracts

    %% Initial Proposal
    P->>G: Propose change
    Note over G: Voting period begins
    Note over G: Quorum reached
    G->>T: Queue for execution
    Note over T: Timelock delay (days/weeks)
    T->>C: Execute change

    Note over C: Bug discovered!

    %% Emergency Fix (Same slow process)
    P->>G: Propose emergency fix
    Note over G: Voting period begins
    Note over G: Quorum reached
    G->>T: Queue for execution
    Note over T: Timelock delay (days/weeks)
    T->>C: Execute emergency fix
```

**Problems with Current Architecture:**
- No emergency rollback mechanism
- Rollback requires full governance cycle (days/weeks)

### After Architecture

#### New Production Flow (With Rollback System)

```mermaid
sequenceDiagram
    participant * as User
    participant G as Governor
    participant T as Timelock
    participant U as Rollback Manager
    participant C as Target Contracts
    participant GN as Guardian

    %% Initial Proposal with Rollback
    *->>G: Propose change with rollback
    Note over G: Voting period begins
    Note over G: Quorum reached
    *->>G: Queue Proposal
    G->>T: Queue Proposal
    Note over T: Timelock delay (days/weeks)
    *->>G: Execute Proposal
    G->>T: Execute Proposal
    T->>C: Transactions executed
    T->>U: Propose rollback to Rollback Manager

    Note over C: Bug discovered!

    %% Emergency Rollback (Fast response)
    Note over GN: Before rollback expiry
    GN->>U: Guardian queues rollback
    U->>T: Queue rollback
    Note over GN: After Timelock delay
    GN->>U: Guardian executes rollback
    U->>T: Execute rollback fix
    T->>C: Rollback Transactions executed

    Note over C: Rollback Executed!
```

**Benefits of New Architecture:**
- Emergency rollback capability with Guardian
- Conditional rollback execution within time windows
- Maintains existing governance security model
- Backward compatible with existing tooling
- **Rollbacks are proposed as part of governance proposals via double encoding**

## Actors

### Governance Actors

1. **Governor** - The governance contract that proposes and executes governance proposals
2. **Timelock** - The existing OpenZeppelin TimelockController that enforces delays on governance actions
3. **Proposers** - DAO members who create governance proposals

### Rollback Manager Actors

1. **Guardian** - An address granted emergency capabilities for managing rollback transactions, including queuing, cancellation, and execution.
2. **Admin** - The address responsible for submitting rollback proposals to the Rollback Manager. In the context of this system, the OpenZeppelin TimelockController assumes this role.
3. **Target Contract** - The contract that is the recipient of rollback transactions, which can be queued, executed, or cancelled.

## System Components

### Rollback Manager

* [Rollback Manager Interface](../src/interfaces/IRollbackManager.sol)
* [Rollback Manager Core Implementation](../src/RollbackManager.sol)
* [OpenZeppelin Manager](../src/RollbackManagerTimelockControl.sol)

The core contract that manages the lifecycle of rollback proposals.

**Key Features:**
- Propose rollback transactions with queueing expiration windows
- Queue rollback transactions for execution
- Execute or cancel queued rollbacks
- Guardian-controlled emergency execution
- Configurable queueing windows

**Security Model:**
- Only admin can propose rollbacks and manage settings
- Only guardian and admin can queue/execute/cancel rollbacks
- Queue windows prevent indefinite rollback availability
- Respects OpenZeppelin TimelockController delays to prevent immediate execution

## Deployment Process

1. **Deploy Rollback Manager**
Deploy the `RollbackManager` with `RollbackManagerTimelockControl` contract.

2. **Configure Rollback Manager**
Set the Rollback Manager as an executor in the existing OpenZeppelin TimelockController.

3. **Grant Guardian Role**
   Grant the guardian role to the designated emergency address.

## OZ-Specific Considerations

### Multi-Executor Support

Unlike the Compound implementation, OpenZeppelin Governor systems already support multiple executors, so no shim is required. The Rollback Manager can be added directly as an executor to the existing TimelockController.

### TimelockController Integration

The OpenZeppelin implementation leverages the existing TimelockController's multi-executor capabilities, making the integration simpler and more straightforward than the Compound version.

### Deployment Scripts

* [Deploy Rollback Manager](../script/1_DeployRollbackManagerTimelockControl.s.sol)
* [Grant Roles to Rollback Manager](../script/2_GrantRolesToRollbackManagerTimelockControl.s.sol)

## Testing

The OpenZeppelin implementation includes comprehensive testing:

* [Integration Tests](../test/RollbackManagerTimelockControlDeployment.integration.t.sol)
* [Unit Tests](../test/RollbackManagerTimelockControl.unit.t.sol) 