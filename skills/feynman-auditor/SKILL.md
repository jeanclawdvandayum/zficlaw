---
name: feynman-auditor
description: Deep business logic bug finder using the Feynman technique. Language-agnostic — works on Solidity, Move, Rust, Go, C++, or any codebase. Questions every line, every ordering choice, every guard presence/absence, and every implicit assumption to surface logic bugs that pattern-matching misses. Use when doing deep logic review, hunting business logic bugs beyond pattern-matching, or after automated scans to find what patterns missed.
---

# Feynman Auditor

Business logic vulnerability hunter that finds bugs pattern-matching cannot. Uses the Feynman technique: if you cannot explain WHY a line exists, you do not understand the code — and where understanding breaks down, bugs hide.

**Language-agnostic.** Logic bugs live in the reasoning, not the syntax. Works on Solidity, Move, Rust, Go, C++, or anything else.

**Complements:** Use alongside `attack-vector-db` (pattern-matching) and `state-inconsistency-auditor` (coupled state). Feed verified findings through `finding-validation` before final report.

## When to Use

- Deep business logic bug hunting beyond pattern-matching
- After any automated scan to find what patterns missed
- When auditing novel/custom code (not forks of battle-tested libraries)
- As part of `nemesis-orchestrator` iterative loop

## When NOT to Use

- Quick pattern-matching scans (use `attack-vector-db`)
- Simple spec compliance checks
- Report generation from existing findings (use `audit-report-format`)

---

## Core Philosophy

```
"What I cannot create, I do not understand." — Feynman

Applied to auditing: If you cannot explain WHY a line of code exists,
in what order it MUST execute, and what BREAKS if it changes —
you have found where bugs hide.
```

Pattern matchers find KNOWN bug classes. This methodology finds UNKNOWN bugs by
questioning the developer's reasoning at every decision point.

---

## Core Rules

```
RULE 0: QUESTION EVERYTHING, ASSUME NOTHING
Never accept code at face value. Every line exists because a developer
made a decision. Your job is to question that decision.

RULE 1: EVIDENCE-BASED FINDINGS ONLY
Every finding must include:
- The specific line(s) of code
- The question that exposed the issue
- A concrete scenario proving the bug
- Why the current code fails in that scenario

RULE 2: COMPLETE COVERAGE
Analyze EVERY function in scope. Do not skip "simple" functions.
Business logic bugs hide in the code everyone assumes is correct.

RULE 3: NO PATTERN MATCHING
Do NOT fall back to pattern-matching ("this looks like reentrancy").
Reason from first principles about what this specific code does.

RULE 4: CROSS-FUNCTION REASONING
A line that is correct in isolation may be wrong in context.
Always consider how functions interact, call each other, and share state.
```

---

## Language Adaptation

Detect the language and adapt terminology:

| Concept | Solidity | Move | Rust | Go | C++ |
|---------|----------|------|------|----|-----|
| Module/unit | contract | module | crate/mod | package | class/namespace |
| Entry point | external/public fn | public fun | pub fn | Exported fn | public method |
| Access guard | modifier | access control (friend, visibility) | trait bound / #[cfg] | middleware / auth check | access specifier |
| Caller identity | msg.sender | &signer | caller param / Context | ctx / request.User | this / session |
| Error/abort | revert / require | abort / assert! | panic! / Result::Err | error / panic | throw / exception |
| State storage | storage variables | global storage / resources | struct fields / state | struct fields / DB | member variables |
| Checked math | 0.8+ auto / SafeMath | built-in overflow abort | checked_add / saturating | math/big / overflow check | safe int libs |
| Value/assets | ETH, ERC-20, NFTs | APT, Coin\<T\>, tokens | SOL, SPL tokens, funds | any value type | any value type |

**IMPORTANT:** Do NOT force Solidity terminology onto non-Solidity code.

---

## The Feynman Question Framework

For **every function**, apply these 7 question categories systematically:

### Category 1: Purpose Questions (WHY is this here?)

```
Q1.1: Why does this line exist? What invariant does it protect?
      → If you cannot name the invariant, the line may be:
        (a) unnecessary, or (b) protecting something the dev forgot to document

Q1.2: What happens if I DELETE this line entirely?
      → Nothing breaks = dead code
      → Something breaks = you found what it protects
      → Something SHOULD break but doesn't = missing dependency

Q1.3: What SPECIFIC attack or edge case motivated this check?
      → If the dev added `require(amount > 0)`, what goes wrong at amount=0?
        Trace the zero/empty/max value through the entire function.

Q1.4: Is this check SUFFICIENT for what it's trying to prevent?
      → `amount > 0` doesn't prevent dust/minimum-value griefing
      → `caller == owner` doesn't prevent owner key compromise
      → Bounds check doesn't prevent off-by-one within the bounds
```

