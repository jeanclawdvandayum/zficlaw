# Access Control Audit

Detect access control vulnerabilities — missing modifiers, privilege escalation, unprotected admin functions, and role mismanagement.

**Database:** 645 findings (59 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Verify ALL state-changing functions have appropriate access control modifiers
2. Check for missing `onlyOwner`/`onlyAdmin`/role checks on sensitive functions
3. Look for privilege escalation paths (can a lower-role user gain higher privileges?)
4. Verify two-step ownership transfers (transferOwnership should require acceptance)
5. Check proxy admin functions — can admin upgrade to malicious implementation?
6. Verify initializer functions cannot be called by unauthorized parties
7. Check if `tx.origin` is used for authorization (phishing vulnerable)
8. Look for unprotected selfdestruct/delegatecall paths
9. Verify multi-sig/timelock requirements on critical admin operations
10. Check if privileged roles can brick the protocol (rug vectors)

## Common Vulnerable Patterns
- External function with no modifier that changes critical state → missing access control
- `tx.origin == owner` → phishing attack vector
- Single-step `transferOwnership` → ownership can be lost to wrong address
- Admin can set fees to 100% or drain funds → rug vector
- `initialize()` without `initializer` modifier → can be re-initialized

## Real-World Examples (from audit database)
- **[HIGH]** Arbitrary withdrawal could be executed by bridge admin
  - Source: Zellic: 2024-08-astria-bridge
- **[HIGH]** Withdrawal event could be reused by bridge admin
  - Source: Zellic: 2024-08-astria-bridge
- **[CRIT]** The function setWithdrawThreshold lacks access control
  - Source: Zellic: 2023-12-avantis
- **[HIGH]** Missing access control in AdminGrpc API
  - Source: Zellic: 2025-12-jovay-relayer
- **[HIGH]** The quorum_change_admin function does not check the calldata selector
  - Source: Zellic: 2025-09-layerzero-v2-starknet
- **[CRIT]** Overridden ownable functionality can lead to admin lockout
  - Source: Zellic: 2025-06-d3-doma
- **[CRIT]** Vesting admin can take advantage of open approvals
  - Source: Zellic: 2025-02-solera
- **[CRIT]** Race condition allows admin to drain the vault
  - Source: Zellic: 2025-02-solera
- **[CRIT]** Lack of user access control in StakeV2
  - Source: Zellic: 2024-10-yeet
- **[CRIT]** Lack of access control in requestDeposit
  - Source: Zellic: cove
- **[CRIT]** The owner can self-assign the operator role
  - Source: Zellic: hyperbeat-pay
- **[CRIT]** Signature replay allows unauthorized migrations
  - Source: Zellic: points-farm
