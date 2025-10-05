# Token Airdrop Distribution Smart Contract

## Overview

This Clarity smart contract implements a secure and flexible token airdrop distribution system with multi-tier rewards, whitelist management, and comprehensive administrative controls. The contract enables controlled distribution of fungible tokens to eligible recipients while maintaining complete audit trails and security features.

## Features

### Core Functionality
- Whitelist-based token distribution system
- Multi-tier reward structure (Bronze, Silver, Gold, Platinum)
- Pausable distribution mechanism
- Batch processing for efficient recipient management
- Automatic overflow protection for mathematical operations
- Comprehensive event logging for audit trails
- Token reclaim mechanism after lockup period

### Administrative Controls
- Ownership transfer capability
- Distribution pause/resume toggle
- Tier system activation/deactivation
- Configurable reward amounts per tier
- Adjustable lockup periods
- Batch recipient management (up to 50 recipients)

## Token Information

**Fungible Token**: `reward-token`
**Initial Supply**: 1,000,000,000 tokens

## Tier Structure

The contract supports four reward tiers:

- **Tier 1 (Bronze)**: Default tier, base reward amount
- **Tier 2 (Silver)**: Enhanced reward level
- **Tier 3 (Gold)**: Premium reward level
- **Tier 4 (Platinum)**: Maximum reward level

Default reward amounts:
- Bronze: 100 tokens
- Silver: 250 tokens
- Gold: 500 tokens
- Platinum: 1,000 tokens

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | ERR-UNAUTHORIZED-ACCESS | Caller is not authorized |
| u101 | ERR-DUPLICATE-CLAIM-ATTEMPT | Recipient already claimed |
| u102 | ERR-RECIPIENT-NOT-ELIGIBLE | Recipient not whitelisted |
| u103 | ERR-INSUFFICIENT-TOKEN-BALANCE | Insufficient tokens for distribution |
| u104 | ERR-DISTRIBUTION-CURRENTLY-PAUSED | Distribution is paused |
| u105 | ERR-INVALID-REWARD-AMOUNT | Invalid reward amount provided |
| u106 | ERR-PREMATURE-RECLAIM-ATTEMPT | Lockup period not expired |
| u107 | ERR-RECIPIENT-ALREADY-WHITELISTED | Recipient already exists |
| u108 | ERR-INVALID-TIME-PERIOD | Invalid time period specified |
| u109 | ERR-MATHEMATICAL-OVERFLOW-DETECTED | Overflow in calculation |
| u110 | ERR-ZERO-AMOUNT-PROVIDED | Zero amount not allowed |
| u111 | ERR-TOKEN-MINTING-FAILURE | Token minting failed |
| u112 | ERR-INVALID-PRINCIPAL-ADDRESS | Invalid principal address |
| u113 | ERR-INVALID-TIER-LEVEL | Tier level out of range |
| u114 | ERR-TIER-ALREADY-SET | Tier already assigned |

## Public Functions

### Administrative Functions

#### transfer-ownership
```clarity
(transfer-ownership (new-owner principal))
```
Transfers contract ownership to a new administrator.

**Requirements**:
- Caller must be current owner
- New owner must be a valid principal
- New owner cannot be current owner

#### pause-or-resume-distribution
```clarity
(pause-or-resume-distribution)
```
Toggles the distribution state between active and paused.

**Requirements**:
- Caller must be owner

#### activate-or-deactivate-tiers
```clarity
(activate-or-deactivate-tiers)
```
Enables or disables the multi-tier reward system.

**Requirements**:
- Caller must be owner

#### set-tier-rewards
```clarity
(set-tier-rewards (bronze uint) (silver uint) (gold uint) (platinum uint))
```
Sets reward amounts for all four tier levels.

**Requirements**:
- Caller must be owner
- All amounts must be greater than zero

#### set-base-reward
```clarity
(set-base-reward (new-amount uint))
```
Updates the base reward amount for non-tiered distributions.

**Requirements**:
- Caller must be owner
- Amount must be greater than zero

#### set-lockup-period
```clarity
(set-lockup-period (blocks uint))
```
Configures the lockup period in blocks before tokens can be reclaimed.

**Requirements**:
- Caller must be owner
- Period must be greater than zero

### Recipient Management

#### add-recipient
```clarity
(add-recipient (recipient principal))
```
Adds a single recipient to the whitelist without tier assignment.

**Requirements**:
- Caller must be owner
- Recipient must be valid principal
- Recipient not already whitelisted