### Category 2: Ordering Questions (WHAT IF I MOVE THIS?)

```
Q2.1: What if this line executes BEFORE the line above it?
      → Would a different ordering allow state manipulation?
      → Validate-then-act violations: reading state, making external call,
        THEN updating state allows re-entry with stale state.

Q2.2: What if this line executes AFTER the line below it?
      → Does delaying create a window of inconsistent state?
      → Can an external call/callback between these lines exploit the gap?

Q2.3: What is the FIRST line that changes state? What is the LAST line
      that reads state? Is there a gap between them?

Q2.4: If this function ABORTS HALFWAY through, what state is left behind?
      → Side effects that persist despite abort? (external calls, events, writes)
      → Can an attacker intentionally trigger partial execution?

Q2.5: Can the ORDER in which users call this function matter?
      → Front-running / race conditions: does calling first give advantage?
      → Blockchain: two calls in the same block/transaction?
```

### Category 3: Consistency Questions (WHY does A have it but B doesn't?)

```
Q3.1: If functionA has an access guard and functionB doesn't, WHY?
      → List ALL functions that modify the same state
      → Every function touching the same storage should have
        consistent access control unless there's an explicit reason

Q3.2: If deposit() checks X, does withdraw() also check X?
      → Pair analysis: deposit/withdraw, stake/unstake, lock/unlock,
        mint/burn, open/close, borrow/repay, add/remove,
        register/deregister, create/destroy, encode/decode
      → The inverse operation must validate at least as strictly

Q3.3: If functionA validates parameter P, does functionB (which also
      takes P) validate it?

Q3.4: If functionA emits an event, does functionB (doing similar work)
      also emit one?

Q3.5: If functionA uses overflow-safe arithmetic, does functionB?
```

### Category 4: Assumption Questions (WHAT IS IMPLICITLY TRUSTED?)

```
Q4.1: What does this function assume about THE CALLER?
      → Who can call this? Is that enforced or just assumed?
      → Solidity: EOA vs contract vs proxy vs address(0)
      → What if the caller IS the system itself? (self-calls, recursion)

Q4.2: What does this function assume about EXTERNAL DATA it receives?
      → Tokens: standard behavior? Fee-on-transfer? Rebasing? Unusual decimals?
      → Return false silently? (pre-SafeERC20 patterns)

Q4.3: What does this function assume about the current state?
      → "This will never be called when paused" — but IS it enforced?
      → "Balance will always be sufficient" — but who guarantees that?
      → "This was already initialized" — but what if it wasn't?

Q4.4: What does this function assume about TIME or ORDERING?
      → Block timestamp manipulation (~15s on Ethereum)
      → What if deadline has already passed? What if time = 0?

Q4.5: What does this function assume about PRICES, RATES, or EXTERNAL VALUES?
      → Can the value be manipulated within the same transaction?
      → Is the data source fresh? What if the oracle is stale or dead?
      → What if the value is 0? MAX_VALUE?
      → Precision differences between source and consumer?

Q4.6: What does this function assume about INPUT AMOUNTS or SIZES?
      → What if amount = 0? amount = 1 (dust)? amount = MAX?
      → What if a collection is empty? Has millions of entries?
```

### Category 5: Boundary & Edge Case Questions

```
Q5.1: What happens on the FIRST call? (Empty state)
      → First depositor: division by zero when total = 0?
      → Share/ratio inflation when pool is empty?

Q5.2: What happens on the LAST call? (Draining/exhaustion)
      → Last withdraw that empties everything
      → Remaining dust that can never be extracted?
      → Rounding traps value permanently?

Q5.3: What if called TWICE in rapid succession?
      → Re-initialization, double-spending, double-counting
      → Two calls in the same block/transaction

Q5.4: What if two DIFFERENT functions are called in the same context?
      → Borrow in funcA, manipulate in funcB, repay in funcA
      → Cross-function interaction break invariants?

Q5.5: What if called with THE SYSTEM ITSELF as a parameter?
      → Self-referential: transfer to self, compare with self
      → Circular references or recursive structures?
```

### Category 6: Return Value & Error Path Questions

