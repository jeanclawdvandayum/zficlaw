---
name: beefy-expert
description: Expert knowledge of Beefy Finance yield optimizer — auto-compounding vault architecture, mooToken shares, strategy pattern, harvest mechanics, fee structure, and multi-chain deployment. Use when auditing Beefy integrations or building adapters for mooToken vaults.
---

# Beefy Finance Expert

## Architecture Overview

Beefy Finance is a multi-chain yield optimizer that auto-compounds yield from underlying protocols (LPs, lending, staking). Core design:

- **Vault** — ERC-20 contract that issues mooTokens (shares) on deposit
- **Strategy** — separate contract that interacts with underlying protocol (Curve, Aave, etc.), harvests rewards, swaps to base asset, re-deposits
- **Auto-compounding** — `harvest()` called by keepers (anyone can call, incentivized by gas refund + bounty)
- **Fee structure** — performance fee on harvests (typically 4.5%), withdrawal fee (typically 0.1%), treasury fee
- **Multi-chain** — 20+ chains including Ethereum, Arbitrum, Optimism, Base, Polygon, BSC

Integration pattern: Deposit asset into vault → receive mooToken → mooToken balance stays constant, but `getPricePerFullShare()` increases as yield compounds → withdraw by burning mooToken. Unlike ERC-4626, Beefy uses custom deposit/withdraw functions.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `deposit(amount)` | Deposit asset, mint mooToken to msg.sender | - |
| `depositAll()` | Deposit entire balance of msg.sender | - |
| `withdraw(shares)` | Burn mooToken, send proportional assets to msg.sender | - |
| `withdrawAll()` | Burn all mooToken, send all assets to msg.sender | - |
| `getPricePerFullShare()` | Current asset value per share (scaled by 1e18) | pricePerShare |
| `balance()` | Total assets controlled by vault (via strategy) | assets |
| `want()` | Underlying asset token address | address |
| `strategy()` | Current strategy contract address | address |

## realAssets() Computation

For a Beefy adapter holding mooTokens:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = mooToken.balanceOf(address(this));
    uint256 pricePerShare = mooToken.getPricePerFullShare();
    return (shares * pricePerShare) / 1e18;
}
```

**Why this works:** `getPricePerFullShare()` returns current asset value per mooToken (1e18 = 1:1). Shares are static, price grows with compounding.

**Edge case:** Some older vaults have non-standard decimals for `getPricePerFullShare()`. Check vault implementation.

## Security Audit Considerations

- **Strategy trust** — Vault delegates all asset control to strategy. Malicious strategy = total loss. Verify strategy matches expected pattern
- **proposeStrat / upgradeStrat** — Vault owner can change strategy with 48h timelock. If adapter doesn't monitor pending strategy changes, funds at risk
- **Harvest front-running** — Anyone can call `harvest()`. MEV bots can sandwich harvest swaps, extracting value. Beefy uses private RPCs to mitigate
- **Price manipulation** — `getPricePerFullShare()` calculated as `balance() / totalSupply()`. If `balance()` can be manipulated (e.g., donation to strategy), share price inflates
- **Withdrawal fee** — 0.1% fee on withdrawals (configurable per vault). Adapter should account for this in `realAssets()` calculations
- **Paused state** — Vault can be paused by owner. `deposit()` and `harvest()` revert when paused, but `withdraw()` allowed. Check `paused()` state
- **Strategy migration risks** — During `upgradeStrat()`, funds move from old strategy to new. If new strategy has bug or is malicious, funds lost
- **Third-party protocol risk** — Beefy wraps other protocols (Curve, Aave, etc.). Exploit in underlying protocol affects Beefy vault
- **Flash loan attacks** — Some strategies vulnerable to flash loan price manipulation. Audit harvest logic for TWAP usage
- **Multi-chain inconsistency** — Each chain has independent vaults/strategies. Governance and security assumptions differ per chain

## Known Risks / Past Incidents

- **Pickle Finance exploit (Nov 2020)** — Similar auto-compounder exploit. Attacker manipulated DAI jar, drained ~$20M. Beefy not affected but similar risk profile
- **Beefy Venus exploit (Oct 2021)** — Strategy flaw in Venus integration. ~$11M lost. Beefy compensated users, improved security practices
- **Strategy upgrade risk** — Multiple incidents across DeFi where malicious strategy upgrades drained funds. Beefy's 48h timelock mitigates but doesn't eliminate risk

## Links

- Docs: https://docs.beefy.finance/
- GitHub: https://github.com/beefyfinance/beefy-contracts
- App: https://app.beefy.com/
- Audits: https://docs.beefy.finance/developer-documentation/other-beefy-contracts/audits
