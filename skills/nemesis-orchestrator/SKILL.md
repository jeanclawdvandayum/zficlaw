---
name: nemesis-orchestrator
description: "The Inescapable Auditor. Runs the full Feynman Auditor and full State Inconsistency Auditor as primary passes, then fuses their outputs in an iterative feedback loop to find bugs at the intersection that neither alone would catch. Language-agnostic. Use for maximum-depth combined audit coverage on complex codebases."
---

# N E M E S I S — The Inescapable Auditor

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   Your code was written with confidence.                      ║
║   Nemesis questions that confidence.                          ║
║   Then maps what your confidence forgot to protect.           ║
║   Then questions it again.                                    ║
║                                                               ║
║   Nothing survives both passes.                               ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

Not sequential stages. An **iterative back-and-forth loop** where Feynman and State Inconsistency run alternating passes — each informed by the previous — until no new bugs surface.

**Requires:** `feynman-auditor` and `state-inconsistency-auditor` skills.
**Integrates with:** `attack-vector-db` (pattern sweep before/after), `finding-validation` (all findings), `audit-report-format` (final deliverable).

## When to Use

- Maximum-depth business logic + state inconsistency coverage
- Complex codebases where either auditor alone would miss cross-cutting bugs
- Novel DeFi protocols with custom accounting (shares, rewards, debt, indices)

## When NOT to Use

- Quick scans (use `attack-vector-db` alone)
- Simple contracts with no coupled state
- Report generation from existing findings

---

## The Iterative Loop

```
Pass 1 (Feynman) — Full feynman-auditor skill run.
  Every line questioned. Every ordering challenged. Every assumption exposed.
  Output: findings + suspects + exposed assumptions + Function-State Matrix

        ↓ feed forward

Pass 2 (State) — Full state-inconsistency-auditor skill run, ENRICHED by Pass 1.
  Feynman suspects → extra audit targets.
  Exposed assumptions → reveal new coupled pairs.
  Output: findings + gaps + new coupled pairs + masking code

        ↓ feed back

Pass 3 (Feynman) — TARGETED re-interrogation of Pass 2's new items only.
  For each State GAP: "WHY is this sync missing? What assumption led to it?"
  For each MASKING CODE: "WHY would this underflow? What invariant is broken?"
  Output: new findings + root cause analysis

        ↓ feed back

Pass 4 (State) — TARGETED re-analysis of Pass 3's new items only.
  New suspects → new coupled pairs?
  Root causes → affect other coupled pairs?
  Output: additional gaps or convergence

        ↓ continue alternating until convergence (max 6 total passes)
```

---

## Core Rules

```
RULE 0: THE ITERATIVE LOOP IS MANDATORY
Never run Feynman and State as isolated one-shots.
They MUST alternate. Each pass feeds the next.

RULE 1: FULL FIRST, TARGETED AFTER
Pass 1 (Feynman) and Pass 2 (State) are FULL skill runs.
Pass 3+ are TARGETED — only audit the delta from previous pass.

RULE 2: EVERY COUPLED PAIR GETS INTERROGATED
State finds pairs. Feynman interrogates each one:
"Why are these coupled? Is the invariant maintained by ALL mutation paths?"

RULE 3: EVERY SUSPECT GETS STATE-TRACED
When Feynman flags a SUSPECT, State traces every state variable that line
touches and checks if the suspicion propagates to coupled dependencies.

RULE 4: PARTIAL OPERATIONS + ORDERING = GOLD
The intersection of "partial state change" (State's specialty) and
"operation ordering" (Feynman's Category 2 & 7) is where the highest-value
bugs live.

RULE 5: DEFENSIVE CODE IS A SIGNAL
When State finds masking code, Feynman interrogates WHY it exists.
The mask reveals the invariant that's actually broken underneath.

RULE 6: EVIDENCE OR SILENCE
No finding without: coupled pair, breaking operation, trigger sequence,
downstream consequence, and verification.
```

---

## Execution Pipeline

### Phase 0: Attacker Recon

