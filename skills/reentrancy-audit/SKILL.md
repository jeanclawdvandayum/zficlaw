# Reentrancy Audit

Detect reentrancy vulnerabilities in smart contracts — classic, cross-function, read-only, and cross-contract patterns.

**Database:** 194 findings (39 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Check all external calls for reentrancy (ETH transfers, token callbacks, cross-contract calls)
2. Verify checks-effects-interactions pattern in all state-changing functions
3. Look for cross-function reentrancy (function A calls external → reenters function B using stale state)
4. Check for read-only reentrancy via view functions returning manipulated state mid-callback
5. Verify reentrancy guards (ReentrancyGuard) on ALL entry points, not just some
6. Check ERC777/ERC1155 token callbacks (tokensReceived, onERC1155Received) as reentry vectors
7. Look for ETH receive/fallback reentrancy in contracts accepting native tokens
8. Check flash loan callbacks as potential reentry points
9. Verify cross-contract reentrancy where contract A calls B which reenters A
10. Check Balancer/Curve pool interactions for read-only reentrancy (manipulated getRate/virtualPrice)

## Common Vulnerable Patterns
- `call{value: ...}("")` before state update → classic reentrancy
- `safeTransferFrom` on ERC721/1155 with `onERC721Received` callback → callback reentrancy
- Balancer `getRate()` called during pool join/exit → read-only reentrancy
- Missing `nonReentrant` on withdraw but present on deposit → inconsistent guard
- State read in view function used by other protocol during callback → cross-protocol read-only reentrancy

## Real-World Examples (from audit database)
- **[CRIT]** Reentrancy in withdrawals leading to double-spend
  - Source: Zellic: 2024-04-singularity
- **[CRIT]** Reentrancy for actions involving multiple assets allows draining the vault
  - Source: Zellic: 2024-04-singularity
- **[CRIT]** Reentrancy issue allowing repeat withdrawals
  - Source: Zellic: 2024-10-gasp-node-and-monorepo
- **[CRIT]** Fixed depositor reentrancy can take all the ETH
  - Source: Zellic: lido-fixed-income
- **[HIGH]** Potential reentrancy from malicious tokens
  - Source: ToB: 0000-compound-2
- **[HIGH]** A malicious contract can reentrantly bypass administrative checks in the
  - Source: ToB: 0000-compound-2
- **[HIGH]** Drain tokens condition due to reentrancy in collectFees
  - Source: Spearbit: 0000-clober
- **[HIGH]** Balancer Read-Only Reentrancy Vulnerability (Changes from dev team added to audit.)
  - Source: Spearbit: 0000-cronfinance
- **[HIGH]** Read-only reentrancy
  - Source: Cyfrin: 2023-03-beanstalk-wells-v01
- **[HIGH]** Intermediate value sent by the caller can be drained via reentrancy when
  - Source: Cyfrin: 2023-09-beanstalk
- **[HIGH]** Use reentrancy guard modiﬁers
  - Source: mixbytes-eywa-dao-security-audit-report
- **[HIGH]** Add a nonReentrant guard to all external entry points that can be reached during
  - Source: mixbytes-notional-v4-security-audit-report
