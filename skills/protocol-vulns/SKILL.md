# Protocol Vulnerability Index — 460 Categories × 31 Protocol Types

Distilled from ~10,600 DeFi security audit findings. Use when auditing any smart contract protocol.

Source: `~/clawd/protocol-vulnerabilities-index/categories/`

## How to Use

1. **Identify the protocol type** you're auditing (see list below)
2. **Load ALL category files** for that type: `read ~/clawd/protocol-vulnerabilities-index/categories/<type>/<category>.md`
3. Each file contains: Preconditions, Vulnerable Patterns (annotated Solidity), Detection Heuristics, False Positives, Remediation
4. For protocols spanning multiple types (e.g., Alchemix = CDP + Lending + Yield), load categories from ALL relevant types
5. Cross-reference with `evmbench-exploits` skill for real exploit examples

## Quick Protocol Type Selector

**What does the protocol do?** → Load these categories:

| If the protocol... | Load type |
|---|---|
| Issues loans against collateral | `lending` (17) or `cdp` (21) |
| Issues synthetic assets / stablecoins | `synthetics` (22) or `algo-stables` (12) |
| Provides token swaps / AMM | `dexes` (19) |
| Aggregates yield across protocols | `yield-aggregator` (16) or `yield` (19) |
| Manages concentrated liquidity | `liquidity-manager` (17) |
| Provides liquid staking (LSTs) | `liquid-staking` (20) |
| Staking with rewards | `staking-pool` (21) |
| Leveraged yield farming | `leveraged-farming` (20) |
| Bridges assets cross-chain | `bridge` (18) or `cross-chain` (20) |
| NFT lending / collateral | `nft-lending` (13) |
| NFT marketplace / trading | `nft-marketplace` (19) |
| Options / structured products | `options-vault` (17) |
| Derivatives / perpetuals | `derivatives` (13) |
| Oracle / price feeds | `oracle` (12) |
| Token launch / IDO | `launchpad` (16) |
| Insurance / coverage | `insurance` (11) |
| Real-world assets | `rwa` (16) or `rwa-lending` (13) |
| Payments / streaming | `payments` (12) |
| Index funds / baskets | `indexes` (14) |
| Gaming / GameFi | `gaming` (12) |
| Privacy / mixing | `privacy` (12) |
| Prediction markets | `prediction-market` (8) |
| Reserve currency / OHM-fork | `reserve-currency` (4) |
| Uncollateralized lending | `uncollateralized-lending` (4) |
| Services / general | `services` (20) |

---

## All Categories by Protocol Type

### lending (17 categories)
- `access-control` — Missing/broken auth on critical lending functions
- `accounting-share-mismatch` — Share ↔ asset tracking inconsistencies
- `bad-debt-insolvency` — Unhandled bad debt accumulation
- `external-protocol-integration` — Issues with integrated protocols (Aave, Compound, etc.)
- `interest-accrual-errors` — Wrong interest calculations
- `interest-rate-update-ordering` — State ordering bugs in rate updates
- `liquidation-logic` — Broken liquidation mechanics
- `locked-funds` — User funds trapped by edge cases
- `non-standard-erc20` — Fee-on-transfer, rebasing, blacklist tokens
- `oracle-price-feed` — Stale prices, manipulation, L2 sequencer
- `position-health-check` — Incorrect health factor calculations
- `precision-loss-rounding` — Rounding in share/interest math
- `reentrancy` — CEI violations in deposit/withdraw/liquidate
- `reward-distribution` — Wrong reward accounting
- `slippage-protection` — Missing slippage checks on swaps
- `treasury-fee-accounting` — Fee calculation/distribution errors
- `vault-share-inflation` — First depositor / donation attacks

### cdp (21 categories)
- `access-control-bypass` — Auth bypass in CDP management
- `cross-chain-bridge-issues` — Multi-chain CDP inconsistencies
- `denial-of-service` — DoS vectors in CDP operations
- `erc4626-vault-compliance` — Non-compliant vault implementations
- `fee-on-transfer-incompatibility` — Weird token handling
- `flash-loan-attacks` — Flash loan exploitation vectors
- `front-running` — Frontrunnable CDP operations
- `governance-voting-manipulation` — Vote manipulation in CDP governance
- `incorrect-math-calculations` — Arithmetic bugs in CDP math
- `initialization-and-upgradeability` — Proxy/init vulnerabilities
- `liquidation-mechanism-flaws` — Broken liquidation mechanics
- `locked-or-frozen-funds` — Trapped funds
- `missing-state-updates` — Incomplete state transitions
- `oracle-price-manipulation` — Price feed attacks
- `precision-and-rounding-errors` — Math precision issues
- `reentrancy` — CEI violations
- `reward-accounting-errors` — Wrong reward math
- `signature-and-replay-vulnerabilities` — Sig replay attacks
- `slippage-and-sandwich-attacks` — MEV vectors
- `unsafe-token-interactions` — Token interaction pitfalls
- `vault-share-inflation` — First depositor attacks

