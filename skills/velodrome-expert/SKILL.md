---
name: velodrome-expert
description: Expert knowledge of Velodrome DEX on Optimism — Solidly fork, stable/volatile AMM pools, veVELO governance, LP gauge rewards, vote-escrowed tokenomics, and Router architecture. Use when auditing Velodrome integrations or building LP adapters.
---

# Velodrome DEX Expert

## Architecture Overview

Velodrome is a DEX on Optimism forked from Solidly, with ve(3,3) tokenomics. Core design:

- **Stable + Volatile pools** — Stable pools use x³y + xy³ curve (low slippage for pegged assets), volatile pools use x*y = k
- **Pool = LP token** — Pool contracts ARE the ERC-20 LP tokens (not separate contracts like Uniswap V2)
- **veVELO** — vote-escrowed VELO. Locked VELO → veVELO → voting power + fee share
- **Gauge voting** — veVELO holders vote on which pools receive VELO emissions. Voters earn fees from voted pools
- **Router** — handles multi-hop swaps and liquidity provision

Integration pattern: Call `Router.addLiquidity()` → receive LP tokens (from Pool contract) → stake in Gauge to earn VELO → withdraw via `Router.removeLiquidity()`. Pools themselves are the LP tokens.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `Router.addLiquidity(tokenA, tokenB, stable, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline)` | Add liquidity to pool, mint LP to `to` | amountA, amountB, liquidity |
| `Router.removeLiquidity(tokenA, tokenB, stable, liquidity, amountAMin, amountBMin, to, deadline)` | Burn LP, send tokens to `to` | amountA, amountB |
| `Pool.getReserves()` | Current reserves of token0 and token1 | reserve0, reserve1, blockTimestamp |
| `Pool.balanceOf(address)` | LP token balance of address | balance |
| `Pool.totalSupply()` | Total LP tokens in circulation | supply |
| `Gauge.deposit(amount, tokenId)` | Stake LP tokens in gauge to earn VELO | - |
| `Gauge.withdraw(amount)` | Unstake LP tokens from gauge | - |
| `Gauge.getReward(address, tokens[])` | Claim accumulated VELO rewards | - |

## realAssets() Computation

For a Velodrome adapter holding LP tokens:

```solidity
function realAssets() external view returns (uint256) {
    uint256 lpBalance = pool.balanceOf(address(this));
    uint256 totalSupply = pool.totalSupply();
    (uint256 reserve0, uint256 reserve1, ) = pool.getReserves();
    
    // Calculate proportional share of reserves
    uint256 amount0 = (lpBalance * reserve0) / totalSupply;
    uint256 amount1 = (lpBalance * reserve1) / totalSupply;
    
    // Convert to base asset value (requires price oracle)
    return convertToBaseAsset(token0, amount0) + convertToBaseAsset(token1, amount1);
}
```

**Complexity:** Like Camelot, LP positions hold two tokens. Must calculate current token amounts from reserves, then convert to base asset value via oracle.

**If LP staked in Gauge:** Add `gauge.balanceOf(address(this))` to `lpBalance` before calculation.

**VELO rewards:** `gauge.earned(address(this))` returns unclaimed VELO. Include in valuation if adapter harvests rewards.

## Security Audit Considerations

- **Impermanent loss** — Standard AMM IL. Adapter should not assume principal preservation, especially in volatile pools
- **Stable pool depegs** — Stable pools assume token0 ≈ token1. If depeg (e.g., USDC/DAI pool during USDC depeg), extreme IL
- **Flash loan attacks** — Reserves manipulable via flash loans. Use TWAP or external oracle for pricing, not `getReserves()`
- **Router slippage** — `addLiquidity()` and `removeLiquidity()` require `amountMin` parameters. Set conservatively to prevent sandwich attacks
- **Gauge reward manipulation** — veVELO voters can redirect emissions to low-TVL pools, inflating APY temporarily then rug
- **veVELO voting bribery** — Voters bribed to direct emissions to specific pools. Adapter relying on gauge APY may see sudden drops
- **Pool contract = LP token** — Unusual pattern. Ensure adapter doesn't confuse pool address with LP token address (they're the same)
- **Locked liquidity risk** — Some pools have "locked" liquidity (LP tokens owned by protocol). If majority of LP locked, circulating LP may not represent actual liquidity
- **Multi-hop complexity** — Router supports complex multi-hop swaps. Audit swap paths for sandwich vulnerability
- **Solidly codebase risks** — Velodrome forked from Solidly (Andre Cronje's project). Solidly had early bugs (fixed in Velodrome), but similar code patterns

## Known Risks / Past Incidents

- **Solidly initial launch chaos (2022)** — Original Solidly had ve(3,3) design flaws, collapsed shortly after launch. Velodrome improved design, launched successfully
- **Velodrome no major exploits** — Launched Jun 2022, no critical exploits to date (as of Feb 2026)
- **veVELO whale manipulation** — Large veVELO holders can swing vote outcomes, affecting emissions and pool viability

## Links

- Docs: https://docs.velodrome.finance/
- GitHub: https://github.com/velodrome-finance/contracts
- App: https://app.velodrome.finance/
- Optimism-only: https://optimistic.etherscan.io/ (check deployments here)
