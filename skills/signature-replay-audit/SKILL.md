# Signature & Replay Audit

Detect signature and replay vulnerabilities — missing nonce checks, cross-chain replay, malleable signatures, and EIP-712 issues.

**Database:** 419 findings (52 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Verify nonces are used and incremented for all signed messages
2. Check for cross-chain replay — is chainId included in the signed data?
3. Verify EIP-712 domain separator includes all required fields (name, version, chainId, verifyingContract)
4. Check for signature malleability — is `ecrecover` result compared correctly?
5. Look for missing deadline/expiry on signed permits and approvals
6. Verify `ecrecover` return of `address(0)` is handled (invalid signature returns 0)
7. Check for EIP-2612 permit replay across different tokens/contracts
8. Verify multi-sig signature ordering requirements prevent double-counting
9. Look for off-by-one errors in signature threshold checks
10. Check that cancelled/used signatures cannot be resubmitted

## Common Vulnerable Patterns
- `ecrecover` without checking `!= address(0)` → invalid sig accepted as valid
- Missing `nonce` in signed message → replay attack
- Missing `block.chainid` in domain separator → cross-chain replay
- Permit without deadline → signature valid forever
- Signature over `msg.sender` instead of explicit parameter → front-run with different caller

## Real-World Examples (from audit database)
- **[HIGH]** Multisig ISM allows duplicated signatures
  - Source: Zellic: 2024-07-hyperlane-starknet
- **[CRIT]** Incorrect parity check in adaptor signatures
  - Source: Zellic: 2025-03-babylon-genesis-chain
- **[HIGH]** Variable-time multiplication by nonce in adaptor signatures, EOTSs, ECDSA,
  - Source: Zellic: 2025-03-babylon-genesis-chain
- **[CRIT]** Signature replay allows unauthorized migrations
  - Source: Zellic: points-farm
- **[CRIT]** Missing nonce validation in signature verification allows transaction re-
  - Source: Cyfrin: 2025-07-securitize-onofframp-bridge-v21
- **[CRIT]** SignatureValidator::setAllowlist is unrestricted leading to free pur-
  - Source: Cyfrin: 2025-10-remora-dynamic-tokens-v21
- **[CRIT]** Signatures on TokenBank and AllowList can be reused in perpetuity an
  - Source: Cyfrin: 2025-10-remora-dynamic-tokens-v21
- **[CRIT]** Phony signatures can be used to forge any strategy
  - Source: Spearbit: 0000-astaria
- **[HIGH]** Nonce logic is skipped for smart contract wallets
  - Source: Spearbit: 2024-04-fastlane
- **[CRIT]** Malicious Restoration Servers can replay RestoreData messages and drain accounts
  - Source: Spearbit: 2024-05-overprotocol-vciso
- **[HIGH]** EVM.Restore() gas not consumed on invalid signature
  - Source: Spearbit: 2024-05-overprotocol-vciso
- **[HIGH]** Enable Mode Signature can be replayed
  - Source: Spearbit: 2024-10-biconomy
