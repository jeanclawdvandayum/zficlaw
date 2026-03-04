# Smart Contract Defense — Security Patterns, Invariant Design & Verification Strategy

Source: evmresearch.io knowledge graph (350 notes, Feb 2026). Use when designing security architecture, choosing verification tools, writing invariants, or implementing defensive patterns.

This skill covers DEFENSE: what to build, how to verify it, and the epistemological limits of each approach. For attack patterns, see `defi-attack-taxonomy`. For EVM mechanics, see `evm-execution-security`. For exploit case studies, see `exploit-forensics`.

---

## Defensive Patterns

### Reentrancy
- **CEI (Checks-Effects-Interactions)**: Update state before external calls. Free, but limits composability.
- **Mutex/nonReentrant**: Storage-based lock. Costs gas but more flexible. Vyper 0.4.0+ uses single global lock eliminating cross-function reentrancy by design (opt-out via `pragma nonreentry "manual"`).
- **Neither prevents read-only reentrancy** (targets view functions other protocols depend on). Requires cross-protocol coordination.

### Access Control
- **EIP-7702 delegation detection**: Check `msg.sender.code[0..2]` for `0xef0100` prefix. The ONLY opcode-level signal distinguishing delegated EOAs from regular EOAs and contracts. Halborn's `noEIP7702Delegation` modifier.
- **Two-step ownership**: OpenZeppelin `Ownable2Step`. Step two MUST verify step one was initiated.

### Cryptographic Defense
- **RFC 6979**: Deterministic ECDSA nonce generation via HMAC-DRBG over (sk, msg_hash). Eliminates both nonce reuse and biased-nonce lattice attacks. Universal defense for all ECDSA signing.
- **BLS Proof of Possession**: Must use domain-separated hash function (different DST for PoP vs signing). Splitting-zero attack exploits shared hash domain.
- **Merkle leaf double-hashing**: `H(H(leaf))` vs `H(left || right)` prevents second-preimage attacks without hash collision. Used by OpenZeppelin JS and Murky.
- **Commit-reveal**: Two-phase pattern concealing details until after ordering is fixed. MUST include `msg.sender` in hash to prevent commitment copying.

### Upgrade Safety
- **Atomic proxy deployment**: Pass `_data` to ERC1967Proxy constructor. Deploy+init in single transaction. Eliminates CPIMP front-running window.
- **Post-deployment verification**: `eth_getStorageAt` on EIP-1967 slot. Cannot be spoofed by CPIMP event/slot misdirection.
- **EIP-7201 namespaced storage**: Structured collision avoidance for all contract state in multi-facet systems.
- **EIP-6780**: Restricts SELFDESTRUCT to same-transaction contracts. Eliminates metamorphic patterns on L1.
- **Proxy pattern comparison**: Transparent (simple, expensive routing, admin concentrated), UUPS (cheap routing, bricking risk), Beacon (shared upgrades, amplified blast radius), Diamond (most flexible, most complex storage management).

### Oracle & Reserve
- **L2 sequencer uptime check**: MUST check Chainlink L2 Sequencer Uptime Feed before consuming price data on Arbitrum/Optimism.
- **Per-feed heartbeat verification**: Chainlink heartbeats vary between similar-named feeds. Never assume uniform update frequency.
- **Chainlink Proof of Reserve**: On-chain verification that tokenized supply matches off-chain reserves.

### Token Interaction
- **SafeERC20**: Handles missing return values (USDT/BNB/OMG), false-returning tokens, USDT zero-first approval. Does NOT handle fee-on-transfer, rebasing, or blocklists.
- **Balance-diff measurement**: Universal defense for fee-on-transfer, max-uint256 reinterpretation, and transfer caps. `balanceOf(before) - balanceOf(after)`.
- **Permit2**: Architectural resolution for mutually incompatible ERC-20 approval behaviors (USDT zero-first vs BNB zero-value revert vs OZ zero-address revert).

### MEV Defense
- **Commit-reveal**: Strong protection, two-transaction friction.
- **Token-level transfer cooldowns**: Break sandwich atomicity by blocking double-movement within a block window. Composability friction tradeoff.

### Governance Defense
- **Snapshot-based voting**: Measure power at proposal creation block. Prevents flash loan attacks. Does NOT prevent slow accumulation.
- **Bytecode hash verification at execution time**: Prevents metamorphic proposal injection (CREATE2 + SELFDESTRUCT). Store calldata instead of contract addresses.
- **Rage quit**: Credible exit threat functioning as veto without active voting. Double-edged: can be weaponized as governance DoS by coordinated actors.

### Signing Infrastructure
- **Timelocks on ownership transfers**: 24-48h delay between signature collection and execution. Converts instantaneous exploit into detectable attack. Derived from Bybit/Radiant/WazirX post-mortems.
- **Geographic signer distribution**: Reduces emergency response latency 42%.

