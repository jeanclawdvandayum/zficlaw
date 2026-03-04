---
name: ethskills-building-blocks
description: DeFi legos and protocol composability on Ethereum. Major protocols (Uniswap, Aave, Compound, MakerDAO, Yearn, Curve), how they work, how to build on them, and how to combine them into novel products. Use when building DeFi integrations, designing tokenomics, or when a user wants to compose existing protocols.
metadata:
  source: "https://ethskills.com/building-blocks/SKILL.md"
---

# Building Blocks (DeFi Legos)

## What You Probably Got Wrong

**DeFi TVL:** Ethereum DeFi TVL is **$50B+** (Feb 2026).

**Uniswap V4:** V4 introduced a **hooks system** — custom logic attached to pools (dynamic fees, TWAMM, limit orders, custom oracles).

**Costs changed everything:** A flash loan arbitrage on mainnet costs ~$0.05-0.50 in gas now (was $5-50).

## Key Protocol Addresses (Verified Feb 2026)

| Protocol | Contract | Mainnet Address |
|----------|----------|-----------------|
| Uniswap V2 Router | Router | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Uniswap V3 Factory | Factory | `0x1F98431c8aD98523631AE4a59f267346ea31F984` |
| Uniswap V3 SwapRouter02 | Router | `0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45` |
| Uniswap Universal Router | Router | `0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD` |
| Aave V3 Pool | Pool | `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2` |

## Uniswap V4 Hooks

Hooks let you add custom logic that runs before/after swaps, liquidity changes, and donations.

**Hook use cases:**
- Dynamic fees — adjust based on volatility
- TWAMM — split large orders over time
- Limit orders — execute when price crosses threshold
- MEV protection — auction swap ordering rights
- Custom oracles — TWAP updated on every swap

## Composability Patterns

### Flash Loan Arbitrage
Borrow from Aave → swap on Uniswap for profit → repay Aave. All in one transaction. If unprofitable, reverts (lose only gas: ~$0.05-0.50).

### ERC-4626 Yield Vaults
Standard vault interface — the "ERC-20 of yield." Every vault exposes the same functions regardless of strategy.

### Flash Loan (Aave V3)
**Aave V3 Pool (mainnet):** `0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2`
**Flash loan fee:** 0.05% (5 basis points). Free if you repay to an Aave debt position.

## Guardrails for Composability

- Every protocol you compose with is a dependency
- Oracle manipulation = exploits. Verify oracle sources
- Impermanent loss is real for AMM LPs
- The interaction between two safe contracts can create unsafe behavior
- Start with small amounts
- Flash loan attacks can manipulate prices within a single transaction

## Discovery Resources

- **DeFi Llama:** https://defillama.com
- **Dune Analytics:** https://dune.com
- **ethereum.org/en/dapps/**