```
Q6.1: What does this function return? Who consumes the return value?
      → If caller ignores return value, what's lost?
      → Solidity: low-level call returns bool — often unchecked

Q6.2: What happens on the ERROR/ABORT path?
      → Side effects before the error?
      → Can an attacker cause targeted errors (griefing/DoS)?

Q6.3: What if an EXTERNAL CALL fails silently?
      → Solidity: low-level call returns (bool, bytes) — often unchecked
      → Does the language guarantee failure propagation?

Q6.4: Is there a code path where NO return and NO error happens?
      → Functions falling through without explicit return
      → Solidity: functions can fall through returning zero values
```

### Category 7: External Call Reordering & Multi-Transaction State Analysis

#### Part A: External Call Reordering (within a single transaction)

```
Q7.1: If the function performs an external call BEFORE a state update,
      what happens if I SWAP them?
      → If swap causes revert: ORIGINAL ordering may be exploitable
      → If swap works cleanly: original is likely safe, OR swap reveals
        the intended safe ordering was never enforced

Q7.2: For EVERY external call, ask:
      "What can the CALLEE do with the current state at THIS exact moment?"
      → What state is committed vs pending at the call point?
      → Can callee re-enter and see inconsistent state?
      → Can callee call a DIFFERENT function reading not-yet-updated state?

Q7.3: What is the MINIMAL set of state that MUST be updated before each
      external call to prevent exploitation?
      → If ANY are updated AFTER the external call, flag it
```

#### Part B: Multi-Transaction State Corruption (across time)

```
Q7.4: If a user calls this function with value X, then AGAIN with value Y —
      does the second call behave correctly given state changes from the first?
      → deposit(100), then deposit(50): shares/accounting correct when
        totalSupply is no longer 0?
      → borrow(1000), then borrow(500): checks against UPDATED debt?

Q7.5: Does accumulated state from MULTIPLE calls create a condition that
      a SINGLE call can never reach?
      → Rounding errors that compound (each call loses 1 wei)
      → Monotonically growing state hitting ceiling/overflow
      → Reward/rate staleness from infrequent updates
      → State fragmentation blocking future operations (1 wei of remaining debt)

Q7.6: Can an attacker craft a SEQUENCE of transactions to reach a state
      that no single "normal" path would produce?
      → Deposit-borrow-withdraw-liquidate sequences leaving bad debt
      → Stake-unstake-restake sequences compounding rounding errors
      → The attacker CHOOSES order, amounts, and timing
```

**WORKED EXAMPLE — Fee Accumulator Path-Dependency:**

AMM pool swap() that: (1) calculates amountOut, (2) updates accumulatedFees, (3) updates reserves.

If fees are added to accumulator BEFORE reserves update, each swap changes what "1 unit of fee" means, but the accumulator treats all units as equal. After many swaps, fee distribution skews: early LPs overpaid, late LPs underpaid.

**Generalize:** Any global accumulator (fees, rewards, interest) updated per-tx where the VALUE of what's accumulated changes between txs, and the accumulator doesn't normalize/rebase.

---

## Execution Process

### Phase 0: Attacker Mindset (BEFORE reading code)

```
Q0.1: What's the WORST thing an attacker can do here?
      → List top 3-5 catastrophic outcomes. These become ATTACK GOALS.

Q0.2: What parts are NOVEL? (Not forks of battle-tested code)
      → Custom math, novel mechanisms, unique state machines = highest bug density.

Q0.3: Where does VALUE actually sit?
      → Map every module holding funds, assets, accounting state.
      → For each: what code path moves value OUT? What authorizes it?

Q0.4: What's the most COMPLEX interaction path?
      → Paths crossing 4+ modules with 3+ external calls = prime targets.
```

**Output:** Attacker's Hit List with priority targets.

### Phase 1: Scope & Inventory

```
1. Identify ALL modules/contracts in scope
2. For each, list:
   - ALL entry points (external/public functions)
   - ALL state they read/write
   - ALL access guards applied
   - ALL internal functions they call
3. Build FUNCTION-STATE MATRIX:
   | Function | Reads | Writes | Guards | Calls |
```

### Phase 2: Individual Function Deep Dive

For EACH function (priority order from Phase 0), apply question categories:

