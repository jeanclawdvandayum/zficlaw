# EVM Execution Security — How the Machine Creates Vulnerabilities

Source: evmresearch.io knowledge graph (350 notes, Feb 2026). Use when auditing smart contracts, reviewing EVM-level behaviors, or understanding WHY vulnerability patterns exist at the machine level.

This skill covers the EVM execution model and Solidity compiler behaviors that **create** vulnerabilities. Existing audit checklists tell you WHAT to look for; this tells you WHY it's exploitable.

---

## Storage Model

**Slot packing**: Compiler packs consecutive sub-32-byte variables into shared slots. Writing any packed variable requires SLOAD→modify→SSTORE (read-modify-write). In proxy contexts, packing decisions are permanently locked because storage layout must remain consistent across implementation versions.

**Custom storage layouts** (Solidity 0.8.29+): Allow explicit slot positions for proxy patterns. EIP-1967 standardizes proxy metadata slots via `keccak256("eip1967.proxy.implementation") - 1`. EIP-7201 extends this to namespaced storage for all contract state, enabling multi-facet proxy systems without collision.

**Transient storage** (EIP-1153): Key-value storage that persists within a single transaction, auto-clears at tx end. Solidity 0.8.28 added language support. **Critical bugs**: (1) Solidity 0.8.28-0.8.33 had a bug where clearing a regular storage variable could unintentionally clear a transient variable at the same slot, and vice versa (SOL-2026-1). (2) Transient values persist across external calls within a transaction, violating composability assumptions in multi-contract interactions. (3) SIR.trading lost $355K from residual transient storage values in callbacks. (4) TSTORE lacks SSTORE's minimum gas cost, enabling reentrancy at lower gas thresholds than traditional storage-based guards expect.

**Dangling references**: `.pop()` on arrays invalidates storage references but doesn't clear them. Writing through a dangling reference hits unintended storage slots. `delete` on arrays containing mappings leaves orphaned mapping data (mappings can't enumerate keys).

**Memory model**: Memory-to-memory assignment creates references, not copies. Both variables alias the same data. Memory/calldata values are NOT packed (every value occupies 32 bytes). Memory gas costs grow quadratically; memory is never freed within a transaction. Scratch space at 0x00-0x3f is overwritten by mapping/array hash computations between assembly blocks.

---

## Execution Model

**delegatecall**: Executes code from target address using caller's storage, msg.sender, and msg.value. Foundation of all proxy patterns. Every state write lands in the proxy's storage slots.

**Low-level call to non-existent address**: CALL to empty address succeeds silently (returns true). The EVM doesn't distinguish "executed successfully" from "nothing to execute." Three tiers of protection exist but none are default.

**EXTCODESIZE timing**: Returns zero during constructor execution. Any `extcodesize(caller) == 0` EOA check is bypassable by calling from a constructor.

**CREATE2 metamorphism**: CREATE2 address depends on `keccak256(0xff ++ deployer ++ salt ++ keccak256(init_code))`, which uses init code hash, not runtime bytecode. A fixed init code that fetches implementation from an external source produces different runtime bytecode at the same address after selfdestruct+redeploy. EIP-6780 (Dencun) restricts SELFDESTRUCT to same-transaction contracts, eliminating this on L1, but L2s that haven't adopted Cancun changes remain vulnerable.

**Opcode incompatibility**: PUSH0 (default since Solidity 0.8.20) unsupported on zkSync Era, Polygon zkEVM, Linea. CREATE/CREATE2 behave differently on zkSync. SELFDESTRUCT semantics diverge across chains. OpDiffer study (ISSTA 2025): 26 bugs across 9 EVM implementations; 7.21% of deployed contracts affected; PUSH0/TSTORE/MCOPY disproportionately buggy.

**EIP-2929 warm/cold access**: Cold SLOAD costs 2100 gas (up from 200). This broke contracts relying on 2300 gas stipend for implicit reentrancy prevention. Solidity 0.8.31 deprecated send/transfer in response.

---

## Precompiles

