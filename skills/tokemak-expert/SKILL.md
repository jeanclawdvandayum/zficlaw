---
name: tokemak-expert
description: Expert knowledge of Tokemak liquidity direction protocol — AutoPool architecture (ERC-4626 vaults), tAssets, liquidity routing, RootOracle pricing, TOKE governance, and rebalancing mechanics. Use when auditing Tokemak integrations or building AutoPool adapters.
---

# Tokemak Expert

## Architecture Overview

Tokemak is a liquidity direction protocol where users deposit into AutoPools (ERC-4626 vaults) that automatically route liquidity to DEXes based on yields and governance. Core design:

- **AutoPools** — ERC-4626 vaults that accept single asset deposits (e.g., ETH, USDC)
- **Liquidity routing** — AutoPool strategies deploy liquidity to Curve, Balancer, Uniswap, etc.
- **RootOracle** — unified pricing oracle for all assets in Tokemak ecosystem
- **TOKE governance** — TOKE stakers vote on liquidity direction (which pools/DEXes to prioritize)
- **Rebalancer** — automated system that moves liquidity based on yields and governance votes

Integration pattern: Standard ERC-4626. Deposit asset → receive AutoPool shares → shares represent claim on routed liquidity + yield → withdraw to exit.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(assets, receiver)` | Deposit assets, mint shares to receiver | shares |
| `mint(shares, receiver)` | Mint exact shares, pull required assets | assets |
| `withdraw(assets, receiver, owner)` | Burn shares, send assets to receiver | shares |
| `redeem(shares, receiver, owner)` | Burn shares, send assets to receiver | assets |
| `convertToAssets(shares)` | Current asset value of shares | assets |
| `totalAssets()` | Total assets controlled by AutoPool | assets |
| `getDestinations()` | List of DEX destinations where liquidity deployed | destinations[] |
| `rootOracle.getPrice(asset)` | Get current price of asset in base currency | price |

## realAssets() Computation

For a Tokemak adapter holding AutoPool shares:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = autoPool.balanceOf(address(this));
    return autoPool.convertToAssets(shares);
}
```

**Why this works:** Standard ERC-4626. `convertToAssets()` accounts for:
- Liquidity deployed across DEXes
- Accrued yield from LP fees, farming rewards, etc.
- Idle assets in AutoPool

**RootOracle dependency:** `totalAssets()` (and thus `convertToAssets()`) relies on RootOracle for pricing LP positions across multiple DEXes. Oracle accuracy critical.

## Security Audit Considerations

- **RootOracle manipulation** — All asset pricing flows through RootOracle. If oracle compromised or manipulated, AutoPool valuations wrong
- **Multi-DEX exposure** — AutoPool deploys to Curve, Balancer, Uniswap, etc. Exploit in any destination DEX affects AutoPool
- **Rebalancing slippage** — Automated rebalancing moves liquidity between DEXes. Large moves = MEV extraction via sandwich attacks
- **Governance attacks** — TOKE holders vote on liquidity direction. Malicious voters could direct liquidity to low-yield or rigged pools
- **Destination trust** — AutoPool strategies interact with arbitrary DEXes. Malicious destination = drained liquidity
- **Impermanent loss** — AutoPool provides liquidity to DEXes, subject to IL. Not principal-protected
- **Liquidity fragmentation** — AutoPool spreads liquidity across many destinations. Withdrawal may require pulling from multiple sources, increasing gas and slippage
- **Oracle staleness** — RootOracle may have update delays. Stale prices = incorrect `totalAssets()` and potential arbitrage
- **Flash loan attacks** — Standard ERC-4626 + flash loan = potential share price manipulation
- **Paused state** — AutoPool owner can pause deposits/withdrawals. Check `paused()` status

## Known Risks / Past Incidents

- **Tokemak V1 → V2 migration** — Tokemak relaunched in 2024 as AutoPools (V2), deprecating old reactor system. Migration had hiccups, some users stuck in transition
- **Low TVL risk** — Tokemak TVL peaked ~$400M (2021), dropped to ~$50M (2024). Low liquidity = high slippage on rebalances
- **TOKE price correlation** — TOKE incentives drive yields. If TOKE dumps, AutoPool yields drop, triggering withdrawals and spiral

## Links

- Docs: https://docs.tokemak.xyz/
- GitHub: https://github.com/Tokemak/v2-core-ctf (CTF repo, main repos may be private)
- App: https://app.tokemak.xyz/
- Audits: https://docs.tokemak.xyz/developer-guides/audits
