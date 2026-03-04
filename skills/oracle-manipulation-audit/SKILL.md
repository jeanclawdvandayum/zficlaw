# Oracle & Price Manipulation Audit

Detect oracle and price manipulation vulnerabilities — stale prices, manipulation vectors, TWAP bypasses, and flash loan oracle attacks.

**Database:** 685 findings (65 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check for stale price data — is there a heartbeat/freshness check on oracle responses?
2. Verify Chainlink `latestRoundData()` return values are ALL checked (roundId, price > 0, answeredInRound >= roundId, updatedAt)
3. Check if spot prices (getReserves, balanceOf) are used instead of oracle prices — manipulable via flash loans
4. Verify TWAP oracle window length — short windows are manipulable
5. Check for L2 sequencer uptime feed integration — prices may be stale during sequencer downtime
6. Look for price calculation errors from integer division/rounding
7. Check if oracle price can return zero and how that case is handled
8. Verify multi-oracle fallback logic — what happens when primary oracle fails?
9. Check for oracle front-running (reading price → executing before update)
10. Look for flash loan attacks that manipulate oracle inputs within a single tx

## Common Vulnerable Patterns
- `latestRoundData()` with only price checked → missing staleness/round validation
- `getReserves()` or `balanceOf()` used for pricing → flash loan manipulable
- Uniswap V3 `observe()` with short window → TWAP manipulation possible
- `price = 0` not handled → division by zero or free assets
- No L2 sequencer check → stale prices during outage used for liquidations/borrows

## Real-World Examples (from audit database)
- **[HIGH]** The fallback oracle returns zero price when no price information is provided
  - Source: Zellic: 2024-03-palmy-finance
- **[HIGH]** The function getOraclePrice may return an incorrect price
  - Source: Zellic: 2024-11-programmable-derivatives
- **[HIGH]** The executeVirtualOrdersToBlock function updates the oracle with the wrong block.number
  - Source: Spearbit: 0000-cronfinance
- **[CRIT]** An attacker can freeze all incoming deposits and brick the oracle members' reporting system with
  - Source: Spearbit: 0000-liquidcollective
- **[HIGH]** Oracle.removeMember could, in the same epoch, allow members to vote multiple times and other
  - Source: Spearbit: 0000-liquidcollective
- **[CRIT]** Oracles' reports votes are not stored in storage
  - Source: Spearbit: 0000-liquidcollective3
- **[HIGH]** SwapManager fails at updating TWAP
  - Source: Spearbit: 0000-morpho
- **[HIGH]** Mint pricing bypasses oracle validation
  - Source: Spearbit: 2026-01-buck-labs
- **[HIGH]** Lack of stale price check in getAssetPrice function
  - Source: Zellic: oracle
- **[HIGH]** Lack of newOracle validation when setting a price oracle
  - Source: ToB: 0000-compound-3
- **[HIGH]** Lack of timeout to claim listing fees allows price manipulation
  - Source: ToB: 0000-computable
- **[HIGH]** LP Oracle Should Enforce 18 Decimals Or Use Decimal Flexible
  - Source: Spearbit: 0000-sense
