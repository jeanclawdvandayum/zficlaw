---
name: frax-expert
description: Expert knowledge of Frax Finance staked ETH — frxETH (non-rebasing ETH), sfrxETH (ERC-4626 staking vault), FraxMinter, FraxRedemptionQueue (NFT-based exits), and validator network. Use when auditing Frax staking integrations or building sfrxETH adapters.
---

# Frax Finance Staked ETH Expert

## Architecture Overview

Frax Finance offers ETH liquid staking via frxETH/sfrxETH. Core design:

- **frxETH** — non-rebasing ETH derivative. 1 frxETH ≈ 1 ETH, but doesn't earn yield unless staked
- **sfrxETH** — ERC-4626 staking vault. Deposit frxETH → receive sfrxETH shares → earn staking yield
- **Dual-token model** — Separates ETH derivative (frxETH) from yield accrual (sfrxETH). Allows frxETH to be used in DeFi without rebasing complexity
- **FraxMinter** — deposit ETH → mint frxETH
- **FraxRedemptionQueue** — NFT-based withdrawal queue. Burn frxETH → receive redemption NFT → claim ETH when finalized
- **Frax validators** — Frax operates own validators (like Lido's node operators)

Integration pattern: For yield-bearing collateral, use sfrxETH. Deposit ETH → mint frxETH → stake to sfrxETH → hold sfrxETH → redeem to frxETH → queue withdrawal → claim ETH.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `frxETHMinter.submitAndDeposit(recipient)` | Deposit ETH, mint frxETH, stake to sfrxETH (payable) | shares |
| `sfrxETH.deposit(assets, receiver)` | Stake frxETH, mint sfrxETH to receiver | shares |
| `sfrxETH.mint(shares, receiver)` | Mint exact sfrxETH shares, pull required frxETH | assets |
| `sfrxETH.withdraw(assets, receiver, owner)` | Burn sfrxETH, send frxETH to receiver | shares |
| `sfrxETH.redeem(shares, receiver, owner)` | Burn sfrxETH, send frxETH to receiver | assets |
| `sfrxETH.convertToAssets(shares)` | Current frxETH value of shares | assets |
| `redemptionQueue.enterRedemptionQueue(recipient, amountToRedeem)` | Burn frxETH, mint redemption NFT | nftId |
| `redemptionQueue.burnRedemptionTicketNft(nftId, recipient)` | Claim ETH for finalized redemption | ethAmount |

## realAssets() Computation

For a Frax adapter holding sfrxETH:

```solidity
function realAssets() external view returns (uint256) {
    uint256 shares = sfrxETH.balanceOf(address(this));
    return sfrxETH.convertToAssets(shares);
}
```

**Why this works:** Standard ERC-4626. sfrxETH shares are static, value grows as staking rewards accrue. `convertToAssets()` returns current frxETH value (≈ ETH value).

**Pending redemptions:** If adapter has redemption NFTs, query `redemptionQueue.redemptionQueueState(nftId)` to get claimable ETH and add to realAssets.

## Security Audit Considerations

- **frxETH vs sfrxETH confusion** — frxETH does NOT earn yield. Only sfrxETH earns yield. Adapter must hold sfrxETH, not frxETH, to accrue rewards
- **ERC-4626 rounding** — Standard rounding issues. First depositor can inflate share price via donation. Frax mitigates with virtual shares, but test edge cases
- **Redemption queue delays** — Withdrawals can take 1-7 days depending on validator exit queue. Adapter must handle illiquidity
- **Centralization** — Frax runs own validators. Less decentralized than Lido (30+ operators). Frax compromise = all validators compromised
- **Slashing risk** — Validator misbehavior = slashed stake. Frax has no explicit insurance fund (unlike Lido). Slashing socializes losses to sfrxETH holders
- **Oracle dependencies** — sfrxETH exchange rate updated by Frax backend. Compromised backend = incorrect share price
- **FraxMinter trust** — All ETH deposits go through FraxMinter. Compromised minter = stolen deposits
- **Redemption queue manipulation** — Large redemptions can clog queue, delaying exits for all users
- **frxETH depeg risk** — If sfrxETH yield drops or Frax exploited, frxETH could depeg from ETH (like stETH did in 2022)
- **MEV and penalties** — Frax validators earn MEV but also risk penalties. Net yield = rewards + MEV - penalties - Frax fee (10%)

## Known Risks / Past Incidents

- **No major exploits** — Frax staked ETH launched Oct 2022, no critical exploits to date (as of Feb 2026)
- **Frax stablecoin AMO incidents** — Frax's algorithmic stablecoin (FRAX) had multiple close calls during depegs (2022-2023). Staked ETH system separate, but reputation risk
- **Validator centralization concerns** — Crypto community critiques Frax for running own validators vs. distributed operators (Lido, Rocket Pool)

## Links

- Docs: https://docs.frax.finance/frax-ether/overview
- GitHub: https://github.com/FraxFinance/frxETH-public
- App: https://app.frax.finance/frxeth/mint
- sfrxETH contract: https://etherscan.io/address/0xac3E018457B222d93114458476f3E3416Abbe38F
