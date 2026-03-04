---
name: fluid-expert
description: Expert knowledge of Instadapp Fluid protocol — smart collateral/debt architecture, fTokens (ERC-4626 lending vaults), liquidity layer, DEx (DEX + lending), and unified liquidation engine. Use when auditing Fluid integrations or building fToken adapters.
---

# Fluid (Instadapp) Expert

## Architecture Overview

Fluid is Instadapp's unified liquidity protocol combining lending and DEX functionality. Core design:

- **fTokens** — ERC-4626 lending vaults. Each fToken represents a lending market for one asset (e.g., fUSDC, fETH)
- **Smart Collateral & Smart Debt** — deposited collateral auto-earns yield, borrowed debt auto-accrues interest. Improves capital efficiency
- **Liquidity Layer** — unified liquidity shared between lending and DEX (DEx = DEX + lending)
- **Unified liquidation** — single engine for both lending and DEX positions
- **Permissionless** — anyone can deploy fTokens via factory

Integration pattern: Standard ERC-4626. Call `fToken.deposit(assets, receiver)` → receive shares → shares represent claim on growing asset pool → `fToken.withdraw(assets, receiver, owner)` or `redeem(shares, receiver, owner)` to exit.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(assets, receiver)` | Deposit assets, mint shares to receiver | shares |
| `mint(shares, receiver)` | Mint exact shares, pull required assets | assets |
| `withdraw(assets, receiver, owner)` | Burn shares from owner, send assets to receiver | shares |
| `redeem(shares, receiver, owner)` | Burn exact shares, send assets to receiver | assets |
| `convertToAssets(shares)` | Current asset value of shares (includes interest) | assets |
| `convertToShares(assets)` | Shares required to withdraw assets | shares |
| `totalAssets()` | Total assets in vault (supplied + interest - borrows) | assets |
| `maxWithdraw(owner)` | Max assets owner can withdraw (considers liquidity) | assets |

## realAssets() Computation

For a Fluid adapter holding fToken shares:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = fToken.balanceOf(address(this));
    return fToken.convertToAssets(shares);
}
```

**Why this works:** Standard ERC-4626. `convertToAssets()` accounts for accrued interest. Shares are static, value grows over time.

**Liquidity consideration:** `maxWithdraw()` may be less than `convertToAssets()` if vault has high utilization. Adapter should handle withdrawal failures.

## Security Audit Considerations

- **ERC-4626 rounding** — Standard rounding issues. First depositor can inflate share price via donation. Fluid mitigates with virtual shares, but test edge cases
- **Smart Collateral rebasing** — Collateral earns yield while deposited. If borrower's collateral appreciates faster than debt, liquidation risk decreases. Complex to model
- **Smart Debt compounding** — Debt accrues interest continuously. Interest rate can spike if utilization high. Adapter should handle rate volatility
- **Liquidity layer interactions** — Lending liquidity shared with DEx. Large DEX trades can drain lending liquidity, blocking withdrawals
- **Oracle dependencies** — Liquidations rely on price oracles (likely Chainlink). Oracle manipulation = bad liquidations
- **Flash loan attacks** — Standard ERC-4626 + flash loan = potential for share price manipulation. Audit deposit/withdraw logic
- **Unified liquidation risks** — Liquidation engine handles both lending and DEX. Bug in one affects both
- **Permissionless deployment** — Anyone can deploy fTokens. If adapter interacts with arbitrary fTokens, attacker could deploy malicious vault
- **Interest rate model** — Each fToken has configurable IRM. Extreme utilization = extreme rates. Check IRM before integration
- **Cross-protocol reentrancy** — Fluid integrates with other protocols (Aave, Compound, etc.). Reentrancy via cross-protocol calls possible

## Known Risks / Past Incidents

- **Early stage protocol** — Launched 2024, limited battle-testing compared to Aave/Compound
- **Complexity risk** — Unified lending + DEX = more attack surface. Interactions between components not fully stress-tested
- **Instadapp track record** — Instadapp has strong history (DSA, Avocado), but Fluid is new architecture

## Links

- Docs: https://docs.fluid.instadapp.io/
- GitHub: https://github.com/Instadapp/fluid
- App: https://fluid.instadapp.io/
- Whitepaper: https://fluid.instadapp.io/whitepaper.pdf