### Runtime Security
- **Circuit breakers (ERC-7265)**: Threshold-based outflow halts. Fundamentally reactive; cannot prevent initial attack transaction. Must pair with off-chain pre-detection. Independent implementation at separate layer provides multiplicative (not additive) security guarantee.
- **Runtime invariant guards**: Trace2Inv (ACM FSE 2024): EOA + Gas Control + Data Flow Upper-bound combination blocks 85% of exploits with <1% gas overhead and 0.28% false positive rate. Practical for production.
- **EOA access control invariant**: Single most effective guard, blocks 66.7% of exploits. BUT EIP-7702 structurally breaks `tx.origin == msg.sender` check.
- **Defense-in-depth**: 12-layer framework (static analysis through incident response). Combined pre/post-deployment approaches reduce breach probability 87%, 3.5x fewer breaches.

---

## Invariant Design & Verification Strategy

### The Specification Problem
- **92% of exploited contracts in 2025 passed security reviews**. Specification completeness, not code correctness, is the primary audit gap.
- **Writing correct invariants is 80% of verification work**. Tool choice is secondary to specification quality. MakerDAO DAI had a bug undetected for 4 years; once the invariant was formulated, a fuzzer found it in under a minute.
- **Formal verification proves code matches spec, not that spec is correct or complete**. Mathematical certainty of the wrong thing provides no safety guarantee.

### Fuzzing vs Formal Verification
They find **systematically different bug classes** with minimal overlap. Complementary, not substitutes.

| Dimension | Fuzzing | Formal Verification |
|---|---|---|
| Strength | Stateful sequences, realistic interaction patterns | Mathematically rare inputs (probability < 1/2^80) |
| Weakness | Cannot reach formally rare inputs regardless of time budget | Requires complete specifications (almost never achieved) |
| Blindspot (shared) | Economic invariants, cross-contract composition, oracle manipulation |

**Neither catches**: Pricing model soundness, adversarial oracle manipulation, rounding accumulation over N operations. These require human expertise.

**Cross-language specification**: Writing specs in a different language than the implementation reveals compiler-level assumption bugs. PRB-Math mulDivSigned case: divergence visible only because Certora CVL and Solidity have different type systems.

### Practical Fuzzing
- **Handler preconditions**: Use `bound()`, `deal()`, and setup-before-test patterns. A handler that always reverts gives false confidence (fuzzer records thousands of "passing" runs while never reaching invariant checks).
- **Linearity invariant**: `f(X, Y) called X times == f(1, X*Y) called once`. Trivially constructable fuzzing oracle detecting rounding and accumulation bugs.
- **Complementary function pairs**: Diff state mutation sets of inverse functions (deposit/withdraw, add/delete). Asymmetry in mutated fields = bug.

### Automated Tools Ceiling
- Combined automated tools catch ~60% of exploitable vulnerabilities
- Remaining 40% requires human expertise in: economic modeling, compositional reasoning, protocol-specific invariant design
- Combining multiple tools (symbolic + static, multiple fuzzers) detects more unique vulns than any single tool
- Complex multi-step interaction invariants are the class that both human auditors and automated tools most commonly miss

---

## Audit Methodology

### Bug Heuristic Methodology
Intersection targeting: cross "easy to get wrong" patterns with "high-impact targets."

**Easy to get wrong** (14 heuristics):
1. Callbacks in token standards (ERC-721, 777, 1155)
2. Gas-sensitive code near external calls
3. try/catch error handling with external calls
4. Unchecked blocks with non-trivial bounds
5. Division before multiplication chains
6. Array pop/delete with mappings
7. Memory vs storage keyword confusion
8. Rounding direction across multi-operation sequences
9. Permit/approval race conditions
10. Timestamp-dependent logic
11. Loop bounds with user-controlled length
12. Cached state across lifecycle transitions
13. Bootstrap logic reachable after launch
14. Complementary function pair asymmetry

**High-impact targets**: Bridge verification, liquidation engines, governance execution, oracle consumption, token migration/upgrade.

### Developer Assumption Hunting
For each function, enumerate implicit preconditions the developer never wrote as explicit checks. Eight subtypes:
1. Empty arrays (bypass loop-based verification)
2. Step ordering (assumed A before B)
3. Unchecked return values
4. Unexpected matching inputs (src == dst)
5. Assumed uniqueness (duplicate entries in lists)
6. Mutual exclusivity (ETH + WETH double-counting)
7. Assumed boundedness (unbounded growth)
8. Sentinel reliability (address(0) as "not initialized" when 0 is legitimate)

### Coverage Expiry
Audit coverage expires when:
1. Post-audit patches create new attack surface (Euler)
2. Permissionless registration adds untrusted contracts (Penpie)
3. Deployment pipeline bypasses review (Socket)
4. Governance changes parameters outside audited bounds
5. External dependency upgrades (token proxy changes semantics)

---

## Key Statistics for Calibration

- 92% of exploited contracts passed security reviews (2025)
- $3.1B stolen despite audits
- 65% of losses from social engineering/key management
- Access control: #1 by value ($953M, 2024)
- Business logic: #2 by frequency (58 incidents, 47.5% of 2025)
- Cross-chain message verification: #1 by audit finding frequency (61 findings)
- Universal vulnerability kernel: reentrancy + oracle + vault inflation + slippage + precision + access control (appears in 15+ of 31 protocol types)
- Defense-in-depth: 87% breach probability reduction, 3.5x fewer incidents

---

## Deep-Dive Reference

Full security patterns at `~/clawd/knowledge/evmresearch/security-patterns/`.
Full protocol mechanics at `~/clawd/knowledge/evmresearch/protocol-mechanics/`.
