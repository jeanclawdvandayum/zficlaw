# DeFi Attack Taxonomy — 239 Vulnerability Patterns Organized by Attack Surface

Source: evmresearch.io knowledge graph (350 notes, Feb 2026). Use when auditing smart contracts, designing security reviews, or systematically checking a protocol against known attack patterns.

This is NOT a checklist (see `protocol-vulns` and `evmbench-exploits` for checklists). This is a **taxonomy**: WHY each attack class exists, what EVM/Solidity behavior enables it, and how attacks in each class interconnect.

For full details on any pattern, read the note at `~/clawd/knowledge/evmresearch/vulnerability-patterns/<note-title>.md`

---

## 1. Reentrancy (7 variants, $500M+ cumulative)

**Root cause**: External call transfers execution before state update. Four core types: single-function, cross-function, cross-contract, read-only.

**Variant evolution**: Each variant defeats the defense designed for the previous one. CEI prevents single-function. Mutex/nonReentrant prevents cross-function. Neither prevents read-only (targets view functions other protocols depend on). Neither prevents cross-contract via different storage domains.

**Hidden callback vectors**: ERC-721 `safeTransferFrom`, ERC-777 `tokensReceived`/`tokensToSend`, ERC-1155 `onERC1155Received`. Developers model standard library calls as pure state writes; the callback surface is systematically underestimated. ERC-777 `tokensToSend` enables PRE-transfer reentrancy (before sender balance debited), bypassing CEI designed for post-transfer callbacks.

**Compiler-level failures**: Vyper 0.2.15-0.3.0 gave each `@nonreentrant` function its own storage slot (should be shared global lock). Empty lock key silently produces no checks. Default function didn't respect decorator. $50-70M Curve exploit.

**Account abstraction dimension**: EIP-1153 transient storage leaks across ERC-4337 multi-UserOperation bundles. Manual cleanup required per sender boundary.

---

## 2. Access Control ($953M in 2024, #1 OWASP 2025)

**Missing modifiers on state-changing functions**: The most common form. `tx.origin` authentication vulnerable to phishing (any contract in call chain reads it).

**Two-step ownership transfer**: Exploitable when `acceptOwnership()` doesn't verify `pendingOwner` was set. OpenZeppelin `Ownable2Step` is the fix.

**Unvalidated user-supplied calldata in routers**: Seneca ($6.4M) and Socket ($3.4M) in 2024. Router holds user approvals + unvalidated calldata = attacker drains all approved tokens.

**Signing infrastructure**: Blind signing on hardware wallets provides no protection when signing UI is compromised. Multisig threshold security assumes independent uncompromised signers.

---

## 3. Signature & Cryptographic

**Malleability**: secp256k1 symmetry enables alternative valid signatures. EIP-2098 compact signatures add a second bypass vector. Defense: track processed message hashes.

**Replay taxonomy** (5 sub-patterns): cross-chain, missing parameter binding, no expiry, malleability, no nonce. Signatures without timestamps are irrevocable lifetime licenses.

**ecrecover returns address(0)** on invalid signatures, matching uninitialized address variables. False authorization via zero-address comparison.

**EIP-712 domain separator**: Computed at deployment, becomes stale after chain forks. Dynamic recomputation per-call is the fix.

**ECDSA nonce reuse**: Two signatures sharing the same `r` value expose private key algebraically in microseconds. Biased nonces enable lattice-based recovery with as few as 2-3 signatures. RFC 6979 deterministic nonce generation is the universal defense.

**ERC-2612 permit phishing**: $35M stolen in 2024 via off-chain permit signatures. Users unknowingly sign malicious allowances.

---

## 4. Arithmetic & Precision

**Post-0.8 unchecked blocks**: Restore pre-0.8 wrapping behavior. Cetus DEX $223M from missed overflow. Threat model inversion: pre-0.8 value theft became post-0.8 function bricking (DoS via revert).

**Division-by-zero**: Always reverts in Solidity (even in unchecked). Attacker-controlled denominators are a hard DoS vector with no compiler opt-out.

**Multiplication before division**: The per-function audit rule. `3/4 * 100 = 0` vs `3 * 100 / 4 = 75`. The difference is total.

**Modular architecture hides precision loss**: Individual function boundaries look acceptable; the cumulative path across functions/contracts/libraries is exploitable. Auditor technique: trace "precision chain seams" end-to-end.

**Weaponizable precision loss**: Controllable inputs + loss accruing to attacker + loop-repeatability = critical fund drain, not cosmetic inaccuracy.

**Composite rounding errors**: Individually safe rounding directions produce exploitable errors across multiple operations. Bunni $8.4M: mulDiv rounding down in one operation, repeated 44 times.

---

## 5. Upgrade & Proxy

