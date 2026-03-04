---
name: e2e-audit-process
description: End-to-end smart contract security audit process — from scoping through delivery. Covers context building, attack surface mapping, systematic vulnerability hunting, exploit development, finding validation, and report writing. Use this as the master orchestration skill for any audit engagement.
---

# End-to-End Smart Contract Security Audit Process

This is the master process skill. It orchestrates the other audit skills in the correct order.

---

## Phase 0: Scope & Setup (Before Code)

**Goal:** Understand what you're auditing and why.

### 0.1 Engagement Scoping
- [ ] Get the exact commit hash / tag / branch
- [ ] Identify files in scope vs out of scope
- [ ] Note the chain(s) of deployment (mainnet, L2s, cross-chain?)
- [ ] Identify external dependencies (which protocols are integrated?)
- [ ] Get the deployment configuration (constructor args, admin addresses, initial params)
- [ ] Ask: "What are YOU most worried about?" (the team often knows)

### 0.2 Prior Art
- [ ] Check for previous audits (read ALL of them)
- [ ] Check the project's bug bounty / immunefi page
- [ ] Search audit databases for similar protocols (→ use `audit-db` skill)
- [ ] Check for known issues in dependencies (OpenZeppelin version? Solmate version?)

### 0.3 Environment
- [ ] Clone repo, verify you can compile (`forge build`)
- [ ] Run existing test suite (`forge test -vv`) — note failures
- [ ] Check test coverage (`forge coverage`)
- [ ] Verify deployment scripts exist and are coherent

---

## Phase 1: Context Building (Read Before You Hunt)

**Goal:** Build a mental model of the system. Don't touch vulnerabilities yet.

**Use skill: `audit-context-building`**

### 1.1 Architecture Map
- [ ] Identify core contracts and their roles
- [ ] Map the inheritance hierarchy
- [ ] Map external calls (which contracts call which)
- [ ] Identify the trust boundaries (who can call what)
- [ ] Draw the state machine (what states exist, what transitions them)

### 1.2 Entry Point Analysis
**Use skill: `entry-point-analyzer`**
- [ ] List ALL external/public functions
- [ ] Categorize by access level: unrestricted / role-gated / admin-only
- [ ] Identify the "hot paths" — functions that move money or change critical state
- [ ] Identify callback receivers (hooks, flash loan callbacks, etc.)

### 1.3 Specification Mining
**Use skill: `spec-miner`**
- [ ] Extract invariants from documentation, comments, tests
- [ ] Identify implicit assumptions (what does the code assume but not check?)
- [ ] Note any discrepancies between docs and code
- [ ] Build a list of "properties that must hold" for Phase 3

### 1.4 Token Flow Analysis
- [ ] Map how tokens enter the system (deposits, mints, swaps)
- [ ] Map how tokens exit (withdrawals, burns, claims)
- [ ] Identify any intermediate token states (shares, receipt tokens, locked tokens)
- [ ] Verify conservation: can tokens be created from nothing or destroyed?
- [ ] Check for fee-on-transfer token compatibility
- [ ] Check for rebasing token compatibility

---

## Phase 2: Attack Surface Mapping

**Goal:** Identify WHERE vulnerabilities could exist.

### 2.1 Calldata Attack Surface
**Use skill: `calldata-attack-patterns`**
- [ ] Identify all calldata entry points
- [ ] Check for raw calldata handling (assembly, abi.decode, msg.data)
- [ ] Map proxy forwarding chains
- [ ] Identify multicall/batch patterns
- [ ] Check for cross-chain message handlers

### 2.2 Access Control Surface
**Use skill: `access-control-audit`**
- [ ] Map all roles and permissions
- [ ] Verify role assignment/revocation is secure
- [ ] Check for privilege escalation paths
- [ ] Verify initializer access control
- [ ] Check for open access on sensitive functions

### 2.3 Oracle & External Data Surface
**Use skill: `oracle-manipulation-audit`**
- [ ] Identify all external price feeds / data sources
- [ ] Check for TWAP vs spot price usage
- [ ] Verify oracle staleness checks
- [ ] Test oracle manipulation scenarios
- [ ] Check for oracle-dependent liquidation paths

