# Bitcoin Options Trading Platform Smart Contract

A decentralized Bitcoin options trading platform built on Stacks L2 with sBTC settlement. Implements non-custodial options contracts with automated collateral management and oracle-based price feeds.

## Key Features

- **BTC Options Trading**: Create/exercise European-style CALL/PUT options
- **sBTC Integration**: Wrapped Bitcoin collateral management (ERC-20 compatible)
- **Oracle System**: Secure price feeds with validity window enforcement
- **Collateral Engine**: Dynamic collateral requirements (150%+ ratio)
- **Auto-Expiry**: Programmatic option settlement at expiration
- **Fee System**: Configurable platform fee (basis points)

## Architecture Overview

### Core Components

1. **Options Market**

   - CREATE ➞ EXERCISE/EXPIRE lifecycle
   - Strike prices denominated in sBTC
   - Block height-based expiration

2. **Collateral System**

   ```clarity
   Collateral = (Option Amount * Strike Price) * Collateral Ratio / 100
   ```

3. **Oracle Integration**

   - Price freshness validation
   - Admin-managed oracle address
   - Emergency stale price detection

4. **Fund Management**
   - sBTC deposit/withdrawal system
   - Segregated user balances
   - Locked collateral tracking

## Technical Specification

### Data Models

#### Option Contract

```clarity
{
    creator: principal,
    holder: principal,
    option-type: "CALL"|"PUT",
    strike-price: uint,       // sBTC per contract
    expiry: uint,             // Block height
    amount: uint,             // Contract size
    collateral: uint,         // Locked sBTC
    status: "ACTIVE"|"EXERCISED"|"EXPIRED"
}
```

#### User Balance

```clarity
{
    sbtc-balance: uint,       // Available balance
    locked-collateral: uint   // Collateral in use
}
```

### Key Functions

#### 1. Option Creation

```bash
clarinet contract call create-option \
  --type "CALL" \
  --strike-price 50000 \
  --expiry 14400 \
  --amount 1000000 \
  --sender wallet1
```

#### 2. Option Exercise

```clarity
(exercise-option u42)  // Option ID
```

#### 3. Oracle Management

```clarity
(update-btc-price u48500)  // $48,500 BTC price
```

### Security Model

#### Validation Checks

- Collateral sufficiency verification
- Price feed staleness detection
- Option expiration enforcement
- Principal authorization layers
- Parameter boundary checks

#### Risk Mitigations

```clarity
;; Collateral Safety Check
(asserts! (>= (get sbtc-balance user-balance) required-collateral)
          ERR_INSUFFICIENT_COLLATERAL)

;; Price Freshness Enforcement
(asserts! (< (- block-height last-updated) validity-window)
```

## Development Setup

### Prerequisites

- Clarinet 2.0+
- Node.js 16.x
- sBTC testnet tokens
