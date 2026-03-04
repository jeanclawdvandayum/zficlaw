---
name: lido-expert
description: Expert knowledge of Lido liquid staking — stETH (rebasing), wstETH (wrapped non-rebasing), withdrawal queue (unstETH NFTs), oracle system, node operator network, and slashing protection. Use when auditing Lido integrations or building stETH/wstETH adapters.
---

# Lido Liquid Staking Expert

## Architecture Overview

Lido is the largest liquid staking protocol for Ethereum. Core design:

- **stETH** — rebasing ERC-20 token. Balance increases daily as staking rewards accrue (~4% APY). 1 stETH ≈ 1 ETH
- **wstETH** — wrapped stETH. Non-rebasing, ERC-20 compliant. Wraps stETH at exchange rate. Preferred for DeFi integrations
- **Withdrawal queue** — NFT-based queue for stETH → ETH redemptions. Users burn stETH → receive unstETH NFT → claim ETH when finalized
- **Node operators** — 30+ professional validators run Lido validators
- **Oracle** — reports beacon chain balances to update stETH total supply

Integration pattern: For DeFi adapters, use wstETH (non-rebasing). User deposits ETH → receives stETH → wraps to wstETH → hold wstETH as collateral → unwrap to stETH → queue withdrawal → claim ETH.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `stETH.submit(referral)` | Deposit ETH, receive stETH (payable) | stETHAmount |
| `wstETH.wrap(stETHAmount)` | Wrap stETH to wstETH | wstETHAmount |
| `wstETH.unwrap(wstETHAmount)` | Unwrap wstETH to stETH | stETHAmount |
| `wstETH.getWstETHByStETH(stETHAmount)` | Calculate wstETH for given stETH | wstETHAmount |
| `wstETH.getStETHByWstETH(wstETHAmount)` | Calculate stETH for given wstETH | stETHAmount |
| `withdrawalQueue.requestWithdrawals(amounts[], owner)` | Burn stETH, mint unstETH NFT(s) | requestIds[] |
| `withdrawalQueue.claimWithdrawal(requestId)` | Claim ETH for finalized request | - |
| `withdrawalQueue.getWithdrawalStatus(requestIds[])` | Check withdrawal finalization status | statuses[] |

## realAssets() Computation

For a Lido adapter holding wstETH:

```solidity
function realAssets() external view returns (uint256) {
    uint256 wstETHBalance = wstETH.balanceOf(address(this));
    return wstETH.getStETHByWstETH(wstETHBalance);
}
```

**Why this works:** wstETH is non-rebasing. `getStETHByWstETH()` converts to current stETH value (which includes accrued rewards). Return stETH value, which is ~1:1 with ETH.

**For stETH (if holding directly):** `return stETH.balanceOf(address(this))` — balance auto-increases with rewards.

**Pending withdrawals:** If adapter has unstETH NFTs, query `withdrawalQueue.getClaimableEther(requestIds[])` and add to realAssets.

## Security Audit Considerations

- **Rebasing accounting** — stETH balance changes without transfers. Adapters MUST NOT cache `balanceOf()`. Use wstETH to avoid rebasing complexity
- **1-2 wei corner case** — stETH rebasing uses shares. Small amounts may round to 0 or experience 1-2 wei discrepancies. Always use wstETH for adapters
- **Withdrawal queue delays** — Withdrawals can take 1-5 days (or longer during high demand). Adapter must handle illiquidity
- **Slashing risk** — Validator misbehavior = slashed stake. Lido has insurance fund, but large slashing event could cause stETH:ETH depeg
- **Oracle trust** — stETH supply updated by oracle. Compromised oracle = incorrect supply = broken share accounting
- **Depeg risk** — stETH:ETH price can deviate (especially pre-withdrawals, 2022). wstETH doesn't eliminate this, just removes rebasing complexity
- **Smart contract risk** — Lido holds >30% of all staked ETH. Exploit = systemic Ethereum risk
- **Node operator centralization** — If majority of node operators collude, could censor withdrawals or double-sign
- **MEV and staking penalties** — Validators earn MEV, but also risk penalties. Net yield = staking rewards + MEV - penalties - Lido fee (10%)
- **Withdrawal queue griefing** — Attacker could request many small withdrawals to bloat queue. Mitigated by minimum withdrawal amount

## Known Risks / Past Incidents

- **stETH depeg (May-Jun 2022)** — stETH traded at 0.93 ETH during Terra collapse and 3AC liquidations. Caused by forced selling + no withdrawals (pre-Shanghai upgrade). Repeg after withdrawals enabled (Apr 2023)
- **1-2 wei rounding exploit (2021)** — Attacker exploited rounding in stETH shares to mint extra tokens. Patched quickly, <$1 loss
- **No major smart contract exploits** — Lido launched Dec 2020, no critical contract exploits to date (as of Feb 2026)

## Links

- Docs: https://docs.lido.fi/
- GitHub: https://github.com/lidofinance/lido-dao
- App: https://stake.lido.fi/
- Audits: https://github.com/lidofinance/audits
- wstETH contract: https://etherscan.io/address/0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