### 2.4 Upgrade & Initialization Surface
**Use skill: `initialization-upgrade-audit`, `upgrades-admin-audit`**
- [ ] Check proxy patterns and upgrade authority
- [ ] Verify initializer can only be called once
- [ ] Check for storage layout collisions across upgrades
- [ ] Verify timelock/governance controls on upgrades
- [ ] Check for uninitialized implementation contracts

### 2.5 Economic Attack Surface
**Use skills: `defi-attack-taxonomy`, `frontrunning-mev-audit`, `yield-strategy-builder`**
- [ ] Model flash loan attack scenarios
- [ ] Check for sandwich attack vectors
- [ ] Verify economic invariants (debt ≤ collateral, shares ≤ supply, etc.)
- [ ] Check for first-depositor / inflation attacks
- [ ] Model liquidation cascades

---

## Phase 3: Systematic Vulnerability Hunting

**Goal:** Find bugs, methodically.

### 3.1 Automated Tooling (Run First)
**Use skills: `semgrep`, `codeql`, `scv-scan`, `slither-integration`**
- [ ] Run Slither → triage HIGH/MEDIUM findings
- [ ] Run custom Semgrep rules for project-specific patterns
- [ ] Run CodeQL if applicable
- [ ] Run Aderyn / custom static analysis
- [ ] **Do NOT trust automated tools as final answer** — they miss business logic

### 3.2 Pattern-Based Review
Walk through each vulnerability domain systematically:

**Use skills (check each):**
- [ ] `reentrancy-audit` — Cross-function, cross-contract, read-only reentrancy
- [ ] `dos-griefing-audit` — Unbounded loops, gas griefing, dust amounts
- [ ] `signature-replay-audit` — EIP-712, permit, meta-tx replay
- [ ] `governance-voting-audit` — Flash loan governance, vote manipulation
- [ ] `escrow-disputes-audit` — Dispute resolution, timeouts, edge cases
- [ ] `payment-streams-audit` — Streaming/vesting math, cancellation, rounding
- [ ] `token-integration-analyzer` — Weird ERC20s, hooks, callbacks
- [ ] `cross-chain-bridge-audit` — Message validation, replay, finality
- [ ] `evm-execution-security` — Low-level EVM behaviors creating vulns
- [ ] `silent-failure-hunter` — Unchecked calls, swallowed reverts
- [ ] `constant-time-analysis` — Timing side channels (if applicable)

### 3.3 Business Logic Review
**This is where most critical bugs hide.**

**Use skill: `spec-to-code-compliance`**
- [ ] For each invariant from Phase 1.3, verify the code enforces it
- [ ] For each state transition, verify all preconditions are checked
- [ ] For each math operation, verify precision/rounding direction is correct
- [ ] For each fee calculation, verify it can't be gamed
- [ ] Walk through the "unhappy paths" — what happens when things fail?
- [ ] Check edge cases: zero amounts, max values, empty arrays, self-referencing

### 3.4 Calldata-Specific Deep Dive
- [ ] Test every external function with malformed calldata
- [ ] Test with short calldata (missing params)
- [ ] Test with extra trailing calldata
- [ ] Test with dirty address bits
- [ ] If multicall exists: test msg.value reuse, batch ordering attacks
- [ ] If proxy: test selector collisions, extra calldata propagation
- [ ] If cross-chain: test message replay, encoding ambiguity

### 3.5 Differential Review (If Upgrade/Fork)
**Use skill: `differential-review`**
- [ ] Diff against the base code (OpenZeppelin, Solmate, original protocol)
- [ ] Every modification is a potential vulnerability
- [ ] Check if modifications break assumptions of the original code
- [ ] Verify storage layout compatibility (for upgrades)

---

## Phase 4: Exploit Development & Validation

**Goal:** Prove your findings are real.

