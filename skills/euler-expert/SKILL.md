---
name: euler-expert
description: Expert knowledge of Euler V2 modular lending protocol — eVault architecture, ERC-4626 compliance, controller pattern, risk-adjusted borrowing, Dutch auction liquidations, and permit2 integration. Use when auditing Euler V2 integrations or building adapters for eVaults.
---

# Euler V2 Expert

## Architecture Overview

Euler V2 is a modular, permissionless lending protocol where each market is an independent ERC-4626 vault (eVault). Core design:

- **eVault** — isolated ERC-4626 vault per asset. Anyone can deploy via `EVaultFactory`
- **Controller pattern** — each eVault has a controller that manages collateral/liability relationships
- **Risk-adjusted borrowing** — collateral value determined by LTV, debt value by borrow factor (both per-vault configurable)
- **Dutch auction liquidations** — discount starts low, increases over time. No fixed liquidation bonus
- **Permit2 integration** — gasless approvals via Uniswap Permit2
- **No governance token** — fully permissionless, no protocol-level governance

Integration pattern: eVaults are standard ERC-4626. Call `deposit(assets, receiver)` → receive shares → shares grow in value → `withdraw(assets, receiver, owner)` or `redeem(shares, receiver, owner)`. Unlike Aave, shares don't rebase — use `convertToAssets(shares)` to get current value.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(assets, receiver)` | Deposit assets, mint shares to receiver | shares |
| `mint(shares, receiver)` | Mint exact shares, pull required assets | assets |
| `withdraw(assets, receiver, owner)` | Burn shares from owner, send assets to receiver | shares |
| `redeem(shares, receiver, owner)` | Burn exact shares from owner, send assets to receiver | assets |
| `convertToAssets(shares)` | Current asset value of shares (includes accrued interest) | assets |
| `convertToShares(assets)` | Shares required to withdraw assets | shares |
| `totalAssets()` | Total assets controlled by vault (supplied + interest - borrows) | assets |
| `maxWithdraw(owner)` | Max assets owner can withdraw (considers vault liquidity) | assets |

## realAssets() Computation

For an Euler V2 adapter holding eVault shares:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = eVault.balanceOf(address(this));
    return eVault.convertToAssets(shares);
}
```

**Why this works:** ERC-4626 `convertToAssets()` returns current value of shares, accounting for interest accrual. Unlike Aave's rebasing aTokens, Euler shares are static — value grows in `convertToAssets()`, not `balanceOf()`.

**Edge case:** If eVault has bad debt (total borrows > total deposits), `convertToAssets()` may round down to zero for small share amounts. Check `totalAssets() > 0`.

## Security Audit Considerations

- **ERC-4626 rounding** — `deposit()` rounds shares down, `mint()` rounds assets up. An attacker can donate assets to inflate share price and cause rounding issues. Euler V2 mitigates with virtual shares, but adapters should test edge cases
- **Controller trust** — eVault delegates collateral/liability logic to controller. Malicious controller = broken liquidations. Audit controller before integrating
- **Permit2 race conditions** — `permit2.approve()` can be front-run. Use nonce-based permits or tolerate reverts
- **Dutch auction gaming** — Liquidator can wait for max discount. Monitor liquidation parameters (`liquidationCoolOffTime`, `maxLiquidationDiscount`)
- **Interest rate spikes** — Each eVault has independent interest rate model (IRM). Utilization >100% possible (borrows > deposits) in extreme cases
- **Vault isolation** — Each eVault is isolated. Exploit in one doesn't affect others, but bad debt in one vault can't be socialized
- **Governor abuse** — eVault governor can change LTV, borrow factor, IRM. If adapter interacts with user-deployed eVaults, governor may rug
- **Price oracle manipulation** — Liquidations rely on external price oracle (configured per eVault). Audit oracle freshness and manipulation resistance

## Known Risks / Past Incidents

- **Euler V1 exploit (Mar 2023)** — $197M exploit via donation attack on eToken/dToken. V2 redesigned from scratch with ERC-4626 and no donation vector
- **V2 early deployment risks** — Launched 2024, less battle-tested than V1. Modular design = more surface area for edge cases

## Links

- Docs: https://docs.euler.finance/
- GitHub: https://github.com/euler-xyz/euler-vault-kit
- Deployments: https://docs.euler.finance/euler-vault-kit/deployment-addresses
- V1 exploit postmortem: https://www.euler.finance/blog/eulers-solution-for-returning-funds