Combine Feynman's attacker mindset with State's value tracking:

```
Q0.1: ATTACK GOALS — What's the WORST an attacker can achieve?
Q0.2: NOVEL CODE — What's NOT a fork of battle-tested code?
Q0.3: VALUE STORES — Where does value sit? What moves it OUT?
Q0.4: COMPLEX PATHS — What crosses 4+ modules with 3+ external calls?
Q0.5: COUPLED VALUE — Which value stores have DEPENDENT accounting?
      (For each value store: "What other storage must stay in sync?")
```

**Output:** Attacker's Hit List + Initial Coupling Hypothesis

### Phase 1: Dual Mapping

Run both mapping operations simultaneously:

**1A: Function-State Matrix** (Feynman foundation)
```
| Function | Reads | Writes | Guards | Internal Calls | External Calls |
```

**1B: Coupled State Dependency Map** (State foundation)
```
State A changes → State B MUST change (invariant: [relationship])
```

**1C: Cross-Reference** (THE NEMESIS DIFFERENCE)
```
Overlay the two maps:
For each COUPLED PAIR → find ALL functions that WRITE to either side
Mark which functions update BOTH sides vs only ONE side
Functions updating only ONE side = PRIMARY AUDIT TARGETS
```

**Output:** Unified Nemesis Map

```
┌───────────────┬──────────┬──────────┬──────────┬──────────────────┐
│ Function      │ Writes A │ Writes B │ A↔B Pair │ Sync Status      │
├───────────────┼──────────┼──────────┼──────────┼──────────────────┤
│ deposit()     │ ✓        │ ✓        │ bal↔chk  │ ✓ SYNCED         │
│ withdraw()    │ ✓        │ ✓        │ bal↔chk  │ ✓ SYNCED         │
│ transfer()    │ ✓        │ ✗        │ bal↔chk  │ ✗ GAP            │
│ liquidate()   │ ✓        │ ✗        │ bal↔chk  │ ✗ GAP            │
└───────────────┴──────────┴──────────┴──────────┴──────────────────┘
```

### Phase 2: Feynman Interrogation (Hunt Pass 1)

Apply ALL 7 Feynman Question Categories (from `feynman-auditor` skill) to every function in priority order.

Feed forward: Every SUSPECT verdict and every state variable touched by suspect code → Phase 3.

### Phase 3: State Cross-Check (Hunt Pass 2)

Run full State Inconsistency analysis (from `state-inconsistency-auditor` skill), ENRICHED by Feynman's Phase 2 output:
- Feynman SUSPECTS → extra audit targets in Mutation Matrix
- Exposed assumptions → reveal NEW coupled pairs
- Ordering concerns → check if state gap exists at flagged point
- Function-State Matrix → use as base for Mutation Matrix

### Phase 4: The Nemesis Loop (Feedback)

```
LOOP {
    STEP A: State gaps → Feynman re-interrogation
      For each GAP:
        "WHY doesn't [function] update [coupled state B]?"
        "What ASSUMPTION led to this gap?"
        "What DOWNSTREAM function reads B and breaks?"
        "Can an attacker CHOOSE a sequence to exploit this gap?"

    STEP B: Feynman findings → State dependency expansion
      For each SUSPECT/VULNERABLE:
        "Does this line WRITE to a state part of an unmapped coupled pair?"
        "Does the ordering concern create a WINDOW of inconsistency?"

    STEP C: Masking code → Joint interrogation
      Feynman: "WHY would this underflow? What invariant is broken?"
      State:   "Which coupled pair's desync is this mask hiding?"

    STEP D: Convergence check
      New findings/pairs/suspects → loop back
      No new items → converged. Proceed to Phase 5.

    SAFETY: Maximum 3 loop iterations.
}
```

### Phase 5: Multi-Transaction Journey Tracing

Trace adversarial sequences that exploit findings from BOTH dimensions:

**Always test:**
- Deposit → partial withdraw → claim rewards (rewards on which balance?)
- Stake → unstake half → restake → unstake all (reward debt correct?)
- Open position → add collateral → partial close → health check
- Provide liquidity → swaps happen → remove liquidity (fee tracking?)
- Delegate votes → transfer tokens → vote (voting power current?)
- Borrow → partial repay → borrow again → check debt (interest rebased?)

### Phase 6: Verification Gate (MANDATORY)

**Every C/H/M finding MUST be verified** using `finding-validation` skill.

Methods: Deep Code Trace / PoC Test / Hybrid

**Common FP patterns from BOTH auditors:**
1. Hidden reconciliation (hook/modifier updates coupled state)
2. Lazy evaluation (stale by design, reconciled on read)
3. Immutable after init
4. Designed asymmetry
5. Language safety (overflow in Solidity ≥0.8)
6. Severity inflation
7. Economic infeasibility

### Phase 7: Final Report

Save to: `.audit/findings/nemesis-verified.md`

```markdown
# N E M E S I S — Verified Findings

## Scope
- Language: [detected]
- Modules analyzed: [list]
- Coupled state pairs mapped: [count]
- Nemesis loop iterations: [count]

## Nemesis Map (Phase 1 Cross-Reference)
[Unified map]

## Verification Summary
| ID | Source | Coupled Pair | Breaking Op | Severity | Verdict |
|----|--------|-------------|-------------|----------|---------|

## Verified Findings

### Finding NM-001: [Title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Source:** [Feynman-only / State-only / Feedback Loop Step X]
**Verification:** [Code trace / PoC / Hybrid]

**Coupled Pair:** State A ↔ State B
**Invariant:** [What must hold]

**Feynman Question that exposed it:**
> [Exact question]

**State Mapper gap that confirmed it:**
> [Mutation matrix entry]

**Breaking Operation:** `functionName()` at `File.sol:L123`
**Trigger Sequence:** [step-by-step]
**Consequence:** [concrete impact]
**Fix:** [minimal code fix]

## Feedback Loop Discoveries
[Findings that ONLY emerged from cross-feed — proving the loop's worth]

## False Positives Eliminated
[What failed and why]

## Summary
- Functions analyzed: [N]
- Coupled pairs mapped: [N]
- Loop iterations: [N]
- Feedback loop discoveries: [N] (found ONLY via cross-feed)
- Final: [N] CRITICAL | [N] HIGH | [N] MEDIUM | [N] LOW
```

---

## Red Flags Checklist (Combined)

```
FROM FEYNMAN:
- [ ] Line whose PURPOSE you cannot explain
- [ ] Ordering choice with no clear justification
- [ ] Guard on funcA missing from funcB (same state)
- [ ] Implicit trust about caller/data/state/time
- [ ] External call with state updates AFTER it
- [ ] Function behaves differently on 2nd call due to 1st call's state

FROM STATE:
- [ ] Function modifies A but has no writes to coupled B
- [ ] Two similar operations handle coupled state differently
- [ ] Claim/collect before reduce/remove with no reconciliation
- [ ] Partial op exists but only full op resets coupled state
- [ ] Defensive ternary/min() between coupled values
- [ ] Emergency/admin bypasses normal state update path

FROM THE LOOP:
- [ ] Feynman ordering concern + State gap in SAME function → compound
- [ ] State masking code + Feynman explains broken invariant → root cause
- [ ] Feynman assumption about freshness + State confirms staleness
- [ ] BOTH auditors flag SAME function from different angles → highest confidence
```

---

## Anti-Hallucination Protocol

```
NEVER:
- Skip the feedback loop (Phase 4) — highest-value bugs emerge there
- Present raw findings as verified results
- Assume coupled pairs without finding code that reads BOTH values
- Claim missing update without tracing full call chain

ALWAYS:
- Run the loop until convergence
- Verify ALL C/H/M findings
- Tag discovery path (Feynman-only / State-only / Cross-feed)
- Present ONLY verified findings
```

---

## Attribution

Methodology adapted from [nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) by 0xiehnnkta (MIT License), with integration into our audit skill ecosystem.