**CPIMP (Cross-Proxy Intermediary Malware Pattern)**: Non-atomic deployment creates front-running window. Shadow implementation forwards all calls to legitimate implementation (invisible), self-restores after every transaction, layers fake ERC1967 events to evade detection. Atomic deployment (init data in constructor) is the primary defense. Post-deployment verification: `eth_getStorageAt` on EIP-1967 slot cannot be spoofed.

**Storage collisions**: EIP-2535 Diamond facets sharing proxy storage. Storage gap mismanagement in upgradeable base contracts (Audius, July 2022). Re-initialization when upgrades reset initialized boolean (AllianceBlock, August 2024).

**UUPS bricking**: Upgrade logic in implementation; uninitialized or selfdestructed implementation = permanently fatal. Missing `onlyOwner` on `_authorizeUpgrade` allows any address to upgrade.

**Process-layer vulnerability class**: Deployment sequencing, upgrade windows, and re-initialization are structurally invisible to code-level analysis. USPD had correct code and two clean audits; exploited at deployment.

---

## 6. Oracle Manipulation ($33.8M+ direct, $114M+ with economic exploits)

**Flash loan oracle manipulation**: Self-funding atomic attacks. AMM spot prices manipulable within single transaction.

**CLM slot0 exploitation**: Concentrated liquidity managers reading `pool.slot0()` for rebalancing expose users to flash-loan-manipulated position ranges.

**TWAP bypass**: Correctly implemented calm-period check applied only to user-facing functions; owner paths left unguarded. Asymmetric enforcement.

**Curve get_p() oracle**: Explicitly documented as manipulable. UwU Lend $23M from $3.796B flash loan manipulating median of 11 feeds.

**Chainlink staleness**: Heartbeats vary between feeds with similar names. Per-feed verification required. On L2: must check sequencer uptime feed before consuming prices.

---

## 7. Token Standard Quirks

**65.8% of deployed ERC-20s exhibit non-standard behaviors** (FRBScan empirical study). Compliance is the exception.

**Fee-on-transfer**: Received amount differs from specified. $500K Balancer STA drain. Balance-diff measurement is the universal defense.
**Missing return values**: USDT, BNB, OMG. Standard IERC20 call reverts on absent return data. SafeERC20 wraps in low-level assembly.
**Rebasing**: stETH-style daily rebase creates free AMM arbitrage. Breaks balance-caching protocols.
**Double entry points**: Legacy SNX/TUSD with two addresses sharing one balance. Blacklist bypass via secondary address.
**Low-decimal tokens**: GUSD (2 decimals) makes ERC-4626 inflation attacks 10^16x cheaper.
**Flash-mintable**: DAI flash mint to uint256.max inflates totalSupply denominator.
**USDT approval quirk**: Reverts on approve with non-zero existing allowance. Conflicts with BNB (reverts on approve(addr, 0)). Mutually incompatible. Permit2 is the architectural resolution.

---

## 8. Account Abstraction (ERC-4337, EIP-7702, ERC-7579)

**EIP-7702 delegation phishing**: $12M+ drained from 15,000+ wallets in 2025. 90%+ on-chain delegations malicious. chainId=0 enables cross-chain amplification. Authorization tuples encode no scope, expiry, or call restrictions (unconditional persistent capability grants).

**EIP-7702 breaks 4 EVM invariants**: (1) Contract detection (delegated EOAs have code), (2) address(this) signing identity, (3) ETH transfer safety (can revert), (4) mempool balance tracking. `tx.origin == msg.sender` no longer prevents flash loans.

**ERC-4337 paymaster drainage**: Gas penalty exploitation via inflated callGasLimit. Post-op charging drained by EntryPoint continuing when postOp reverts.

**ERC-7579 module risks**: delegatecall modules have unrestricted storage write access. Malicious modules that revert on uninstallation permanently lock accounts.

---

## 9. Governance

**Flash loan voting**: Beanstalk $182M, Build Finance $470K, GreenField $31M. Defense: snapshot-based voting power at proposal creation block.
**Slow accumulation**: Compound 2024 ($24M) via open-market purchases, five wallets. Snapshot protections block flash loans but not gradual accumulation.
**Metamorphic proposal injection**: Tornado Cash (May 2023). CREATE2 replaced approved bytecode during timelock window. Defense: bytecode hash verification at execution time.
**Vote buying**: LobbyFi April 2025, 19.3M ARB votes for 5 ETH ($10K).
**Delegation concentration**: Top 10% control 76%+ of voting power across 200+ DAOs.

---

## 10. Bridge & Cross-Chain

**40% of total DeFi hack losses** ($2.8B+). Cross-chain message verification is the #1 vulnerability class in audit findings (61 findings).
**Lock-and-mint**: Concentrates all value in single source-chain contract.
**Finality assumptions**: Premature relay before source chain confirms creates reorg attack window.
**Upgrade-introduced bugs**: Nomad ($190M, 0x00 root passed verification) and Ronin 2024 ($12M, vote threshold) from upgrade transactions.
**Cross-chain sandwich**: Bridge events reveal destination transaction details. 21.4% profit rate vs 0.8% same-chain.

