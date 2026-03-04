---
name: finding-validation
description: Structured false-positive elimination and confidence scoring for security audit findings. Apply to every finding before including in a report. Provides a 3-check FP gate, confidence scoring with explicit deductions, and composability analysis. Use when validating audit findings, triaging scanner output, or finalizing a report.
---

# Finding Validation Framework

Every finding must pass the FP gate and receive a confidence score before it enters a report. This prevents the #1 problem with AI-assisted audits: reporting theoretical issues as real vulnerabilities.

---

## FP Gate (3 Checks — ALL Must Pass)

If any check fails, **drop the finding immediately**. Do not score it. Do not report it. Do not revisit it.

### Check 1: Concrete Attack Path

You can trace a specific path: `caller → function call → state change → loss/impact`.

```
✅ PASS: "Attacker calls deposit(0) → _updateShares() divides by zero → 
         share price set to type(uint256).max → attacker redeems for entire vault"

❌ FAIL: "The function might be vulnerable to reentrancy"
❌ FAIL: "If an admin were to set a bad parameter..."
❌ FAIL: "This could potentially lead to issues"
```

**Rules:**
- Evaluate what the code *allows*, not what the deployer *might choose*
- "Could" and "might" are not attack paths. Trace the exact call chain.
- If you can't write the Foundry test in your head, you don't have a concrete path.

### Check 2: Reachable Entry Point

The entry point is reachable by the attacker. Check:
- Is the function `external` or `public`?
- What modifiers gate it? (`onlyOwner`, `onlyRole`, access control)
- Is `msg.sender` validated?
- Is the function behind a timelock or governance vote?
- Can the attacker actually call this function?

```
✅ PASS: deposit() is external, no modifiers, anyone can call
✅ PASS: liquidate() requires position to be underwater — attacker can manipulate oracle first

❌ FAIL: setFee() is onlyOwner — admin privilege, not a vulnerability
❌ FAIL: _internalHelper() is internal — no external entry point reaches it with attack params
```

**Rules:**
- Privileged caller (owner/admin/multisig/governance) is not an attacker unless the finding is about privilege escalation
- Admin-can-rug is a centralization observation, not a vulnerability (unless there's a specific unexpected mechanism)

### Check 3: No Existing Guard

No existing code already prevents the attack.

```
✅ PASS: No slippage check on the swap output
✅ PASS: Reentrancy guard exists on deposit() but NOT on the callback path

❌ FAIL: nonReentrant modifier on the vulnerable function
❌ FAIL: require(amount > 0) prevents the zero-amount attack
❌ FAIL: SafeERC20.safeTransfer already handles return value
```

**Rules:**
- Read the ACTUAL code, not just the function signature
- Check inherited contracts and libraries
- Check if the guard is in a modifier vs inline
- Partial guards count — if the guard covers 99% of cases but not edge case X, that's a finding about edge case X specifically

---

## Confidence Scoring

Every finding that passes the FP gate starts at **100**. Apply all applicable deductions:

| Condition | Deduction | Example |
|-----------|-----------|---------|
| Privileged caller required | -25 | Only governance can trigger the path |
| Partial attack path (can't write exact PoC) | -20 | "The concept is sound but exact parameters unclear" |
| Self-contained impact (only attacker's funds) | -15 | Attacker can grief themselves but not others |
| Requires specific token behavior | -10 | Only exploitable with fee-on-transfer tokens |
| Requires external protocol state | -10 | Only works if oracle is stale for >1 hour |
| Requires specific block timing | -10 | Needs exact block.timestamp alignment |
| Economic viability uncertain | -10 | Attack costs more gas than the profit |
| Requires front-running | -5 | Needs to see and beat a pending transaction |

**Score interpretation:**
- **90-100**: Near-certain real vulnerability. Must include PoC.
- **80-89**: High confidence. Include PoC and fix.
- **75-79**: Confidence threshold. Include fix.
- **60-74**: Below threshold. Include description only, no fix.
- **Below 60**: Drop from report entirely.

---

## Severity Classification (Separate from Confidence)

Confidence = "is this real?" | Severity = "how bad is it?"

A finding can be high-confidence low-severity (definitely real, but only informational) or low-confidence high-severity (if real, it's catastrophic, but we're not sure it's exploitable).

| Severity | Definition |
|----------|------------|
| **Critical** | Direct fund loss without unusual preconditions. Protocol can be bricked. |
| **High** | Significant fund loss, requires specific but realistic conditions |
| **Medium** | Limited fund loss, degraded functionality, or griefing with real cost |
| **Low** | Theoretical risk, edge cases, minor issues |
| **Informational** | Code quality, best practices, no direct risk |

**Impact × Likelihood → Severity:**
```
              High Impact    Medium Impact    Low Impact
High Likeli.  CRITICAL       HIGH             MEDIUM
Med Likeli.   HIGH           MEDIUM           LOW
Low Likeli.   MEDIUM         LOW              INFO
```

---

## Do Not Report

These are never findings. Save everyone's time.

- Compiler warnings, linting issues, naming conventions, NatSpec gaps
- Gas micro-optimizations (unless they cause DoS)
- Owner/admin can set parameters — that's by design
- Missing event emissions (unless critical for off-chain monitoring)
- Centralization observations without a specific exploit mechanism
- "Admin could rug" without showing HOW beyond "they have the keys"
- Theoretical attacks requiring implausible preconditions (>50% token supply, corrupt sequencer, compromised compiler)

**Exception:** Common ERC20 behaviors ARE plausible preconditions:
- Fee-on-transfer tokens
- Rebasing tokens
- Tokens with blacklists/pausing
- Tokens with callbacks (ERC777, ERC1155)
- Tokens that revert on zero transfer

If the contract accepts arbitrary tokens, these are valid attack surfaces.

---

## Composability Check

After validating individual findings, check if any two findings compound:

```
Example compounds:
- DoS on withdraw + admin can pause = permanent fund lock
- Oracle manipulation + undercollateralized borrow = leveraged drain  
- Reentrancy in callback + stale state read = double-spend
- Access control gap + uninitialized proxy = complete takeover
```

If findings compound, note the interaction in the higher-severity finding's description and escalate severity if warranted.

---

## Structured One-Liner Format

During triage, use this format for rapid pass/fail decisions:

```
V15: path: deposit() → _expandLock() → lockStart reset | guard: none | verdict: CONFIRM [85]
V22: path: deposit() → _distributeDepositFee() → token.transfer | guard: nonReentrant + require | verdict: DROP (FP gate 3: guarded)
V08: path: liquidate() → oracle.getPrice() → stale | guard: maxAge check | verdict: DROP (FP gate 3: staleness checked)
```

**Rules:**
- ≤1 line per dropped finding
- ≤3 lines per confirmed finding before expanding to full format
- Never reconsider a dropped finding

---

## Integration with Report

After validation, format confirmed findings per `audit-report-format` skill:

1. Sort by confidence (highest first)
2. Insert "Below Confidence Threshold" separator at score 75
3. Findings ≥75: Full description + impact + PoC + fix
4. Findings 60-74: Description only, no fix
5. Below 60: Excluded from report

This framework should be applied to EVERY finding — whether from manual review, automated tools, or sub-agent scans.