### dexes (19 categories)
- `access-control-privilege` — Auth issues in DEX admin functions
- `amm-pool-manipulation` — AMM-specific manipulation vectors
- `denial-of-service` — DoS in swap/LP operations
- `erc4626-vault-compliance` — Vault standard issues
- `fee-accounting-errors` — Fee calculation bugs
- `fee-on-transfer-token` — FOT token handling
- `first-depositor-share-inflation` — LP token inflation
- `flash-loan-price-manipulation` — Flash loan attacks on DEX pricing
- `front-running-sandwich` — Sandwich attack vectors
- `initialization-upgradeability` — Proxy vulnerabilities
- `insufficient-input-validation` — Missing parameter checks
- `liquidity-accounting-errors` — LP math bugs
- `locked-funds` — Trapped liquidity
- `oracle-twap-manipulation` — TWAP manipulation
- `precision-rounding-errors` — Swap math precision
- `reentrancy` — CEI in swap/LP functions
- `reward-distribution-errors` — LP reward bugs
- `slippage-protection` — Missing slippage bounds
- `unchecked-return-values` — Silent failures

### synthetics (22 categories)
- `access-control` — Auth in minting/burning synthetic assets
- `accounting-mismatch` — Supply tracking inconsistencies
- `collateral-ratio-manipulation` — CR manipulation vectors
- `cross-chain-issues` — Multi-chain synthetic inconsistencies
- `denial-of-service` — DoS in mint/burn/liquidate
- `erc4626-vault-issues` — Vault compliance in synthetic vaults
- `fee-on-transfer` — FOT token handling
- `first-depositor-inflation` — Share inflation attacks
- `flash-loan-attacks` — Flash loan exploitation
- `front-running` — Frontrunnable minting/redemptions
- `governance-manipulation` — Governance attacks
- `initialization-upgradeability` — Proxy issues
- `insufficient-validation` — Input validation gaps
- `liquidation-errors` — Broken liquidation for synthetics
- `locked-funds` — Trapped synthetic collateral
- `oracle-manipulation` — Price feed attacks on synthetics
- `precision-rounding` — Math in synthetic pricing
- `reentrancy` — CEI violations
- `reward-distribution` — Reward accounting bugs
- `signature-replay` — Sig vulnerabilities
- `slippage-sandwich` — MEV vectors
- `state-inconsistency` — State management bugs

### yield / yield-aggregator (19 + 16 = 35 categories)
Key categories across both:
- Vault share accounting, strategy integration bugs, harvest timing, auto-compound errors
- Fee-on-transfer incompatibility, first depositor inflation
- Flash loan attacks on yield sources, oracle manipulation
- Reward distribution errors, precision loss in yield calculations
- Access control on strategy changes, reentrancy in deposit/withdraw

### liquid-staking (20 categories)
Key categories:
- Exchange rate manipulation, validator accounting, withdrawal queue issues
- Unbonding period attacks, slashing event handling
- Oracle integration for LST pricing, rebasing token math
- Governance manipulation, operator key management

### staking-pool (21 categories)
Key categories:
- Reward distribution accounting, stake/unstake timing attacks
- Cooldown period bypasses, delegation issues
- Governance vote manipulation, emergency withdrawal bugs

### bridge / cross-chain (18 + 20 = 38 categories)
Key categories:
- Cross-chain message replay, verification bypass
- Fund lock and stuck tokens, native ETH handling
- Flow rate limiting, gas estimation errors
- Initialization/upgradeability across chains

---

## Alchemix-Specific Loading Guide

When auditing Alchemix V3 or related contracts, load categories from:

1. **`lending/`** — core lending mechanics (17 files)
2. **`cdp/`** — CDP/self-repaying loan patterns (21 files)
3. **`yield-aggregator/`** — MYT strategy integration (16 files)
4. **`synthetics/`** — alUSD/alETH synthetic asset patterns (22 files)
5. **`oracle/`** — price feed vulnerabilities (12 files)

For Crucible Protocol (flatcoin), additionally load:
6. **`algo-stables/`** — algorithmic stablecoin patterns (12 files)
7. **`dexes/`** — AMM component patterns (19 files)

---

## File Format

Each category file contains:
```
# Category Name
> Protocol Type: X | Findings: N | Severity: Y

## Preconditions
When this vulnerability applies

## Vulnerable Pattern
Annotated Solidity code showing the anti-pattern

## Detection Heuristics
Numbered checklist for finding this vulnerability

## False Positives
When the pattern is NOT a vulnerability

## Remediation
Code fixes
```

Load the specific files you need. Don't try to load all 460 at once.
