# zficlaw 🔒

**An OpenClaw starter pack for smart contract security auditors.**

84 skills. Zero fluff. Everything you need to turn Claude into a security-pilled audit partner.

Built by auditors, for auditors. Emphasis on:
- **End-to-end audit processes** — from scoping to report delivery
- **Calldata attack patterns** — the overlooked attack surface
- **DeFi-specific vulnerability domains** — oracles, flash loans, governance, bridges
- **Protocol expertise** — deep knowledge of 14 major DeFi protocols
- **Automated tooling** — Semgrep, CodeQL, Slither integration, fuzzing, formal verification

---

## Quick Start

### 1. Install OpenClaw
```bash
# Follow: https://docs.openclaw.ai
```

### 2. Clone this repo
```bash
git clone https://github.com/jeanclawdvandayum/zficlaw.git
cd zficlaw
```

### 3. Install skills
```bash
# Copy all skills to your OpenClaw skills directory
cp -r skills/* ~/.openclaw/skills/

# Or symlink (auto-updates when you pull)
for skill in skills/*/; do
  ln -sf "$(pwd)/$skill" ~/.openclaw/skills/$(basename "$skill")
done
```

### 4. Copy the workspace config
```bash
cp AGENTS.md ~/clawd/AGENTS.md   # or wherever your workspace is
```

### 5. Start auditing
Tell your agent: *"I need to audit [contract]. Use the e2e-audit-process skill."*

---

## What's Inside

### 🎯 Audit Process & Methodology (13 skills)
| Skill | Purpose |
|---|---|
| `e2e-audit-process` | **Master orchestrator** — end-to-end audit from scoping to delivery |
| `nemesis-orchestrator` | **NEW** — Iterative Feynman + State Inconsistency feedback loop until convergence |
| `feynman-auditor` | **NEW** — First-principles questioning (7 categories, 28+ questions per function) |
| `state-inconsistency-auditor` | **NEW** — Coupled state desync detector (mutation matrix, parallel path comparison) |
| `audit-context-building` | Ultra-granular line-by-line code analysis for deep context |
| `audit-prep-assistant` | Pre-audit checklist (Trail of Bits methodology) |
| `audit-report-format` | Professional report formatting (severity matrix, PoC structure) |
| `entry-point-analyzer` | Map all state-changing external functions by access level |
| `spec-miner` | Extract invariants from docs, comments, and tests |
| `spec-to-code-compliance` | Verify code matches specification |
| `differential-review` | Security-focused diff review for PRs and upgrades |
| `finding-validation` | 3-check FP gate + confidence scoring + severity classification |
| `attack-vector-db` | 200 machine-formatted vectors with built-in FP conditions |

### 🔴 Vulnerability Domains (22 skills)
| Skill | Focus |
|---|---|
| `calldata-attack-patterns` | **NEW** — ABI encoding exploits, dirty bits, multicall reentrancy, proxy forwarding |
| `access-control-audit` | Role-based access, privilege escalation, missing checks |
| `reentrancy-audit` | Cross-function, cross-contract, read-only reentrancy |
| `oracle-manipulation-audit` | Price feed manipulation, TWAP bypass, stale oracles |
| `frontrunning-mev-audit` | Sandwich attacks, MEV extraction, transaction ordering |
| `dos-griefing-audit` | Gas griefing, unbounded loops, dust attacks |
| `governance-voting-audit` | Flash loan governance, vote manipulation |
| `signature-replay-audit` | EIP-712 replay, permit frontrunning, meta-tx security |
| `initialization-upgrade-audit` | Initializer exploits, storage collision, uninitialized proxies |
| `upgrades-admin-audit` | Timelock analysis, governance attack vectors |
| `cross-chain-bridge-audit` | Message validation, replay, finality attacks |
| `escrow-disputes-audit` | Optimistic protocols, dispute resolution, timeout attacks |
| `payment-streams-audit` | Streaming math, vesting edge cases, cancellation |
| `token-integration-analyzer` | Weird ERC20s, fee-on-transfer, rebasing, hooks |
| `defi-attack-taxonomy` | Comprehensive DeFi exploit classification |
| `defi-integration-audit` | Third-party protocol integration risks |
| `evm-execution-security` | Low-level EVM behaviors that create vulnerabilities |
| `exploit-forensics` | Post-mortem analysis of real exploits |
| `protocol-vulns` | Known vulnerability patterns across protocols |
| `reputation-identity-audit` | Sybil resistance, identity system attacks |
| `silent-failure-hunter` | Unchecked return values, swallowed reverts |
| `yield-strategy-builder` | Yield strategy design and risk analysis |

