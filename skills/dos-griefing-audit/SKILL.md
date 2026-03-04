# DoS & Griefing Audit

Detect denial of service and griefing vulnerabilities — unbounded loops, gas bombs, block stuffing, and protocol-halting edge cases.

**Database:** 522 findings (82 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check for unbounded loops over user-controlled arrays — can an attacker make loops exceed block gas limit?
2. Verify external calls in loops have proper error handling (try/catch or continue on failure)
3. Look for block stuffing attacks on time-sensitive operations
4. Check for griefing via dust amounts (e.g., sending 1 wei to break invariants)
5. Verify pull-over-push payment patterns for bulk distributions
6. Check if a single revert in a batch operation blocks the entire batch
7. Look for gas limit issues in cross-chain messages
8. Verify precompile gas costs are correctly accounted for
9. Check for ReDoS (Regular Expression Denial of Service) in off-chain validators
10. Look for state growth attacks — can an attacker create unbounded storage entries?

## Common Vulnerable Patterns
- `for (uint i = 0; i < users.length; i++)` with external call → gas limit DoS
- `require(success)` after `call` in loop → one failure blocks all
- Fixed gas stipend (`2300`) for ETH transfer → contract recipients fail
- Unbounded array `.push()` without removal mechanism → gas limit over time
- Missing `maxIterations` parameter on pagination → full scan DoS

## Real-World Examples (from audit database)
- **[HIGH]** Query gas limit not enforced through bank module
  - Source: Zellic: 2024-06-initia
- **[HIGH]** Node ReDoS in claim receipt validation
  - Source: Zellic: 2024-04-reclaim-protocol
- **[CRIT]** DOS vulnerability from inaccurate gas estimation in BeginBlock via simCheck
  - Source: Zellic: 2024-11-fairyring
- **[HIGH]** Low gas costs of precompiles lead to denial of service
  - Source: Zellic: swisstronik
- **[CRIT]** Attacker can cause a DOS during unstaking by intentionally reverting the
  - Source: Cyfrin: 2024-07-casimir-v20
- **[CRIT]** Front-run withdrawValidator by submitting proofs can permanently DOS
  - Source: Cyfrin: 2024-07-casimir-v20
- **[CRIT]** Dust limit attack on forceUpdateNodes allows DoS of rebalancing and
  - Source: Cyfrin: 2025-07-suzaku-core-v20
- **[CRIT]** Critical DOS in queue processing if async cancellations are allowed
  - Source: Cyfrin: 2025-10-accountable-v20
- **[HIGH]** Users can get their withdrawal active requests DoSed by malicious users
  - Source: Cyfrin: 2025-10-strata-tranches-v20
- **[HIGH]** Vault creation can be DoSed by lien owners who can transfer their lien token to any address
  - Source: Spearbit: 0000-astaria-july
- **[HIGH]** VaultImplementation.buyoutLien can be DoSed by calls to LienToken.buyoutLien
  - Source: Spearbit: 0000-astaria
- **[CRIT]** OrderBook Denial of Service leveraging blacklistable tokens like USDC
  - Source: Spearbit: 0000-clober