#### add-recipient-with-tier
```clarity
(add-recipient-with-tier (recipient principal) (tier uint))
```
Adds a recipient with a specific tier assignment.

**Requirements**:
- Caller must be owner
- Valid principal and tier level (1-4)
- Recipient not already whitelisted

#### modify-recipient-tier
```clarity
(modify-recipient-tier (recipient principal) (new-tier uint))
```
Changes the tier level of an existing recipient.

**Requirements**:
- Caller must be owner
- Recipient must be whitelisted
- Recipient must not have claimed tokens
- Valid tier level (1-4)

#### remove-recipient
```clarity
(remove-recipient (recipient principal))
```
Removes a recipient from the whitelist and clears tier assignment.

**Requirements**:
- Caller must be owner
- Recipient must be whitelisted

#### batch-add-recipients
```clarity
(batch-add-recipients (recipients (list 50 principal)))
```
Adds multiple recipients to the whitelist (up to 50).

**Requirements**:
- Caller must be owner

#### batch-add-with-tiers
```clarity
(batch-add-with-tiers (recipient-list (list 25 {recipient: principal, tier: uint})))
```
Adds multiple recipients with tier assignments (up to 25).

**Requirements**:
- Caller must be owner

### Token Distribution

#### claim-tokens
```clarity
(claim-tokens)
```
Allows eligible recipients to claim their airdrop tokens.

**Requirements**:
- Distribution must be active
- Caller must be whitelisted
- Caller must not have already claimed
- Sufficient token balance available

**Returns**: Amount of tokens claimed

#### reclaim-unclaimed-tokens
```clarity
(reclaim-unclaimed-tokens (destination principal))
```
Allows owner to reclaim unclaimed tokens after lockup period.

**Requirements**:
- Caller must be owner
- Lockup period must have expired
- Valid destination principal
- Destination cannot be owner
- Remaining balance must be greater than zero

**Returns**: Amount of tokens reclaimed

## Read-Only Functions

### Contract State Queries

- `get-owner`: Returns current contract owner
- `is-distribution-active`: Checks if distribution is active
- `is-tier-system-active`: Checks if tier system is enabled
- `get-all-tier-rewards`: Returns reward amounts for all tiers
- `get-base-reward`: Returns current base reward amount
- `get-lockup-period`: Returns lockup period in blocks
- `get-deployment-block`: Returns deployment block height
- `get-total-distributed`: Returns total tokens distributed

### Recipient Queries

- `is-whitelisted (recipient principal)`: Checks if recipient is whitelisted
- `has-claimed (recipient principal)`: Checks if recipient has claimed
- `get-claimed-amount (recipient principal)`: Returns amount claimed by recipient
- `get-tier (recipient principal)`: Returns tier assignment for recipient
- `get-potential-reward (recipient principal)`: Calculates potential reward based on tier

### Event Logging

- `get-event (event-id uint)`: Retrieves event log details by ID

## Usage Examples

### Initial Setup

1. Deploy the contract (automatically mints 1 billion tokens)
2. Configure tier rewards (optional):
   ```clarity
   (contract-call? .airdrop set-tier-rewards u150 u300 u600 u1200)
   ```
3. Enable tier system (optional):
   ```clarity
   (contract-call? .airdrop activate-or-deactivate-tiers)
   ```

### Adding Recipients

Single recipient:
```clarity
(contract-call? .airdrop add-recipient-with-tier 'SP123... u3)
```

Batch add:
```clarity
(contract-call? .airdrop batch-add-recipients 
  (list 'SP123... 'SP456... 'SP789...))
```

### Claiming Tokens

Recipients call:
```clarity
(contract-call? .airdrop claim-tokens)
```

### Emergency Controls

Pause distribution:
```clarity
(contract-call? .airdrop pause-or-resume-distribution)
```

Reclaim after lockup:
```clarity
(contract-call? .airdrop reclaim-unclaimed-tokens 'SP-DESTINATION...)
```

## Security Features

1. **Access Control**: All administrative functions restricted to contract owner
2. **Validation**: Comprehensive input validation for all parameters
3. **Overflow Protection**: Safe arithmetic operations with overflow detection
4. **Duplicate Prevention**: Recipients cannot claim twice
5. **Pause Mechanism**: Emergency stop for distribution
6. **Lockup Period**: Time-locked reclaim mechanism
7. **Audit Trail**: Complete event logging for all major actions

## Default Configuration

- Base reward: 100 tokens
- Lockup period: 10,000 blocks
- Distribution: Active
- Tier system: Disabled
- Deployment block: Set at deployment time