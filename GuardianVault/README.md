# Guardian Vault

A decentralized social recovery wallet system built with Clarity smart contracts that enables secure wallet recovery through trusted guardians.

## Overview

Guardian Vault solves the critical problem of wallet recovery in the event of lost private keys. By leveraging a network of trusted guardians, users can regain access to their funds through a secure, threshold-based voting mechanism without compromising security.

## Features

- **Multi-Guardian Support**: Configure 2-10 trusted guardians per wallet
- **Threshold Voting**: Customizable recovery threshold (minimum guardian votes required)
- **Time-Limited Recovery**: 24-hour window for recovery completion
- **Fund Management**: Secure deposit and withdrawal functions
- **Owner Controls**: Cancel recovery attempts and manage wallet settings
- **Transparent Process**: All recovery attempts recorded on-chain

## Quick Start

### Creating a Wallet

```clarity
;; Create wallet with 3 guardians, requiring 2 votes for recovery
(contract-call? .guardian-vault create-wallet 
  (list 'SP1... 'SP2... 'SP3...) 
  u2)
```

### Initiating Recovery

```clarity
;; Guardian initiates recovery for new owner
(contract-call? .guardian-vault initiate-recovery u1 'SP-NEW-OWNER...)
```

### Voting on Recovery

```clarity
;; Other guardians vote to approve recovery
(contract-call? .guardian-vault vote-recovery u1)
```

## Core Functions

| Function | Access | Description |
|----------|--------|-------------|
| `create-wallet` | Public | Create new wallet with guardians |
| `deposit` | Owner | Add funds to wallet |
| `withdraw` | Owner | Remove funds from wallet |
| `initiate-recovery` | Guardian | Start recovery process |
| `vote-recovery` | Guardian | Vote on pending recovery |
| `cancel-recovery` | Owner | Cancel ongoing recovery |

## Security Features

- **Anti-Replay Protection**: Prevents duplicate voting
- **Guardian Verification**: Only designated guardians can participate
- **Timeout Mechanism**: Recovery requests expire after 24 hours
- **Owner Override**: Original owner maintains control during disputes

## Error Codes

- `u401` - Unauthorized access
- `u404` - Wallet not found
- `u400` - Invalid guardian configuration
- `u402` - Insufficient guardians
- `u403` - Recovery already active
- `u405` - No active recovery found
- `u406` - Already voted

## Use Cases

- **Personal Wallets**: Individual users securing personal funds
- **Family Accounts**: Joint accounts with family member guardians
- **Business Wallets**: Corporate accounts with employee/partner guardians
- **DAO Treasuries**: Decentralized organization fund management

## Testing

The contract includes comprehensive error handling and validation. Test all edge cases including:
- Invalid guardian counts and thresholds
- Unauthorized access attempts
- Recovery timeout scenarios
- Duplicate voting attempts