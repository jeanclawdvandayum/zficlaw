---
name: stargate-expert
description: Expert knowledge of Stargate Finance cross-chain liquidity protocol — LayerZero-based bridging, unified liquidity pools, delta credit system, LP tokens, STG governance, and omnichain architecture. Use when auditing Stargate integrations or building cross-chain LP adapters.
---

# Stargate Finance Expert

## Architecture Overview

Stargate is a cross-chain bridge with unified liquidity pools powered by LayerZero. Core design:

- **Unified liquidity** — single pool per asset shared across all chains. E.g., USDC pool liquidity on Ethereum backs transfers from Arbitrum
- **LayerZero messaging** — cross-chain communication via LayerZero protocol
- **Delta credit system** — balances liquidity across chains. Chains with net inflows earn credits, net outflows use credits
- **LP tokens** — ERC-20 receipt tokens for liquidity provision. Value grows from bridge fees
- **STG token** — governance + staking. veSTG holders vote on pool parameters and fee distribution

Integration pattern: Deposit asset into Pool via `deposit()` → receive LP token → LP token balance is static, value increases via fee accrual → withdraw via `instantRedeemLocal()` (instant, subject to liquidity) or `redeemLocal()` (may queue if liquidity low).

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(poolId, amount)` | Deposit asset, mint LP tokens to msg.sender | lpAmount |
| `instantRedeemLocal(poolId, lpAmount, to)` | Burn LP, send assets instantly (fails if insufficient liquidity) | amountSD |
| `redeemLocal(poolId, lpAmount, to)` | Burn LP, queue redemption if liquidity low | amountSD |
| `convertRate()` | LP token to underlying asset conversion rate | rate |
| `totalLiquidity()` | Total liquidity in pool (across all chains) | liquidity |
| `totalSupply()` | Total LP tokens in circulation | supply |

## realAssets() Computation

For a Stargate adapter holding LP tokens:

```solidity
function realAssets() external view returns (uint256) {
    uint256 lpBalance = lpToken.balanceOf(address(this));
    uint256 totalSupply = lpToken.totalSupply();
    uint256 totalLiquidity = pool.totalLiquidity();
    
    return (lpBalance * totalLiquidity) / totalSupply;
}
```

**Why this works:** LP tokens represent proportional claim on total pool liquidity. As fees accrue, `totalLiquidity` grows while `totalSupply` stays constant (or grows slower).

**Alternative:** `pool.amountLPtoLD(lpBalance)` converts LP to underlying, but may have rounding issues.

## Security Audit Considerations

- **LayerZero trust assumptions** — Stargate depends on LayerZero's security (relayers, oracles, endpoints). Compromise of LayerZero = compromise of Stargate
- **Delta credit manipulation** — Attacker could drain one chain's pool by coordinating large inflows on other chains. Delta algorithm adjusts fees to rebalance, but extreme imbalances possible
- **Instant redemption failures** — `instantRedeemLocal()` reverts if pool liquidity < redemption amount. Adapter must handle this or use `redeemLocal()` with queuing
- **Cross-chain state desync** — LayerZero message delivery not atomic. Pool state on different chains can temporarily desync
- **Fee volatility** — Bridge fees adjust dynamically based on delta credits. Low liquidity = high fees = less competitive bridge
- **Governance risk** — veSTG holders can change pool parameters (fees, caps, etc.). Malicious governance = drained pools
- **Reorg risk** — Source chain reorg after LayerZero message sent can cause double-spend. Stargate waits for finality before bridging large amounts
- **Pool depletion** — If one chain's pool fully depleted, all redemptions on that chain must queue. Adapter should monitor pool liquidity
- **STG inflation** — STG token emissions incentivize liquidity. If emissions stop or STG dumps, LP APY drops
- **LayerZero endpoint upgrades** — LayerZero endpoints are upgradeable. Malicious upgrade could redirect messages

## Known Risks / Past Incidents

- **No major exploits** — Stargate launched Mar 2022, no critical exploits to date (as of Feb 2026)
- **LayerZero oracle risk** — LayerZero's oracle model (separate relayer + oracle) has been critiqued. Google Cloud is default oracle for most chains
- **Wormhole/Nomad exploits (2022)** — Other bridges (Wormhole, Nomad) exploited for $300M+ combined. Stargate uses different architecture but similar risk profile

## Links

- Docs: https://stargatefi.gitbook.io/stargate/
- GitHub: https://github.com/stargate-protocol/stargate
- App: https://stargate.finance/
- LayerZero docs: https://layerzero.gitbook.io/docs/