---

## 11. Composability & Systemic

**Cascade propagation**: November 2025: Balancer -> Euler -> Morpho -> Lista. Local failures become systemic via dependencies.
**Vulnerability surface scales nonlinearly with complexity**: Synthetics (22 vulnerability categories), CDPs (21), staking pools (21).
**Universal vulnerability kernel**: Reentrancy, oracle manipulation, vault share inflation, slippage, precision loss, and access control appear in 15+ of 31 protocol types. This is the minimum audit baseline.

---

## 12. Denial of Service

**Unbounded loops**: Exceed block gas limit. Permanent function bricking.
**Unexpected revert**: Malicious fallback blocks push payments. Pull-payment pattern isolates.
**Gas griefing**: Meta-transaction starvation; oversized return data forces quadratic memory costs.
**Panic-based DoS**: Induction variable overflow (uint8 loop counter past 255), attacker-controlled array indices, empty array pop. All trigger unrecoverable Panic reverts.

---

## 13. MEV & Transaction Ordering ($3B+ annual)

**Sandwich attacks**: 51.56% of total MEV. Three-transaction pattern exploiting AMM deterministic pricing.
**Cross-chain sandwich**: Bridge events as information leak. 21.4% profit rate.
**JIT liquidity**: Parasitic extraction capturing swap fees without impermanent loss by sandwiching large swaps.
**Funding rate manipulation**: Large perp positions skew extraction at counterparty expense.

---

## Meta-Patterns

1. **Compiler bugs as threat category**: Source-level analysis structurally insufficient. Bytecode verification needed.
2. **Audit coverage expiry**: 92% of exploited contracts passed reviews. Specification completeness is the gap.
3. **Defense balloon**: Squeezing one vulnerability class inflates another (overflow protection -> DoS; send/transfer deprecation -> reentrancy surface).
4. **Gas optimization creates security surface**: Caching (yETH), unchecked blocks (Cetus), fixed gas stipends (all).
5. **Composability tension**: Simultaneously DeFi's greatest strength and primary systemic risk.

---

## Appendix: Grep-Scan Quick Reference

Source: kadenzipfel/scv-scan. For full detection heuristics + false positive conditions per vuln, load `scv-scan` skill and read `references/<vuln>.md`.

| Vulnerability | Grep Keywords |
|---|---|
| Reentrancy | `.call{value`, `.send(`, `_safeMint`, `_safeTransfer`, `onERC721Received`, `onERC1155Received`, `tokensReceived`, `nonReentrant` |
| Access Control | `onlyOwner`, `onlyRole`, `msg.sender ==`, `initialize(`, `initializer` |
| Delegatecall | `delegatecall`, `setImplementation`, `upgradeTo` |
| Overflow/Underflow | `unchecked`, `SafeMath`, `SafeCast`, `uint8(`, `uint16(`, `int8(`, `assembly` |
| Signature Replay | `ecrecover`, `ECDSA.recover`, `nonces`, `block.chainid`, `EIP712`, `domainSeparator` |
| Precision Loss | `/ `, `* `, `WAD`, `RAY`, `1e18`, `mulDiv` |
| Frontrunning | `minAmountOut`, `deadline`, `slippage`, `approve(`, `commit`, `reveal` |
| Unchecked Returns | `.call(`, `.send(`, `.delegatecall(`, `require(success` |
| DoS Gas Limit | `for (`, `while (`, `.length`, `.push(` |
| DoS Revert | `selfdestruct`, `.balance ==`, `.send(`, `.transfer(` |
| Hash Collision | `abi.encodePacked` |
| Timestamp | `block.timestamp`, `now`, `block.number` |
| Weak Randomness | `block.prevrandao`, `block.difficulty`, `blockhash`, `keccak256`, `% ` |
| tx.origin Auth | `tx.origin` |
| ecrecover Null | `ecrecover`, `address(0)` |
| msg.value Loop | `msg.value`, `multicall` |
| Unbounded Return | `returndatasize`, `returndatacopy`, `ExcessivelySafeCall` |
| Unsafe Low-Level | `.call(`, `.staticcall(`, `.code.length` |
| Storage Pointer | `pragma solidity 0.4`, `storage`, `memory` |
| State Shadowing | `is `, `override`, `virtual`, `super.` |
| Private Data | `private`, `secret`, `password`, `key` |
| Unsupported Opcodes | `PUSH0`, `selfdestruct`, `create(`, `create2(` |
| Deprecated Functions | `suicide`, `sha3`, `block.blockhash`, `callcode`, `throw`, `msg.gas` |
| Signature Malleability | `mapping(bytes =>`, `usedSignatures` |
| Token Standards | `SafeERC20`, `safeTransfer`, `.transfer(`, `.approve(`, `decimals` |
