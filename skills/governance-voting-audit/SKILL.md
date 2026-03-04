# Governance & Voting Audit

Detect governance vulnerabilities — flash loan voting, proposal manipulation, timelock bypasses, and quorum attacks.

**Database:** 409 findings (53 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check for flash loan voting attacks — can voting power be borrowed for a single block?
2. Verify snapshot-based voting (voting power locked at proposal creation, not execution)
3. Check quorum requirements — can they be manipulated or are they too low?
4. Verify timelock delay is enforced and cannot be bypassed
5. Look for proposal front-running (reading proposal → buying tokens → voting)
6. Check governance token delegation edge cases
7. Verify vote counting handles abstentions correctly
8. Check if defeated proposals can be re-submitted immediately (spam)
9. Look for governance griefing (creating proposals to block others)
10. Verify emergency mechanisms have appropriate safeguards

## Common Vulnerable Patterns
- Voting power from `balanceOf(block.number)` without snapshot → flash loan vote
- Timelock with `delay = 0` allowed → no governance delay
- No quorum check → single voter can pass proposals
- Proposal execution without timelock → instant malicious upgrades
- `delegateBySig` without nonce → replay delegation

## Real-World Examples (from audit database)
- **[HIGH]** The quorum_change_admin function does not check the calldata selector
  - Source: Zellic: 2025-09-layerzero-v2-starknet
- **[CRIT]** Slashed finality provider retaining voting power
  - Source: Zellic: 2025-03-babylon-genesis-chain
- **[CRIT]** Slashed finality provider restoring voting power through pending delegations
  - Source: Zellic: 2025-03-babylon-genesis-chain
- **[HIGH]** Extra calls into timelock EOA will fail
  - Source: Zellic: 2024-11-cultured
- **[HIGH]** Speciﬁcation-Code mismatch for AssetProxyOwner timelock period
  - Source: trail-of-bits-0x-protocol
- **[HIGH]** Re-use of a delegate address allows invalid proposals to execute
  - Source: ToB: 0000-basis
- **[HIGH]** Previously executed proposals can be re-executed
  - Source: ToB: 0000-basis
- **[HIGH]** Malicious users can double their voting power
  - Source: Cyfrin: 2024-06-templedao-v21
- **[HIGH]** No quorum in voting allows attack to spam the election with candidates
  - Source: ToB: 0000-computable
- **[HIGH]** Aragon’s voting does not follow voting best practices
  - Source: ToB: 0000-curvedao
- **[CRIT]** TokenSaleProposal::buy implicitly assumes that buy token has 18 dec-
  - Source: Cyfrin: 2023-11-dexe-v20
- **[CRIT]** Attacker can combine flashloan with delegated voting to decide a pro-
  - Source: Cyfrin: 2023-11-dexe-v20
