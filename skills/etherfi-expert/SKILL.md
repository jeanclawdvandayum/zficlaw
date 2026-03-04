---
name: etherfi-expert
description: Expert knowledge of EtherFi liquid restaking — eETH (rebasing), weETH (wrapped non-rebasing), DepositAdapter, RedemptionManager, EigenLayer integration, and node services. Use when auditing EtherFi integrations or building eETH/weETH adapters.
---

# EtherFi Liquid Restaking Expert

## Architecture Overview

EtherFi is a liquid restaking protocol integrating with EigenLayer. Core design:

- **eETH** — rebasing liquid staking token. Balance increases as staking + restaking rewards accrue
- **weETH** — wrapped eETH. Non-rebasing, ERC-20 compliant. Preferred for DeFi integrations
- **EigenLayer restaking** — eETH holders earn both ETH staking rewards (~4%) + EigenLayer AVS rewards (variable)
- **DepositAdapter** — entry point for ETH deposits. Handles minting eETH
- **RedemptionManager** — manages eETH → ETH withdrawals (may have queue during high demand)
- **Node services** — EtherFi operates validators + EigenLayer operator nodes

Integration pattern: Deposit ETH via DepositAdapter → receive eETH → wrap to weETH for DeFi use → unwrap to eETH → redeem via RedemptionManager → claim ETH.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `liquidityPool.deposit()` | Deposit ETH, receive eETH (payable) | eETHAmount |
| `weETH.wrap(eETHAmount)` | Wrap eETH to weETH | weETHAmount |
| `weETH.unwrap(weETHAmount)` | Unwrap weETH to eETH | eETHAmount |
| `weETH.getEETHByWeETH(weETHAmount)` | Calculate eETH for given weETH | eETHAmount |
| `weETH.getWeETHByEETH(eETHAmount)` | Calculate weETH for given eETH | weETHAmount |
| `withdrawRequestNFT.requestWithdraw(recipient, amount)` | Burn eETH, mint withdrawal NFT | requestId |
| `withdrawRequestNFT.claimWithdraw(requestId)` | Claim ETH for finalized request | ethAmount |
| `liquidityPool.getTotalPooledEther()` | Total ETH controlled by protocol | totalEth |
| `liquidityPool.getTotalShares()` | Total eETH shares in circulation | totalShares |

## realAssets() Computation

For an EtherFi adapter holding weETH:

```solidity
function realAssets() external view returns (uint256) {
    uint256 weETHBalance = weETH.balanceOf(address(this));
    return weETH.getEETHByWeETH(weETHBalance);
}
```

**Why this works:** weETH is non-rebasing. `getEETHByWeETH()` converts to current eETH value (which includes accrued staking + restaking rewards). Return eETH value (≈ ETH value).

**For eETH (if holding directly):** `return eETH.balanceOf(address(this))` — balance auto-increases with rewards (rebasing like stETH).

**Pending withdrawals:** If adapter has withdrawal NFTs, query `withdrawRequestNFT.getRequest(requestId)` to check claimable ETH and add to realAssets.

## Security Audit Considerations

- **Rebasing accounting** — eETH rebases like stETH. Adapters MUST NOT cache `balanceOf()`. Use weETH to avoid rebasing complexity
- **EigenLayer risks** — eETH restakes to EigenLayer AVSs (actively validated services). AVS slashing = eETH slashing. Risk profile higher than pure ETH staking
- **AVS selection trust** — EtherFi chooses which AVSs to restake to. Malicious or buggy AVS = slashed stake
- **Withdrawal queue delays** — Withdrawals require validator exits + EigenLayer unstaking. Can take 7-14 days during high demand
- **Oracle dependencies** — eETH exchange rate updated by EtherFi oracles. Compromised oracle = incorrect rebasing
- **Centralization** — EtherFi operates validators + EigenLayer operators. Single point of failure
- **Depeg risk** — eETH:ETH can deviate during market stress (like stETH in 2022). weETH doesn't eliminate this, just removes rebasing
- **Smart contract complexity** — EigenLayer + liquid staking = complex interactions. More attack surface than simple staking (Lido)
- **Slashing amplification** — ETH staking slashing + EigenLayer AVS slashing = potential for >32 ETH loss per validator
- **RedemptionManager queue griefing** — Attacker could request many small withdrawals to clog queue
- **weETH rounding** — Wrap/unwrap involves exchange rate calculation. Small amounts may experience 1-2 wei rounding errors

## Known Risks / Past Incidents

- **EigenLayer early stage** — EigenLayer mainnet launched 2024. Limited battle-testing. Slashing not yet live (as of Feb 2026)
- **No major EtherFi exploits** — EtherFi launched 2023, no critical contract exploits to date (as of Feb 2026)
- **Restaking risk concentration** — Multiple protocols (EtherFi, Renzo, Puffer, etc.) restake to same EigenLayer AVSs. Shared risk
- **weETH depeg incident (Apr 2024)** — Pendle pool manipulation caused temporary weETH depeg to 0.98 ETH. Recovered within hours, no contract exploit

## Links

- Docs: https://etherfi.gitbook.io/etherfi/
- GitHub: https://github.com/etherfi-protocol/smart-contracts
- App: https://app.ether.fi/
- weETH contract: https://etherscan.io/address/0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee
- EigenLayer docs: https://docs.eigenlayer.xyz/
