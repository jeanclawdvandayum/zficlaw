---
name: aavev3-expert
description: Expert knowledge of Aave V3 lending protocol — Pool architecture, aTokens (rebasing), supply/borrow mechanics, e-mode, isolation mode, flash loans, liquidations, and multi-chain deployment. Use when auditing integrations, building adapters, or reasoning about Aave V3 yield strategies.
---

# Aave V3 Expert

## Architecture Overview

Aave V3 is a decentralized lending protocol with lending pools per asset. Core design:

- **Pool contract** — central hub for supply, borrow, withdraw, repay, liquidate
- **aTokens** — rebasing ERC-20 receipt tokens. Balance auto-increases via `balanceOf()` hook (no transfer needed)
- **Debt tokens** — variable (rebasing) and stable (fixed-rate, deprecated in most markets)
- **Isolation mode** — limits borrowing power of risky collateral
- **E-mode** — efficiency mode for correlated assets (e.g., ETH/wstETH), higher LTV
- **Multi-chain** — Ethereum, Arbitrum, Optimism, Base, Polygon, Avalanche (each has independent Pool)

Integration pattern: Supply asset via `Pool.supply()` → receive aToken (1:1 initially) → aToken balance grows automatically → withdraw via `Pool.withdraw()`. No need to track interest separately — aToken `balanceOf()` returns principal + accrued interest.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `Pool.supply(asset, amount, onBehalfOf, referralCode)` | Deposit asset, mint aToken to `onBehalfOf` | - |
| `Pool.withdraw(asset, amount, to)` | Burn aToken (from msg.sender), send asset to `to`. amount=-1 withdraws max. | actualAmount |
| `aToken.balanceOf(user)` | Current aToken balance including accrued interest | balance |
| `aToken.scaledBalanceOf(user)` | Scaled balance (internal accounting, invariant) | scaledBalance |
| `Pool.getReserveData(asset)` | Reserve configuration, liquidity index, borrow rates | ReserveData struct |
| `Pool.flashLoan(receiver, assets[], amounts[], modes[], onBehalfOf, params, referralCode)` | Flash loan (0.09% fee) | - |
| `Pool.liquidationCall(collateral, debt, user, debtToCover, receiveAToken)` | Liquidate undercollateralized position | - |

## realAssets() Computation

For an Aave V3 adapter holding aTokens:

```solidity
function realAssets() external view returns (uint256) {
    return aToken.balanceOf(address(this));
}
```

**Why this works:** `aToken.balanceOf()` internally multiplies the scaled balance by the current liquidity index, which grows with interest. No additional calculation needed.

**Alternative (gas-intensive, avoid):** `Pool.getUserAccountData(address(this))` returns total collateral value in base currency — requires oracle conversion.

## Security Audit Considerations

- **Rebasing accounting** — aToken balance increases without transfers. Ensure adapter doesn't cache balances across calls
- **Withdrawal rounding** — `withdraw(-1)` withdraws max, but `withdraw(balanceOf())` may revert due to rounding (index updates between calls). Use `type(uint256).max` or tolerate dust
- **Supply cap** — Each reserve has a supply cap. `supply()` reverts if exceeded. Check `getReserveData().configuration` for caps
- **E-mode manipulation** — Attacker can enable e-mode for an adapter's position if adapter has `setUserEMode()` permissions. Ensure adapter doesn't delegate this
- **Flash loan callback** — If adapter implements `IERC3156FlashBorrower` or `IFlashLoanReceiver`, audit callback logic for reentrancy and validation
- **Isolation mode** — Isolated assets can't be used to borrow other assets (only stablecoins). Check `getReserveData().configuration.getIsolationModeTotalDebt()`
- **Interest rate spikes** — Utilization >90% causes exponential rate increases. Adapter should handle withdrawal failures gracefully
- **Oracle dependencies** — Liquidations and LTV calculations rely on Chainlink/Aave oracles. Oracle manipulation = instant liquidations
- **Cross-chain inconsistency** — Each chain has independent Pool. An exploit on one chain doesn't affect others, but governance decisions may differ

## Known Risks / Past Incidents

- **CRV exploit (Nov 2022)** — Attacker manipulated CRV price via Aave governance, attempted large borrow. Mitigated by freezing CRV reserve
- **Curve pool exploit (Jul 2023)** — Vyper reentrancy bug drained Curve pools, affected Aave LPs. Aave paused affected reserves
- **Bad debt events** — Liquidations during high volatility can leave protocol with bad debt (collateral < debt). Aave V3 has reserve factor to absorb this

## Links

- Docs: https://docs.aave.com/developers/core-contracts/pool
- GitHub: https://github.com/aave/aave-v3-core
- Deployments: https://docs.aave.com/developers/deployed-contracts/v3-mainnet
- Whitepaper: https://github.com/aave/aave-v3-core/blob/master/techpaper/Aave_V3_Technical_Paper.pdf
