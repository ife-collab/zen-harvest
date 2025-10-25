# ZenHarvest Smart Contract Documentation

A decentralized autonomous scheduling infrastructure built on Stacks blockchain using Clarity smart contracts.

## Overview

This contract enables dApps to execute time-based operations with economic incentives through a validator marketplace. Tasks are scheduled at specific block heights, and validators stake STX tokens to guarantee execution.

## Features

- ✅ **Task Scheduling**: Create tasks to execute at future block heights
- ✅ **Validator Staking**: Validators stake STX to participate in task execution
- ✅ **Economic Incentives**: Executors earn rewards (110% of task stake)
- ✅ **Reputation System**: Track validator performance
- ✅ **Task Management**: Create, assign, execute, and cancel tasks
- ✅ **Stake Management**: Validators can stake and withdraw tokens

## Contract Functions

### Read-Only Functions

#### `get-task (task-id uint)`
Retrieves task details by ID.

**Returns:** Task information including creator, executor, target block, stake amount, and execution status.

#### `get-validator-stake (validator principal)`
Gets validator's staking information.

**Returns:** Total stake, active tasks count, and reputation score.

#### `get-task-assignment (task-id uint)`
Gets the validator assigned to a task.

**Returns:** Validator principal and assignment block height.

#### `get-task-counter`
Returns the total number of tasks created.

#### `get-total-staked`
Returns the total amount of STX staked in the contract.

#### `is-task-ready (task-id uint)`
Checks if a task is ready for execution (target block reached).

**Returns:** `true` if current block >= target block.

### Public Functions

#### `create-task (target-block uint) (task-data (string-utf8 256)) (stake-amount uint)`
Creates a new scheduled task.

**Parameters:**
- `target-block`: Block height when task should execute
- `task-data`: UTF-8 string description of the task (max 256 chars)
- `stake-amount`: STX amount to stake (minimum 1 STX)

**Requirements:**
- Stake amount >= 1 STX (1,000,000 microSTX)
- Target block must be in the future

**Returns:** Task ID

#### `stake-as-validator (amount uint)`
Allows users to become validators by staking STX.

**Parameters:**
- `amount`: STX amount to stake (minimum 1 STX)

**Requirements:**
- Minimum stake of 1 STX

**Returns:** `true` on success

#### `assign-task (task-id uint) (validator principal)`
Assigns a validator to execute a task.

**Parameters:**
- `task-id`: ID of the task to assign
- `validator`: Principal address of the validator

**Requirements:**
- Must be called by task creator
- Validator must have sufficient stake
- Task must not be executed

**Returns:** `true` on success

#### `execute-task (task-id uint)`
Executes a scheduled task and distributes rewards.

**Parameters:**
- `task-id`: ID of the task to execute

**Requirements:**
- Must be called by assigned validator
- Target block height must be reached
- Task must not be already executed

**Returns:** Reward amount (110% of stake)

**Effects:**
- Transfers reward to executor
- Updates validator reputation (+10 points)
- Marks task as executed

#### `withdraw-stake (amount uint)`
Allows validators to withdraw their stake.

**Parameters:**
- `amount`: Amount of STX to withdraw

**Requirements:**
- Validator must have no active tasks
- Sufficient stake balance

**Returns:** `true` on success

#### `cancel-task (task-id uint)`
Cancels a scheduled task and refunds the stake.

**Parameters:**
- `task-id`: ID of the task to cancel

**Requirements:**
- Must be called by task creator
- Task must not be executed

**Returns:** `true` on success

**Effects:**
- Refunds stake to creator
- Marks task as executed (cancelled)

## Usage Examples

### Example 1: Creating a Scheduled Task

```clarity
;; Schedule a task to execute at block 1000
;; Stake 2 STX (2,000,000 microSTX)
(contract-call? .zenharvest create-task 
    u1000 
    u"Rebalance portfolio" 
    u2000000)
```

### Example 2: Becoming a Validator

```clarity
;; Stake 10 STX to become a validator
(contract-call? .zenharvest stake-as-validator u10000000)
```

### Example 3: Assigning a Validator to a Task

```clarity
;; Assign validator to task #1
(contract-call? .zenharvest assign-task 
    u1 
    'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Example 4: Executing a Task

```clarity
;; Execute task #1 (must be called by assigned validator)
(contract-call? .zenharvest execute-task u1)
```

### Example 5: Checking Task Status

```clarity
;; Get task details
(contract-call? .zenharvest get-task u1)