### 🔧 Tooling & Automation (21 skills)
| Skill | Tool |
|---|---|
| `semgrep` | Semgrep for smart contract patterns |
| `semgrep-rule-creator` | Write custom Semgrep rules |
| `codeql` | CodeQL static analysis for security |
| `scv-scan` | Smart contract vulnerability scanner |
| `property-based-testing` | Foundry fuzzing, Echidna, Medusa |
| `smart-contract-fuzzing` | Advanced fuzzing strategies |
| `formal-verification` | Certora CVL, Halmos, SMTChecker |
| `variant-analysis` | Find variants of known vulnerabilities |
| `varlock` | Variable locking analysis |
| `constant-time-analysis` | Timing side-channel detection |
| `owasp-security` | OWASP Top 10 for smart contracts |
| `sharp-edges` | Dangerous language features and patterns |
| `secure-code-guardian` | Secure coding standards enforcement |
| `secure-workflow-guide` | Secure development lifecycle |
| `security-reviewer` | Code review from security perspective |
| `insecure-defaults` | Detect fail-open configurations |
| `sarif-parsing` | Parse and triage SARIF output from tools |
| `smart-contract-defense` | Defensive programming patterns |
| `yara-rule-authoring` | YARA rules for malware/exploit detection |
| `solana-vulnerability-scanner` | Solana-specific vulnerability detection |
| `evmbench-exploits` | Known exploit benchmarks for testing tools |

### 🏛️ DeFi Protocol Expertise (14 skills)
Deep knowledge of major protocols — architecture, accounting, integration gotchas:

`aavev3-expert` · `beefy-expert` · `camelot-expert` · `etherfi-expert` · `euler-expert` · `fluid-expert` · `frax-expert` · `lido-expert` · `moonwell-expert` · `morphov2-expert` · `peapods-expert` · `stargate-expert` · `tokemak-expert` · `velodrome-expert`

### ⛓️ Ethereum Ecosystem (5 skills)
| Skill | Coverage |
|---|---|
| `ethskills-addresses` | Verified contract addresses across mainnet + L2s |
| `ethskills-building-blocks` | DeFi composability and protocol mechanics |
| `ethskills-standards` | ERC-20, 721, 1155, 4337, 4626, and newer standards |
| `ethskills-tools` | Foundry, Hardhat, block explorers, dev tooling |
| `ethskills-wallets` | EOAs, smart wallets, Safe, account abstraction |

### 🧠 Thinking & Process (5 skills)
| Skill | Purpose |
|---|---|
| `chain-of-thought` | Structured reasoning for hard problems |
| `code-reviewer` | Systematic code review methodology |
| `code-simplifier` | Reduce complexity while preserving function |
| `onchain-sleuthing` | Blockchain forensics and transaction tracing |
| `p2p-network-audit` | P2P network protocol security |

### 📊 Quality & Compliance (5 skills)
| Skill | Purpose |
|---|---|
| `code-maturity-assessor` | Trail of Bits 9-category maturity framework |
| `guidelines-advisor` | Smart contract best practices advisor |
| `second-opinion` | Challenge and validate findings |
| `verification-before-completion` | Pre-delivery quality gate |
| `p2p-network-audit` | Network-layer security analysis |

---

## Finding Validation Framework (NEW)

Every finding passes a structured gauntlet before it enters a report:

```
FP Gate (3 checks — ALL must pass):
  1. Concrete attack path (caller → call → state change → loss)
  2. Reachable entry point (check modifiers, access control)
  3. No existing guard (check requires, reentrancy locks, etc.)

Confidence Score (starts at 100, deductions applied):
  -25  Privileged caller required
  -20  Partial attack path
  -15  Self-contained impact
  -10  Specific token behavior required
  -10  External protocol state required
   -5  Requires front-running

Report Threshold:
  90-100  Must include PoC
  80-89   Include PoC and fix
  75-79   Include fix
  60-74   Description only
  <60     Drop entirely
```

## Attack Vector Database (NEW)

200 machine-formatted vectors across 17 categories, each with built-in false-positive conditions:

- **[SIG]** Signature & Authentication (8 vectors)
- **[TOK]** Token Standards & Interactions (11 vectors)
- **[NFT]** ERC721 & ERC1155 (19 vectors)
- **[VAULT]** ERC4626 Vaults (11 vectors)
- **[ACL]** Access Control (7 vectors)
- **[REEN]** Reentrancy (7 vectors)
- **[ORC]** Oracle & Price Manipulation (12 vectors)
- **[ECON]** Flash Loan & Economic (7 vectors)
- **[PROX]** Proxy & Upgrade (18 vectors)
- **[MATH]** Math & Precision (9 vectors)
- **[CALL]** Calldata & ABI (12 vectors)
- **[XCHAIN]** Cross-Chain & LayerZero (20 vectors)
- **[GOV]** Governance & Voting (4 vectors)
- **[DOS]** DoS & Griefing (8 vectors)
- **[TIME]** Time & Ordering (6 vectors)
- **[ASM]** Assembly & EVM (9 vectors)
- **[DEPLOY]** Deployment & Configuration (11 vectors)
- **[AA]** Account Abstraction / ERC-4337 (5 vectors)
- **[MISC]** Miscellaneous (16 vectors)

