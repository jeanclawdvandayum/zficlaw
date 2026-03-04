---
name: peapods-expert
description: Expert knowledge of Peapods Finance leveraged yield protocol — ERC-4626 pod vaults, auto-compounding strategies, leverage mechanics, liquidation engine, and risk management. Use when auditing Peapods integrations or building pod adapters.
---

# Peapods Finance Expert

## Architecture Overview

Peapods is a leveraged yield protocol where users deposit collateral into "pods" that auto-compound yield with leverage. Core design:

- **Pods** — ERC-4626 vaults that borrow against deposited collateral to amplify yield
- **Auto-compounding** — Yield harvested and reinvested automatically
- **Leverage engine** — Pods borrow from lending markets (Aave, Compound, etc.) to increase position size
- **Liquidation protection** — Automated deleveraging when position approaches liquidation threshold
- **Multi-strategy** — Each pod targets different yield source (staking, LP farming, etc.)

Integration pattern: Standard ERC-4626. Deposit asset → receive pod shares → shares represent leveraged position → withdraw to unwind position and claim yield.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(assets, receiver)` | Deposit assets, mint shares to receiver | shares |
| `mint(shares, receiver)` | Mint exact shares, pull required assets | assets |
| `withdraw(assets, receiver, owner)` | Burn shares, unwind position, send assets to receiver | shares |
| `redeem(shares, receiver, owner)` | Burn shares, unwind position, send assets to receiver | assets |
| `convertToAssets(shares)` | Current asset value of shares (includes leveraged yield) | assets |
| `totalAssets()` | Total assets controlled by pod (collateral + borrowed + yield) | assets |
| `getLeverage()` | Current leverage ratio of pod | leverage (scaled 1e18, 2e18 = 2x) |
| `maxDeposit(address)` | Max deposit allowed (may be capped) | assets |

## realAssets() Computation

For a Peapods adapter holding pod shares:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = pod.balanceOf(address(this));
    return pod.convertToAssets(shares);
}
```

**Why this works:** Standard ERC-4626. `convertToAssets()` accounts for:
- Initial collateral
- Borrowed assets (net position)
- Accrued yield from strategy
- Pending harvests

**Complexity:** Pod value includes leveraged exposure. If underlying yield source drops 10% and pod is 3x leveraged, pod value drops ~30%. Adapter must understand amplified volatility.

## Security Audit Considerations

- **Leverage amplifies losses** — 3x leverage on yield also = 3x losses if strategy underperforms. Adapter should not assume principal preservation
- **Liquidation cascade risk** — If yield source drops sharply, pod may approach liquidation. Automated deleveraging sells assets, potentially at bad prices
- **Debt token risk** — Pod borrows from external protocols (Aave, Compound, etc.). If lending protocol exploited or paused, pod can't rebalance
- **Oracle manipulation** — Pod relies on oracles for collateral value and debt value. Manipulation = forced liquidation or under-collateralization
- **Flash loan attacks** — Attacker could flash loan, manipulate pod's underlying yield source price, trigger liquidation, profit from liquidation bonus
- **Auto-compounding frequency** — If harvests infrequent, APY overstated. Check `lastHarvest` timestamp
- **Slippage on unwind** — Withdrawals require selling borrowed assets back to base. Large withdrawals = slippage + potential sandwich attacks
- **Leverage ratio volatility** — `getLeverage()` changes as asset prices fluctuate. Pod may exceed max leverage, triggering emergency deleverage
- **Paused state** — Pod owner can pause deposits/withdrawals. Check `paused()` before integration
- **Strategy trust** — Pod delegates yield generation to external strategy contract. Malicious or buggy strategy = total loss

## Known Risks / Past Incidents

- **Minimal public information** — Peapods is relatively new/obscure. Limited audit history and battle-testing
- **Similar protocol exploits:**
  - **Alpha Homora (Feb 2021)** — Leveraged yield protocol exploited via Iron Bank manipulation. $37M lost
  - **Rari Fuse (Apr 2022)** — Isolated lending pools (used by leveraged protocols) exploited for $80M
- **Leverage protocol systemic risk** — All leveraged yield protocols share risk: oracle manipulation, liquidation cascades, debt market freezes

## Links

- Docs: [Likely limited or unavailable — Peapods is small/new protocol]
- GitHub: [Search github.com/peapods or similar — may not be public]
- App: [Check peapods.finance or similar domain]
- **Note:** Peapods has minimal online presence. Verify contracts via Etherscan/Arbiscan before integration. Treat as high-risk due to limited transparency.