**BN256 curve precompiles** (ecAdd 0x06, ecMul 0x07, ecPairing 0x08): Never revert on invalid input. Return empty/false on error. Unchecked return value means invalid ZK proofs silently pass.

**Cross-chain precompile divergence**: Moonbeam reverts on under-length input; Aurora v2.7.0 reverts on identity point. Same Solidity code, different behavior across chains.

**BLS12-381** (EIP-2537, Pectra): Native BLS verification. Rogue-key attacks possible when registering a cancellation public key. Defense: Proof of Possession with domain-separated hash function (different DST for PoP vs signing).

---

## Solidity Compiler Behaviors

**Arithmetic**: Solidity 0.8+ defaults to checked arithmetic (reverts on overflow). `unchecked {}` blocks restore pre-0.8 wrapping. This converted overflow from a value-manipulation vulnerability into a DoS vector (functions revert instead of producing wrong values). Cetus DEX lost $223M in 2025 from missed overflow in unchecked blocks.

**Division**: Integer division truncates toward zero. `1/2 = 0`. Yul division by zero returns zero (not revert). Signed integer division: `int_min / -1` silently wraps in unchecked/Yul (the positive result exceeds type max).

**Panic codes**: Solidity 0.8 encodes compiler-inserted reverts as `Panic(uint256)` with selector `0x4e487b71`. Ten defined codes. Three carry high DoS potential: 0x11 (arithmetic overflow), 0x12 (division by zero), 0x32 (array out-of-bounds).

**ABI encoding**: Not self-describing. `abi.encodePacked` concatenates without padding, creating collision risks for types shorter than 32 bytes. Function return types are excluded from the 4-byte selector.

**Visibility**: `private` only restricts contract-level interface access. Storage is always readable via `eth_getStorageAt`. `pure` functions use STATICCALL (prevents writes) but cannot prevent state reads at EVM level.

**Compiler bugs**: Majority of 0.8.x bugs manifest only under specific pipeline configs (via-IR, optimizer, ABIEncoderV2). Same source code, different bytecode semantics. SOL-2026-1: via-IR Yul helper naming collision between persistent and transient storage clearing (0.8.28-0.8.33).

**Vyper compiler bugs**: Double evaluation (5 CVEs from 2024-2025, largest cluster). CVE-2023-46247: reentrancy lock storage slot bug gave each @nonreentrant function its own slot (versions 0.2.15-0.3.0), causing the $50-70M Curve exploit. CVE-2023-42441: empty string nonreentrant key silently produces no checks. Undefined argument evaluation order is the root cause of multiple CVE clusters.

---

## Assembly & Low-Level Code

**Inline assembly** bypasses all Solidity safety: type enforcement, overflow protection, access control modifiers, visibility keywords. None are EVM constructs.

**Hand-written EVM code** (Huff, raw bytecode) has 6 vulnerability classes structurally impossible in compiler-generated code: missing dispatch termination (fall-through into unrelated bytecode), missing type masking (dirty upper bits produce different storage slots), missing extcodesize check, missing arithmetic safety, missing access control, missing blueprint protection (ERC-5202 without 0xFE71 preamble).

---

## Key Tensions

1. **Storage packing**: saves gas but creates read-modify-write complexity and permanently locks layout in proxy contexts.
2. **Custom storage layouts**: enable powerful proxy patterns but manual slot math errors corrupt data.
3. **Unchecked blocks vs safety**: three-sided tension between DoS (checked reverts), value manipulation (unchecked wrapping), and development cost (explicit validation).
4. **send/transfer deprecation**: removing 2300 gas stipend makes reentrancy defense the developer's responsibility while widening DoS surface for callback recipients.
5. **Compiler trust boundary**: Vyper eliminates inheritance/assembly vulnerability classes but Curve exploit proved compiler bugs silently break source-level guards. Source-level auditing is necessary but insufficient.

---

## Deep-Dive Reference

Full notes at `~/clawd/knowledge/evmresearch/evm-internals/` and `~/clawd/knowledge/evmresearch/solidity-behaviors/`.