### 4.1 Proof of Concept
- [ ] Write a Foundry test that demonstrates the vulnerability
- [ ] Show the exact call sequence
- [ ] Quantify the impact (how much money at risk? who's affected?)
- [ ] Verify the PoC works against the actual codebase (not a simplified version)

### 4.2 Severity Classification
**Use skill: `audit-report-format`**

| Severity | Impact | Likelihood | Examples |
|----------|--------|------------|----------|
| **Critical** | Fund loss, protocol bricked | High (easy to execute) | Reentrancy draining vault, broken access control |
| **High** | Significant fund loss or protocol disruption | Medium-High | Oracle manipulation, flash loan attack |
| **Medium** | Limited fund loss or degraded functionality | Medium | Griefing, precision loss, edge case exploits |
| **Low** | Minor issues, theoretical risks | Low | Gas inefficiency, informational, best practices |
| **Info** | No direct risk | Observation | Code quality, documentation gaps |

**Impact × Likelihood matrix:**
```
              High Impact    Medium Impact    Low Impact
High Likeli.  CRITICAL       HIGH             MEDIUM
Med Likeli.   HIGH           MEDIUM           LOW
Low Likeli.   MEDIUM         LOW              INFO
```

### 4.3 Second Opinion
**Use skill: `second-opinion`**
- [ ] Challenge your own findings — is there a mitigation you missed?
- [ ] Check if the finding is a known accepted risk
- [ ] Verify the attack is economically viable (gas costs, capital requirements)
- [ ] Consider if the finding is a duplicate of another

---

## Phase 5: Property Testing & Formal Verification

**Goal:** Prove the ABSENCE of certain bug classes.

### 5.1 Invariant Testing
**Use skill: `property-based-testing`**
- [ ] Write invariant tests for core properties from Phase 1.3
- [ ] Fuzz with Foundry (`forge test --fuzz-runs 10000`)
- [ ] Use Echidna for deeper stateful fuzzing
- [ ] Use Medusa for parallel fuzzing

### 5.2 Formal Verification (If Warranted)
**Use skill: `formal-verification`**
- [ ] Identify highest-value properties to verify
- [ ] Write Certora CVL specs OR Halmos symbolic tests
- [ ] Verify mathematical invariants (token conservation, share price monotonicity)
- [ ] Verify access control properties (only admin can X)
- [ ] Verify state machine properties (can't skip states)

### 5.3 Fuzzing Calldata Specifically
**Use skill: `smart-contract-fuzzing`**
- [ ] Configure fuzzer to generate malformed calldata
- [ ] Fuzz multicall with random call sequences
- [ ] Fuzz proxy forwarding with varied calldata lengths
- [ ] Fuzz cross-chain message handlers with random payloads

---

## Phase 6: Report & Delivery

**Goal:** Communicate findings clearly and actionably.

**Use skill: `audit-report-format`**

### 6.1 Report Structure
1. **Executive Summary** — one paragraph for non-technical stakeholders
2. **Scope** — exact files, commit, chain, configuration
3. **Methodology** — what you did (reference this process)
4. **Findings** — each with Summary, Description, Impact, Likelihood, Code, Recommendation, PoC
5. **Systemic Observations** — patterns across findings, architectural concerns
6. **Gas Optimizations** — if in scope
7. **Appendix** — invariant test results, tool outputs, full PoC code

### 6.2 Quality Checks
- [ ] Every finding has a code reference (file + line)
- [ ] Every Critical/High has a PoC
- [ ] Recommendations are specific and implementable
- [ ] No false positives (double-checked each finding)
- [ ] Report is readable by a developer who hasn't seen the code

### 6.3 Delivery
- [ ] Share report with team
- [ ] Schedule walkthrough call for Critical/High findings
- [ ] Offer to review fixes (fix review pass)
- [ ] Document any findings accepted as known risks

---

## Skill Routing Guide

| What you're doing | Skills to load |
|---|---|
| Starting an audit | `e2e-audit-process` (this), `audit-context-building` |
| Mapping entry points | `entry-point-analyzer` |
| Hunting reentrancy | `reentrancy-audit`, `evm-execution-security` |
| Reviewing DeFi logic | `defi-attack-taxonomy`, protocol-specific expert skill |
| Checking oracles | `oracle-manipulation-audit` |
| Testing calldata | `calldata-attack-patterns` |
| Reviewing upgrades | `initialization-upgrade-audit`, `upgrades-admin-audit` |
| Writing invariant tests | `property-based-testing`, `formal-verification` |
| Running static analysis | `semgrep`, `codeql`, `scv-scan` |
| Writing the report | `audit-report-format` |
| Reviewing a PR/diff | `differential-review` |
| Investigating an exploit | `exploit-forensics`, `onchain-sleuthing` |
