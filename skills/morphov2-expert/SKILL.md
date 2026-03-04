---
name: morphov2-expert
description: Expert knowledge of Morpho Vault V2 protocol — architecture, adapters, cap system, roles, timelocks, security patterns, GraphQL API, and integration. Use when building on, auditing, curating, or querying Morpho Vault V2 contracts. Covers adapter development, risk curation (absolute/relative caps, id system), allocator operations, forceDeallocate/in-kind redemptions, gating, fee structure, and the GraphQL API at api.morpho.org. Also relevant for projects integrating with Morpho V2 vaults (e.g., as MYT yield source).
---

# Morpho Vault V2 Expert

## Architecture Overview

Morpho Vault V2 is a permissionless lending vault protocol built on top of Morpho Markets. Core design:

- **Immutable contracts** — no upgrades after deployment
- **Adapter model** — universal gateway to any yield source via pluggable adapters
- **ID & Cap system** — multi-dimensional risk curation on abstract identifiers
- **Role separation** — Owner / Curator / Allocator / Sentinel
- **Non-custodial** — guaranteed exits via `forceDeallocate` + timelocks
- **ERC-4626 compliant** (shares are ERC-20), but `maxDeposit/maxMint/maxWithdraw/maxRedeem` always return 0

### Key Contracts
- `VaultV2` — core vault, deployed via `VaultV2Factory`
- `MorphoMarketV1AdapterV2` — adapter for Morpho Market V1
- `MorphoVaultV1Adapter` — adapter wrapping a Morpho Vault V1
- Source: [github.com/morpho-org/vault-v2](https://github.com/morpho-org/vault-v2)

## Core Concepts

### 1. Adapters
Adapters are smart contracts that bridge the vault to external yield protocols. Each adapter:
- Receives assets via `allocate()`, executes supply logic on target protocol
- Reports current value via `realAssets()` — enables automatic interest accrual
- Can be added/removed by Curator (timelocked)
- Constrained by an optional **adapter registry** (can be abdicated for permanence)

**Liquidity adapter**: Optional dedicated adapter for deposits/withdrawals. Set by Allocator via `setLiquidityAdapterAndData()`. New deposits auto-forward here; withdrawals pull from it if idle insufficient.

### 2. ID & Cap System
Risk is curated via abstract **ids** — `id = keccak256(idData)` where `idData` encodes a risk factor.

**Cap types:**
- **Absolute cap** (`uint128`) — hard asset limit for an id
- **Relative cap** (`uint128`, scaled 1e18) — % of total assets. Only checked on allocation (can be exceeded by withdrawals)

**MorphoMarketV1AdapterV2 generates three id types:**
- Adapter: `keccak256(abi.encode("this", adapterAddress))`
- Collateral: `keccak256(abi.encode("collateralToken", collateralAddress))`
- Market: `keccak256(abi.encode("this/marketParams", adapterAddress, marketParams))`

**MorphoVaultV1Adapter**: Single id `keccak256(abi.encode("this", adapterAddress))`

### 3. Roles
| Role | Count | Key Powers |
|------|-------|------------|
| **Owner** | 1 | Set Curator, Sentinels, name/symbol. No fund control. |
| **Curator** | 1 | Adapters, caps, fees, gates, timelocks, allocators. Most actions timelocked. |
| **Allocator** | Many | Allocate/deallocate between adapters, set liquidity adapter, set maxRate. |
| **Sentinel** | Many | Deallocate, decrease caps, revoke pending actions. Risk-reduction only. |

### 4. Timelocks
- All Curator config changes timelockable (0–3 weeks), except `decreaseAbsoluteCap`/`decreaseRelativeCap` (instant)
- Process: Curator calls `submit(encodedCall)` → wait timelock → anyone calls function directly
- `increaseTimelock` is timelocked by its own current duration
- `decreaseTimelock(selector, duration)` timelocked by the target function's current timelock
- `abdicate(selector)` — permanently disables a timelocked action

### 5. Fees
- **Performance fee**: Up to 50% on yield
- **Management fee**: Up to 5%/year on principal
- Each has separate recipient, both set by Curator (timelocked)
- **maxRate**: Curator-set cap on how fast `totalAssets` can grow

### 6. Gates (Optional)
Four gate contracts for compliance/KYC:
- `receiveSharesGate`, `sendSharesGate` — control share transfers
- `receiveAssetsGate`, `sendAssetsGate` — control asset deposits/withdrawals
- All timelocked. Can be permanently disabled via `abdicate`.

### 7. forceDeallocate (In-Kind Redemptions)
Permissionless function — anyone can move assets from adapter → vault idle pool.
- Penalty up to 2% per adapter (set by Curator, timelocked)
- Enables guaranteed exits: flashloan → supply to adapter's market → forceDeallocate → withdraw → repay flashloan
- User gets direct position in underlying protocol

## Security Audit Considerations

For audit-specific patterns and common vulnerability classes, see [references/security-audit.md](references/security-audit.md).

## GraphQL API

For querying vault data, positions, APY, allocations, and transactions, see [references/graphql-api.md](references/graphql-api.md).

Endpoint: `https://api.morpho.org/graphql`

## Contract Function Reference

For complete function signatures, parameters, and role requirements, see [references/contract-functions.md](references/contract-functions.md).

## Integration Patterns

When building protocols that use Morpho V2 vaults as yield sources (e.g., Alchemix V3's MYT):

1. **Adapter interaction**: Your strategy contract calls `allocate(adapter, data, assets)` and `deallocate(adapter, data, assets)` via an allocator role
2. **Cap management**: Your curator contract manages `increaseAbsoluteCap`/`decreaseAbsoluteCap` via the timelocked `submit()` pattern
3. **Asset reporting**: Call `realAssets()` on adapters or `totalAssets()` on vault for current value
4. **Share accounting**: Vault is ERC-4626 — use `convertToShares`/`convertToAssets` for conversions
5. **Liquidity**: Ensure liquidity adapter is set for automatic deposit/withdrawal routing
6. **Emergency**: `forceDeallocate` is your escape hatch — design around it for worst-case liquidity