```
┌─────────────────────────────────────────────────────┐
│ FUNCTION: [module.functionName]                      │
│ Visibility | Guards | State reads | State writes     │
├─────────────────────────────────────────────────────┤
│ LINE-BY-LINE INTERROGATION:                          │
│ L[N]: [code line]                                    │
│   Q[x.y] → [answer]                                 │
│   → VERDICT: SOUND | SUSPECT | VULNERABLE            │
│   → If SUSPECT: [specific scenario]                  │
│                                                      │
│ FUNCTION VERDICT: SOUND | HAS_CONCERNS | VULNERABLE  │
└─────────────────────────────────────────────────────┘
```

**Use judgment on which questions per line:**
- State-changing lines → Q2 (ordering) and Q4 (assumptions)
- Validation/guard lines → Q1 (purpose) and Q3 (consistency)
- External calls → Q4 (assumptions), Q5 (edges), Q6 (returns), Q7 (reordering)
- Math operations → Q5 (boundaries) and Q4.6 (amount assumptions)

### Phase 3: Cross-Function Analysis

Using the Function-State Matrix:

```
1. GUARD CONSISTENCY: Group functions by state they WRITE. 
   Flag missing guards.

2. INVERSE OPERATION PARITY: Pair deposit/withdraw, mint/burn, etc.
   Compare validation, state changes, access control, events.

3. STATE TRANSITION INTEGRITY: Map all valid transitions.
   Can they be triggered out of order, skipped, or by unauthorized actors?

4. VALUE FLOW TRACKING: Trace value across function boundaries.
   Verify conservation: value in == value out.
```

### Phase 4: Synthesize Raw Findings

Save raw (unverified) findings to: `.audit/findings/feynman-analysis-raw.md`

### Phase 5: Verification Gate (MANDATORY)

**Every CRITICAL, HIGH, and MEDIUM finding MUST be verified.**

Pass all findings through `finding-validation` skill's FP Gate:
1. Concrete Attack Path — can you trace caller → function → state change → loss?
2. Reachable Entry Point — can the attacker actually call this?
3. No Existing Guard — no code already prevents this?

**Verification Methods:**

| Severity | Required | Method |
|----------|----------|--------|
| CRITICAL | PoC required | Foundry test demonstrating value loss with concrete numbers |
| HIGH | Code trace + PoC recommended | Confirm broken invariant is reachable |
| MEDIUM | Code trace minimum | Confirm mechanism is correct and not mitigated |
| LOW | Code inspection | Quick sanity check |

**Common False Positive Patterns:**
1. "Missing authorization" that exists in a different layer
2. "Rounding drift" cleaned by downstream code
3. "No validation" that errors in called function
4. "Unbounded loop" bounded by design or economics
5. "Severity inflation" — claims CRITICAL but actually MEDIUM
6. "Language safety ignored" — claims overflow in Solidity ≥0.8

Save verified findings to: `.audit/findings/feynman-verified.md`

**Only present verified findings as the final report.**

---

## Output Format

```markdown
# Feynman Audit — Verified Findings

## Scope
- Language: [detected]
- Modules analyzed: [list]
- Functions analyzed: [count]

## Function-State Matrix
[Matrix from Phase 1]

## Verified Findings

### Finding FF-001: [Title]
**Severity:** CRITICAL | HIGH | MEDIUM | LOW
**Verification:** [Code trace / PoC / Hybrid]

**Feynman Question that exposed this:**
> [The exact question]

**The code:**
```[language]
// [affected code]
```

**Why this is wrong:**
[First-principles explanation]

**Attack scenario:**
1. [Step-by-step]

**Impact:** [What breaks]

**Fix:**
```[language]
// [minimal fix]
```

## False Positives Eliminated
[What failed verification and why]

## Summary
- Raw findings: [N] C | [N] H | [N] M | [N] L
- After verification: [N] TRUE POSITIVE | [N] FALSE POSITIVE
- Final: [N] HIGH | [N] MEDIUM | [N] LOW
```

---

## Anti-Hallucination Protocol

```
NEVER:
- Invent code that doesn't exist in the codebase
- Assume a function has an access guard without verifying
- Report a finding without showing the exact vulnerable code
- Use phrases like "could potentially" or "might be vulnerable"
- Apply Solidity assumptions to non-Solidity code

ALWAYS:
- Read the actual code before questioning it
- Verify assumptions by reading called functions
- Check constructors, initializers, and default values
- Show exact file paths and line numbers
```

---

## Attribution

Methodology adapted from [nemesis-auditor](https://github.com/0xiehnnkta/nemesis-auditor) by 0xiehnnkta (MIT License), with integration into our audit skill ecosystem.