;; Check if task is ready
(contract-call? .zenharvest is-task-ready u1)
```

### Example 6: Withdrawing Stake

```clarity
;; Withdraw 5 STX from validator stake
(contract-call? .zenharvest withdraw-stake u5000000)
```

## Error Codes

| Code | Name | Description |
|------|------|-------------|
| u100 | err-owner-only | Operation restricted to contract owner |
| u101 | err-not-found | Task or validator not found |
| u102 | err-unauthorized | Caller not authorized for this operation |
| u103 | err-insufficient-stake | Stake amount below minimum requirement |
| u104 | err-task-already-exists | Task ID already exists |
| u105 | err-task-not-ready | Target block height not yet reached |
| u106 | err-invalid-block-height | Invalid block height specified |
| u107 | err-task-already-executed | Task has already been executed |

## Economic Model

### Staking Requirements
- **Minimum Stake**: 1 STX (1,000,000 microSTX)
- **Per-Task Stake**: Creator-defined (minimum 1 STX)
- **Validator Stake**: Minimum 1 STX to participate

### Rewards
- **Executor Reward**: 110% of task stake amount
- **Reward Breakdown**: Original stake + 10% bonus
- **Reputation Bonus**: +10 points per successful execution

### Reputation System
- **Starting Score**: 100 points
- **Per Execution**: +10 points
- **Future Use**: Higher reputation could unlock premium features

## Workflow

### Task Lifecycle

1. **Creation**: Task creator stakes STX and specifies target block
2. **Assignment**: Creator assigns a validator to the task
3. **Waiting**: Task waits until target block height is reached
4. **Execution**: Validator executes task and receives reward
5. **Completion**: Stake is released, reputation updated

### Visual Workflow

```
[Creator] --stake--> [Create Task] ---> [Task Created]
                                              |
                                              v
[Validator] --stake--> [Become Validator] --> [Validator Active]
                                              |
                                              v
[Creator] --assign--> [Task Assignment] ---> [Task Assigned]
                                              |
                                              v
                                     [Wait for Target Block]
                                              |
                                              v
[Validator] --execute--> [Execute Task] ---> [Reward Distributed]
                                              |
                                              v
                                        [Task Complete]
```

## Use Cases

1. **DeFi Portfolio Rebalancing**: Automatically rebalance portfolios at specific times
2. **Recurring Payments**: Schedule periodic payment distributions
3. **Time-locked Releases**: Release tokens or NFTs at predetermined blocks
4. **Governance Execution**: Execute approved governance proposals at scheduled times
5. **Subscription Management**: Handle recurring subscription renewals
6. **NFT Reveals**: Schedule NFT metadata reveals
7. **Yield Harvesting**: Automate DeFi yield collection strategies

## Security Considerations

- ✅ Stake is held in contract until execution or cancellation
- ✅ Only assigned validators can execute tasks
- ✅ Tasks can only be executed once
- ✅ Creators can cancel tasks before execution
- ✅ Validators must have active stake to participate
- ✅ Validators can only withdraw stake when no active tasks

## Testing Checklist

- [ ] Create task with valid parameters
- [ ] Create task with insufficient stake (should fail)
- [ ] Create task with past block height (should fail)
- [ ] Stake as validator
- [ ] Assign validator to task
- [ ] Attempt to execute task before target block (should fail)
- [ ] Execute task at/after target block
- [ ] Verify reward distribution
- [ ] Verify reputation update
- [ ] Cancel task before execution
- [ ] Attempt to cancel executed task (should fail)
- [ ] Withdraw stake with active tasks (should fail)
- [ ] Withdraw stake with no active tasks

## Deployment

### Using Clarinet

1. Add contract to your Clarinet project:
```bash
clarinet contract new zenharvest
```

2. Copy the contract code to `contracts/zenharvest.clar`

3. Test the contract:
```bash
clarinet test
```

4. Deploy to testnet:
```bash
clarinet deploy --testnet
```

### Using Hiro Platform

1. Upload `zenharvest.clar` to Hiro Platform
2. Deploy to testnet or mainnet
3. Verify contract deployment

## Future Enhancements

- [ ] Cross-chain task execution via bridges
- [ ] Oracle integration for external data triggers
- [ ] Gas-efficient batching with merkle trees
- [ ] Slashing mechanism for validator misbehavior
- [ ] Complex condition triggers (beyond block height)
- [ ] Automatic rescheduling for failed tasks
- [ ] Fee distribution to protocol treasury
- [ ] Governance token for protocol decisions

## License

MIT License - See LICENSE file for details

## Support

For issues, questions, or contributions, please visit the project repository or contact the development team.

---

**Built with ❤️ for the Stacks ecosystem**
