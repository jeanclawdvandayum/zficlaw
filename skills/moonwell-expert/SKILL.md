---
name: moonwell-expert
description: Expert knowledge of Moonwell lending protocol — Compound V2 fork, mToken architecture, exchangeRate-based accounting, multi-chain deployment (Base, Optimism, Moonbeam), Comptroller, and safety module. Use when auditing Moonwell integrations or building mToken adapters.
---

# Moonwell Expert

## Architecture Overview

Moonwell is a lending protocol forked from Compound V2, with governance by WELL token holders. Core design:

- **mTokens** — cToken-like receipt tokens. Balance is static, value grows via `exchangeRate`
- **Comptroller** — central controller for collateral, borrowing, and liquidations
- **exchangeRate** — grows over time as interest accrues. `balanceOf * exchangeRate / 1e18 = underlying`
- **Multi-chain** — Base, Optimism, Moonbeam (independent deployments, separate governance)
- **Safety Module** — staked WELL used to backstop bad debt

Integration pattern: Call `mToken.mint(amount)` to supply → receive mToken → track value via `exchangeRateCurrent()` → call `mToken.redeem(mTokenAmount)` or `redeemUnderlying(underlyingAmount)` to withdraw. NOT ERC-4626 — uses Compound V2 interface.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `mint(uint256 mintAmount)` | Deposit underlying, mint mToken to msg.sender | 0 on success, error code otherwise |
| `redeem(uint256 redeemTokens)` | Burn mToken, send underlying to msg.sender | 0 on success |
| `redeemUnderlying(uint256 redeemAmount)` | Burn mToken equivalent to redeemAmount underlying | 0 on success |
| `exchangeRateCurrent()` | Current exchange rate (non-view, updates state) | exchangeRate (scaled 1e18) |
| `exchangeRateStored()` | Last stored exchange rate (view, may be stale) | exchangeRate (scaled 1e18) |
| `balanceOf(address)` | mToken balance of address | mTokenBalance |
| `balanceOfUnderlying(address)` | Underlying balance of address (calls exchangeRateCurrent) | underlyingBalance |
| `getCash()` | Available liquidity in mToken contract | cash |

## realAssets() Computation

For a Moonwell adapter holding mTokens:

```solidity
function realAssets() external view returns (uint256) {
    uint256 mTokenBalance = mToken.balanceOf(address(this));
    uint256 exchangeRate = mToken.exchangeRateStored(); // view function, may be slightly stale
    return (mTokenBalance * exchangeRate) / 1e18;
}
```

**Why this works:** mToken balance is static. Multiply by exchange rate to get underlying value. Use `exchangeRateStored()` for gas efficiency (view function), but be aware it may be slightly outdated.

**For precise valuation:** Call `mToken.balanceOfUnderlying(address(this))`, but this is non-view (calls `exchangeRateCurrent()`).

**Alternative:** `balanceOfUnderlying(address(this))` returns exact value but triggers state update.

## Security Audit Considerations

- **Error codes** — `mint()`, `redeem()`, etc. return uint error codes, not revert. Adapter MUST check return value. 0 = success, non-zero = failure
- **exchangeRateStored staleness** — `exchangeRateStored()` only updates when someone interacts with mToken. In low-activity markets, can be stale for hours. Use `exchangeRateCurrent()` for critical logic
- **Comptroller dependencies** — All collateral/borrow logic in Comptroller. If adapter enables mToken as collateral (`enterMarkets()`), liquidation risk
- **Oracle manipulation** — Moonwell uses Chainlink (Base/Optimism) or custom oracles (Moonbeam). Price manipulation affects liquidations
- **Paused state** — Comptroller can pause mint/borrow/transfer for specific mTokens. Check `mintGuardianPaused`, `borrowGuardianPaused`
- **Liquidity constraints** — `redeem()` fails if `getCash() < redeemAmount`. High utilization = withdrawal failures. Adapter should handle gracefully
- **Interest rate spikes** — Jump rate model: rates spike above kink (typically 80% utilization). Utilization >90% = extreme rates
- **Reentrancy** — Compound V2 has known reentrancy vectors (mitigated but not eliminated). Audit adapter for reentrancy guards
- **Governance risk** — WELL token holders can change Comptroller parameters (collateral factors, reserve factors, etc.). Base/Optimism/Moonbeam have separate governance
- **Safety Module coverage** — Bad debt backstopped by Safety Module, but coverage limited. Large depeg = insufficient backstop

## Known Risks / Past Incidents

- **Compound V2 cToken exploit (Sep 2021)** — Comptroller bug allowed users to claim excess COMP. Moonwell forked after fix but inherits V2 codebase risks
- **Moonbeam oracle issues (2022)** — Custom oracle on Moonbeam had update delays, causing liquidation cascades. Migrated to Chainlink for Base/Optimism
- **Hundred Finance exploit (Apr 2023)** — Compound V2 fork exploited via donation attack. Similar risk profile to Moonwell

## Links

- Docs: https://docs.moonwell.fi/
- GitHub: https://github.com/moonwell-fi/moonwell-contracts-v2
- App: https://moonwell.fi/
- Deployments: https://docs.moonwell.fi/moonwell/protocol-information/deployments
