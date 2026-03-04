# DeFi Integration Audit

Detect vulnerabilities in DeFi protocol integrations — token handling, vault share manipulation, liquidation edge cases, and composability risks.

**Database:** 1839 findings (220 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check for fee-on-transfer token compatibility — does the contract account for transfer fees?
2. Verify rebasing token handling — do balances change unexpectedly between transactions?
3. Check ERC20 approve race condition — does it use increaseAllowance or require 0 first?
4. Look for first-depositor/donation attacks on vault share calculations
5. Verify vault share price cannot be manipulated via direct token transfers
6. Check liquidation health factor calculations — off-by-one errors, boundary conditions
7. Verify bad debt handling — what happens when position value < dust threshold?
8. Check rounding direction — should round against the user (protocol-favorable)
9. Verify minimum deposit/share amounts to prevent dust attacks
10. Check for tokens with multiple entry points (e.g., TUSD) or tokens that can be paused
11. Verify slippage protection on all swap/trade operations
12. Check collateral factor boundaries — can positions become instantly liquidatable?

## Common Vulnerable Patterns
- `balanceOf(address(this))` after transfer without before/after diff → fee-on-transfer broken
- `totalSupply == 0` check missing on first deposit → donation/inflation attack
- `approve(spender, amount)` without setting to 0 first → ERC20 approve race condition
- Rounding down in user's favor on withdrawal → protocol loses dust on each tx
- No minimum deposit → attacker can grief vault with dust deposits

## Real-World Examples (from audit database)
- **[HIGH]** Erroneous token transfer direction in the UpdateTokenShares function
  - Source: Zellic: sax
- **[HIGH]** Race condition in the ERC20 approve function may lead to token theǻt
  - Source: ToB: 0000-compound-2
- **[HIGH]** Double entrypoint or DeFi integrated ERC20 tokens should not be used
  - Source: ToB: 2023-09-offchain-labs-custom-fee-token
- **[HIGH]** Updating the entity allowance when the individual belongs to a group that
  - Source: Cyfrin: 2025-10-remora-dynamic-tokens-v21
- **[HIGH]** allowance() doesn’t limit withdraw()s
  - Source: Spearbit: 0000-gauntlet
- **[HIGH]** Restriction of transfer can be circumvented by using approve + transferFrom
  - Source: Spearbit: 0000-huma-2024
- **[HIGH]** Receiver doesn't always reset allowance
  - Source: Spearbit: 0000-lifi-retainer1
- **[HIGH]** Decrease allowance when it is already set a non-zero value
  - Source: Spearbit: 0000-lifi
- **[CRIT]** Both wlsETH and lsETH tokens are reducing the allowance when
  - Source: Spearbit: 0000-liquidcollective
- **[HIGH]** Wrong ERC20 token transferred
  - Source: Spearbit: 2024-04-fastlane
- **[CRIT]** Small amount of native token transfer dropped from mempool
  - Source: Spearbit: 2024-06-tezos
- **[HIGH]** Rewards can be stolen when IncentivizedERC20 tokens are recursively
  - Source: Cyfrin: 2025-03-paladin-valkyrie-v20