Each vector: description + FP conditions + category tag. Triage workflow: classify → borderline check → deep pass on survivors.

---

## Nemesis: The Iterative Deep-Logic Auditor (NEW)

Three new skills adapted from [nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) that find bugs pattern-matching misses:

### Feynman Auditor (`feynman-auditor`)
Questions every line of code using 7 systematic categories:
```
Category 1: Purpose    — WHY is this line here? What breaks if deleted?
Category 2: Ordering   — What if this line moves up/down? State gap window?
Category 3: Consistency — WHY does funcA have this guard but funcB doesn't?
Category 4: Assumptions — What is implicitly trusted about caller/data/state/time?
Category 5: Boundaries  — First call, last call, double call, self-reference?
Category 6: Return/Error — Ignored returns, silent failures, fallthrough paths?
Category 7: Call Reorder — Swap external call before/after state update?
            + Multi-Tx   — Same function, different values, across time?
```

### State Inconsistency Auditor (`state-inconsistency-auditor`)
Maps every coupled state pair and finds where one side updates without the other:
```
Phase 1: Map coupled pairs (balance↔checkpoint, shares↔index, debt↔accumulator)
Phase 2: Build Mutation Matrix (every function × every state variable)
Phase 3: Cross-check every mutation for missing coupled updates
Phase 4: Check operation ordering within functions
Phase 5: Compare parallel paths (transfer vs burn, withdraw vs liquidate)
Phase 6: Trace multi-step user journeys for stale state accumulation
Phase 7: Flag masking code hiding broken invariants (ternary clamps, min caps)
Phase 8: Verification gate (eliminate false positives)
```

### Nemesis Orchestrator (`nemesis-orchestrator`)
Runs both in an iterative feedback loop:
```
Pass 1 (Feynman) → suspects + assumptions + Function-State Matrix
    ↓ feed forward
Pass 2 (State) → gaps + new coupled pairs + masking code  
    ↓ feed back
Pass 3 (Feynman, targeted) → root cause analysis on gaps
    ↓ feed back
Pass 4 (State, targeted) → propagate root causes to other pairs
    ↓ ...continue until convergence (max 6 passes)
```
The cross-feed finds bugs that neither methodology catches alone.

---

## The Calldata Attack Emphasis

Most audit checklists treat calldata as an afterthought. We don't.

The `calldata-attack-patterns` skill covers:
- **Short calldata** — missing parameters, manual decoder exploits
- **Dirty high bits** — address padding in assembly
- **ABI encoding exploits** — offset manipulation, overlapping fields, non-canonical encoding
- **Selector collisions** — proxy pattern exploits
- **Multicall reentrancy** — msg.value double-spending, batch ordering
- **Proxy forwarding** — trailing calldata propagation, calldatasize logic
- **Cross-chain calldata** — message re-interpretation, encoding ambiguity
- **Signed calldata** — meta-transaction relay attacks

Every external function is a calldata parser. Treat it that way.

---

## End-to-End Audit Process

The `e2e-audit-process` skill defines a 6-phase methodology:

```
Phase 0: Scope & Setup     → Understand the engagement
Phase 1: Context Building   → Read before you hunt
Phase 2: Attack Surface     → Map where bugs could live
Phase 3: Vulnerability Hunt → Find bugs (patterns + Feynman + state desync)
Phase 4: Exploit & Validate → Prove they're real
Phase 5: Property Testing   → Prove the absence of bug classes
Phase 6: Report & Delivery  → Communicate clearly
```

Each phase routes to specific skills. The agent knows which skill to load at each step.

---

## Customization

This is a starter pack. Make it yours:

- **Add protocol-specific skills** for the protocols you audit most
- **Add custom Semgrep rules** for patterns you find repeatedly
- **Add your AGENTS.md** with your preferences and workflow
- **Add exploit templates** to `evmbench-exploits` from your past findings

---

## Credits

Built with [OpenClaw](https://docs.openclaw.ai). Skills sourced from:
- Trail of Bits methodology and building blocks
- OWASP Smart Contract Security
- Competitive audit findings (Code4rena, Sherlock, Cantina)
- Real-world exploit forensics
- Original research on calldata attack patterns and EVM execution security
- [nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) by 0xiehnnkta (Feynman + State Inconsistency methodology)

---

## License

MIT — use it, fork it, audit everything.
