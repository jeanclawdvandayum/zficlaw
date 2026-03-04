---
name: chain-of-thought
description: "Structured reasoning framework for hard problems. Use when facing complex decisions, debugging tricky issues, or working through multi-step logic."
---

# Chain of Thought Reasoning

Structured reasoning framework for hard problems. Use when facing complex decisions, debugging tricky issues, or working through multi-step logic.

## Step Types

| Icon | Type | Purpose |
|------|------|---------|
| 🎯 | Goal | Set the primary objective |
| 👁️ | Observation | Record factual information |
| ❓ | Question | Identify gaps and ambiguities |
| 💡 | Hypothesis | Propose solutions |
| 🧠 | Reasoning | Logical connections between thoughts |
| ✅ | Conclusion | Final decisions or results |

## Modes

### Plan Mode
Generate reasoning plans from prompts. Use when scoping a problem before diving in.

```markdown
## Reasoning Chain: [Title]

🎯 **Goal:** [Primary objective]

👁️ **Observations:**
- [Fact 1]
- [Fact 2]

❓ **Questions:**
- [Gap 1]
- [Ambiguity 1]

💡 **Hypotheses:**
1. [Proposed solution 1]
2. [Proposed solution 2]

🧠 **Reasoning:**
[Logical connections, trade-offs, analysis]

✅ **Conclusion:**
[Decision or next steps]
```

### Solve Mode
Step-by-step problem solving. Work through each step sequentially.

### Task Mode
Reason about tasks with requirements and constraints. Good for specs and implementation planning.

## When to Invoke

- Complex debugging with multiple potential causes
- Architecture decisions with trade-offs
- Security analysis requiring systematic review
- Multi-step proofs or validations
- Ambiguous requirements needing clarification

## Output Formats

- **Markdown**: Formatted reasoning chains (default)
- **JSON**: Programmatic access for logging/analysis

## Chain Validation

After completing a chain:
1. Verify each conclusion follows from reasoning
2. Check observations are factual (not assumptions)
3. Ensure all questions are addressed or explicitly deferred
4. Validate hypotheses were tested or eliminated

## Example: Debugging a Smart Contract Bug

```markdown
## Reasoning Chain: PaymentRouter Double-Spend

🎯 **Goal:** Find root cause of double-spend in voucher settlement

👁️ **Observations:**
- Voucher can be redeemed twice in same block
- Nonce check passes both times
- Balance decremented correctly each time

❓ **Questions:**
- Is nonce stored before or after transfer?
- Can same nonce be used across different channels?
- Is there a race condition in the check?

💡 **Hypotheses:**
1. Nonce stored after transfer (reentrancy window)
2. Nonce scoped to wrong mapping key
3. Front-running with same nonce

🧠 **Reasoning:**
Checked code: nonce is stored AFTER external call.
This allows reentrancy: attacker calls back before nonce update.
CEI pattern violation.

✅ **Conclusion:**
Move `usedNonces[nonce] = true` before external call.
Add reentrancy guard as defense in depth.
```
