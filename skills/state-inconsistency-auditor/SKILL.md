---
name: state-inconsistency-auditor
description: Finds state inconsistency bugs where an operation mutates one piece of coupled state without updating its dependent counterpart, causing silent data corruption or reverts in subsequent operations. Use when hunting stale state, broken invariants, desynchronized storage, or coupled state audit.
---

# State Inconsistency Auditor

Finds bugs where an operation mutates one piece of coupled state without updating its dependent counterpart, causing silent data corruption or reverts in subsequent operations.

**Language-agnostic.** Coupled state bugs exist in any system that maintains related storage values.

**Complements:** Use alongside `feynman-auditor` (first-principles logic) and `attack-vector-db` (pattern-matching). Feed verified findings through `finding-validation` before final report.

## When to Use

- Hunting stale state, broken invariants, or desynchronized storage
- Auditing any system with coupled accounting (shares/balances, debt/collateral, rewards/stakes)
- After any other audit methodology to catch structural state desync bugs
- As part of `nemesis-orchestrator` iterative loop

## When NOT to Use

- First-principles logic bugs only (use `feynman-auditor`)
- Quick pattern-matching scans (use `attack-vector-db`)
- Report generation from existing findings

---

## The Abstract Pattern

Every system has **COUPLED STATE PAIRS** — two or more storage values that must maintain a relationship (an invariant). When any operation changes one side without adjusting the other, the invariant breaks. Future operations that read both values produce incorrect results.

**Examples of coupled state:**
- balance & checkpoint
- position size & accumulated tracker
- collateral & obligation/debt
- voting power & snapshot
- shares & any per-share derived value
- principal & any cumulative index
- totalSupply & sum of all individual balances
- debt & interest accumulator
- liquidity & fee growth trackers
- stake amount & reward debt
- token balance & voting delegation
- position collateral & health factor cache

**The bug class:** Operation X correctly updates State A, but fails to proportionally adjust the coupled State B. State B is now stale relative to State A.

---

## Core Rules

```
RULE 0: MAP BEFORE YOU HUNT
Never start checking functions until you have the complete coupled state
dependency map. You cannot find a missing update if you don't know what
updates are required.

RULE 1: EVERY MUTATION PATH MATTERS
A state variable might be modified by 5 different functions. ALL 5 must
update the coupled state. If 4 do and 1 doesn't — that's the bug.

RULE 2: PARTIAL OPERATIONS ARE THE #1 SOURCE
Full removals usually reset all state correctly.
Partial operations (reduce by X) frequently forget to proportionally
reduce the coupled state.

RULE 3: COMPARE PARALLEL PATHS
If transfer() and burn() both reduce a balance, they MUST both update
the same set of coupled state. If one does and the other doesn't → finding.

RULE 4: DEFENSIVE CODE MASKS BUGS
Code like `x > y ? x - y : 0` or `min(computed, available)` silently
hides broken invariants. These are red flags, not safety nets.

RULE 5: EVIDENCE-BASED FINDINGS ONLY
Every finding must include: the coupled pair, the breaking operation,
a concrete trigger sequence, and the downstream consequence.
```

---

## Audit Process

### Phase 1: Map All Coupled State Pairs

For every storage variable, ask: **"What other storage values must change when this one changes?"**

Build a dependency map:

```
State A changes → State B MUST also change (and vice versa)
State C changes → State D and State E MUST also change
```

Look for:
- Any per-user value paired with any per-user accumulator/tracker
- Any balance paired with any historical snapshot or checkpoint
- Any numerator paired with its denominator
- Any position-describing value paired with any position-derived value
- Anything stored at time T later used with a value from time T+1
- Any total/aggregate paired with individual components that sum to it
- Any cached computation paired with the inputs it was derived from
- Any index/accumulator paired with the last-known snapshot of that index

**Output:** Coupled State Dependency Map.

```
┌─────────────────────────────────────────────────────────────┐
│ COUPLED STATE DEPENDENCY MAP                                 │
├─────────────────────────────────────────────────────────────┤
│ PAIR 1: userBalance[user] ↔ checkpoint[user]                 │
│   Invariant: checkpoint must reflect balance at last update  │
│   Mutation points: deposit(), withdraw(), transfer(), burn() │
│                                                              │
│ PAIR 2: totalStaked ↔ rewardPerTokenStored                   │
│   Invariant: rewardPerToken must be updated before           │
│              totalStaked changes                             │
│   Mutation points: stake(), unstake(), emergencyWithdraw()   │
└─────────────────────────────────────────────────────────────┘
```

### Phase 2: Find Every Mutation Path

For EACH state variable from Phase 1, list **every** function and code path that modifies it:

- **Direct writes:** `state = newValue`
- **Increments/decrements:** `state += delta`
- **Deletions:** `delete state`, `state = 0`
- **Indirect mutations:** calling `_mint()`, `_burn()`, `_transfer()` internally
- **Implicit changes:** rebasing, burns via internal paths
- **Batch operations:** loops or multicalls modifying state multiple times
- **External triggers:** callbacks, hooks, oracle updates as side effects

**Output:** Mutation Matrix.

```
┌──────────────────┬───────────────────┬───────────────────────────┐
│ State Variable   │ Mutating Function │ Updates Coupled State?    │
├──────────────────┼───────────────────┼───────────────────────────┤
│ userBalance[u]   │ deposit()         │ ✓ checkpoint updated      │
│ userBalance[u]   │ withdraw()        │ ✓ checkpoint updated      │
│ userBalance[u]   │ transfer()        │ ??? — CHECK THIS          │
│ userBalance[u]   │ liquidate()       │ ??? — CHECK THIS          │
└──────────────────┴───────────────────┴───────────────────────────┘
```

The `???` entries are your **primary audit targets**.

### Phase 3: Cross-Check — The Core Audit

For EVERY (operation, state variable) pair from Phase 2:

> "This operation modifies State A. Does it ALSO update every coupled state that depends on A?"

Check specifically:

```
□ Full removal (A → 0): Is every coupled state reset/cleared?
□ Partial removal (A decreases): Is coupled state proportionally reduced?
□ Increase (A grows): Is coupled state proportionally increased?
□ Transfer (A moves between entities): Is coupled state moved too?
□ Deletion (mapping entry removed): Is paired mapping entry also removed?
□ Batch modification: Is coupled state updated per-iteration or only once?
```

**If ANY path updates A without updating its coupled state → FINDING.**

For each potential finding, trace the FULL code path:
1. Read the function that modifies State A
2. Search for any write to State B within the same function
3. Search for any internal call that writes to State B
4. Search for any modifier/hook that writes to State B
5. If none found → confirmed finding

### Phase 4: Check Operation Ordering Within Functions

Trace exact order of state changes:

```
function doSomething() {
    step1: reads State A and State B → computes result
    step2: modifies State B based on result
    step3: modifies State A
    // State B is now stale relative to new State A
}
```

At each step ask:
- "After this step, are ALL coupled pairs still consistent?"
- "Does step N use a value that step N-1 already invalidated?"
- "If an external call happens between steps, can callee observe inconsistent state?"

**Common ordering bugs:**
- Claim rewards BEFORE reducing stake → rewards computed on old (higher) stake
- Update index AFTER modifying supply → index uses stale supply
- Read cached price AFTER changing position → health check uses wrong price

### Phase 5: Compare Parallel Code Paths

Find operations achieving similar outcomes through different paths:

- `transfer()` vs `burn()` — both reduce sender balance
- `withdraw()` vs `liquidate()` — both reduce position
- `partial` vs `full` removal
- Normal path vs emergency/admin path
- Single vs batch operation

For each group, compare: **do ALL paths update the same coupled state?**

```
┌─────────────────┬──────────────┬──────────────┬────────────┐
│ Coupled State   │ withdraw()   │ liquidate()  │ emergencyW │
├─────────────────┼──────────────┼──────────────┼────────────┤
│ balance         │ ✓ updated    │ ✓ updated    │ ✓ updated  │
│ checkpoint      │ ✓ updated    │ ✗ MISSING    │ ✗ MISSING  │
│ rewardDebt      │ ✓ updated    │ ✗ MISSING    │ ✗ MISSING  │
└─────────────────┴──────────────┴──────────────┴────────────┘
```

**If Path A adjusts coupled state but Path B doesn't → FINDING.**

### Phase 6: Trace Multi-Step User Journeys

Simulate sequences where a user interacts multiple times:

```
1. User enters position (state initialized)
2. Time passes / external state evolves
3. User does PARTIAL modification (coupled state may break here)
4. More time passes
5. User does another operation reading the coupled state
```

At step 5: Is the coupled state still valid given partial change at step 3?

**Key sequences to test:**
- Deposit → partial withdraw → claim rewards
- Stake → unstake half → restake → unstake all
- Open position → add collateral → partial close → check health
- Delegate votes → transfer tokens → vote
- Provide liquidity → swap happens → remove liquidity

### Phase 7: Check What Masks the Bug

Look for defensive code that HIDES broken invariants:

```
MASKING PATTERN 1: Ternary clamp
  x > y ? x - y : 0
  → WHY would x ever be less than y? If invariant held, it wouldn't.

MASKING PATTERN 2: Try/catch swallowing
  try target.call() {} catch {}
  → Revert from broken state is caught and ignored.

MASKING PATTERN 3: Early exit on zero
  if (value == 0) return;
  → Skips computation when broken state produces zero.

MASKING PATTERN 4: Min cap
  min(computed, available)
  → Caps result when broken state over-counts. Over-counting IS the bug.

MASKING PATTERN 5: SafeMath without root cause
  → Prevents underflow revert but doesn't fix WHY it would underflow.

MASKING PATTERN 6: Fallback to default
  value = mapping[key]  // returns 0 for non-existent key
  → If key SHOULD exist but was deleted without cleaning coupled entry.
```

**These convert loud failures into silent ones.** The invariant is still broken — the symptom is just suppressed.

### Phase 8: Verification Gate (MANDATORY)

**Every C/H/M finding MUST be verified.**

Pass findings through `finding-validation` skill, then:

**Method A: Code Trace Verification**
1. Read exact function that breaks invariant
2. Trace every internal call — confirm no hidden update to coupled state
3. Check modifiers, hooks, base class overrides
4. Confirm no lazy reconciliation exists

**Method B: PoC Test Verification**
1. Write test in project's native framework
2. Execute trigger sequence from finding
3. Assert coupled state is inconsistent after breaking operation
4. Assert subsequent operation produces incorrect results

**Common False Positive Patterns:**
1. **Hidden reconciliation**: Updated through internal call chain you missed (e.g., `_beforeTokenTransfer` hook)
2. **Lazy evaluation**: Intentionally stale, reconciled on next read (e.g., `_updateReward()` modifier)
3. **Immutable after init**: Set once, never needs updating
4. **Designed asymmetry**: Intentionally NOT coupled the way you assumed

---

## Red Flags Checklist

```
- [ ] Function modifies base value but has no writes to its coupled state
- [ ] Two similar operations handle coupled state differently
- [ ] Claim/collect runs before reduce/remove with no reconciliation
- [ ] Partial operation exists but only full operation resets coupled state
- [ ] Defensive ternary/min() between two coupled values
- [ ] delete/reset of one mapping but not its paired mapping
- [ ] Loop accumulates into shared state without per-iteration adjustment
- [ ] Emergency/admin function bypasses normal state update path
- [ ] Migration/upgrade copies State A but not State B
- [ ] Callback/hook modifies State A without caller updating State B
```

---

## Severity Classification

| Severity | Criteria |
|----------|----------|
| **CRITICAL** | Coupled state desync causes direct value loss (wrong payouts, stolen funds, permanent lock) |
| **HIGH** | Desync causes conditional value loss or broken core functionality |
| **MEDIUM** | Desync causes incorrect accounting, griefing, or degraded functionality |
| **LOW** | Desync causes cosmetic issues, event inaccuracy, or edge-case-only errors |

---

## Output Format

Save raw findings to: `.audit/findings/state-inconsistency-raw.md`
Save verified findings to: `.audit/findings/state-inconsistency-verified.md`

```markdown
# State Inconsistency Audit — Verified Findings

## Coupled State Dependency Map
[Map from Phase 1]

## Mutation Matrix
[Matrix from Phase 2]

## Parallel Path Comparison
[Table from Phase 5]

## Verified Findings

### Finding SI-001: [Title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Verification:** [Code trace / PoC / Hybrid]

**Coupled Pair:** State A ↔ State B
**Invariant:** [What relationship must hold]

**Breaking Operation:** `functionName()` at `Contract.sol:L123`
- Modifies State A: [how]
- Does NOT update State B: [what's missing]

**Trigger Sequence:**
1. [Step-by-step to break invariant]

**Consequence:**
- [What goes wrong when later operation reads both A and B]
- [Concrete impact]

**Masking Code** (if present):
```[language]
// This hides the broken invariant:
[code]
```

**Fix:**
```[language]
// Add missing state synchronization:
[minimal fix]
```

## False Positives Eliminated
[What failed verification and why]

## Summary
- Coupled pairs mapped: [N]
- Mutation paths analyzed: [N]
- Raw findings: [N] | After verification: [N] TRUE POSITIVE
- Final: [N] CRITICAL | [N] HIGH | [N] MEDIUM | [N] LOW
```

---

## Anti-Hallucination Protocol

```
NEVER:
- Assume two states are coupled without verifying they are read together
- Claim a function is missing an update without reading its full call chain
- Report a finding without showing exact code that breaks the invariant
- Ignore lazy-evaluation patterns (modifiers that reconcile on entry)

ALWAYS:
- Read actual storage declarations to understand types and relationships
- Trace internal calls to check for hidden updates
- Check _before/_after hooks and modifiers for reconciliation logic
- Verify coupled relationship by finding code that reads BOTH values together
- Show exact file paths and line numbers
```

---

## Attribution

Methodology adapted from [nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) by 0xiehnnkta (MIT License), with integration into our audit skill ecosystem.
