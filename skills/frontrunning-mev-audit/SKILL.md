# Frontrunning & MEV Audit

Detect frontrunning and MEV vulnerabilities — sandwich attacks, transaction ordering dependence, and missing slippage protection.

**Database:** 749 findings (71 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check all swap/trade operations for slippage protection (minimum output amount)
2. Verify deadline parameters on time-sensitive operations
3. Look for commit-reveal schemes that can be front-run
4. Check if oracle updates can be front-run for profit
5. Verify auction mechanisms are resistant to last-block sniping
6. Look for profitable sandwich opportunities around large state changes
7. Check governance proposal creation/voting for front-running vectors
8. Verify initialization transactions cannot be front-run
9. Check for `block.timestamp` manipulation risks (±15 seconds on mainnet)
10. Look for transaction ordering dependence in multi-step operations

## Common Vulnerable Patterns
- Swap with `amountOutMin = 0` → sandwich attack extracts full value
- Missing `deadline` parameter on swap → tx can be held and executed at unfavorable time
- Price-setting tx visible in mempool → front-run to extract value
- `block.timestamp` used for randomness → miner manipulation
- Governance vote without snapshot → front-run with flash-loaned votes

## Real-World Examples (from audit database)
- **[CRIT]** Front-runners of Uniswap swaps can steal most funds
  - Source: Zellic: 2024-04-singularity
- **[HIGH]** Front-running the encryption-key–registration transaction can deny service
  - Source: Zellic: 2025-10-cloak-v1
- **[CRIT]** Front-run withdrawValidator by submitting proofs can permanently DOS
  - Source: Cyfrin: 2024-07-casimir-v20
- **[HIGH]** MembershipERC1155::sendProfit can be front-run by calls to Member-
  - Source: Cyfrin: 2024-10-one-world-project-v20
- **[HIGH]** marketOrder() with expendOutput reverts with SlippageError with max tolerance
  - Source: Spearbit: 0000-clober
- **[CRIT]** Lack of transferId Verification Allows an Attacker to Front-Run Bridge Transfers
  - Source: Spearbit: 0000-connext
- **[CRIT]** Use of spot dex price when repay portal debt leads to sandwich attacks
  - Source: Spearbit: 0000-connext
- **[CRIT]** Use of spot price in SponsorVault leads to sandwich attack
  - Source: Spearbit: 0000-connext
- **[HIGH]** Routers are exposed to extreme slippage if they attempt to repay debt before being reconciled
  - Source: Spearbit: 0000-connext
- **[HIGH]** Users are forced to accept any slippage on the destination chain
  - Source: Spearbit: 0000-connextnxtp
- **[HIGH]** Overpayment of one side of LP Pair onJoinPool due to sandwich or user error
  - Source: Spearbit: 0000-cronfinance
- **[HIGH]** deposit and withdraw functions are susceptible to sandwich attacks
  - Source: Spearbit: 0000-gauntlet
