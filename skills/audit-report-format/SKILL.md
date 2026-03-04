---
name: audit-report-format
description: Format smart contract security audit findings into a professional report. Use when writing audit reports, formatting vulnerability findings, structuring security assessments, or converting raw audit notes into deliverable reports. Produces reports in the Zero Cool / competitive audit style with Summary, Description, Impact, Likelihood, Affected Code, Recommendation, and optional PoC sections per finding. Supports severity classification (Critical/High/Medium/Low/Info) with Impact × Likelihood matrix.
---

# Audit Report Formatter

Format smart contract audit findings into professional, structured reports.

## Report Structure

### 1. Header Block

```markdown
# [Protocol Name] — Security Audit Report

**Auditor:** [Name]
**Date:** [YYYY-MM-DD]
**Branch:** `[branch]` (commit `[short-hash]`)
**Scope:** [description of what was audited]
**Policy:** Zero false positives. Every finding verified line-by-line.
```

### 2. Findings Summary Table

```markdown
| ID | Title | Severity | Impact | Likelihood |
|----|-------|----------|--------|------------|
| C-01 | ... | Critical | Critical | High |
| H-01 | ... | High | High | Medium |
| M-01 | ... | Medium | Medium | Medium |
| L-01 | ... | Low | Low | High |
| I-01 | ... | Info | — | — |
```

Prefix IDs: `C-` Critical, `H-` High, `M-` Medium, `L-` Low, `I-` Info. Number sequentially within each tier.

### 3. Finding Format (Medium and above)

Each finding from Medium severity and above gets the full treatment:

```markdown
## [ID] — [Concise Title]

### Summary
One paragraph. State what the bug is, where it lives, and what breaks. No filler.

### Description
Technical deep-dive. Reference exact file:line. Include relevant code snippets
inline using fenced code blocks. Trace the logic step by step. Compare with
correct implementations elsewhere in the codebase when relevant.

### Impact Explanation
What breaks in practice. Quantify where possible (e.g., "attacker profits X",
"users lose up to Y%"). Distinguish between theoretical and realistic impact.

### Likelihood Explanation
How likely is this to trigger? Is it deterministic, conditional, or requires
specific preconditions? Does it need a malicious actor or can it happen organically?

### Affected Code
List each affected location as:
- `src/Contract.sol:L123-L145` — brief description of what this location does

### Recommendation
Concrete fix. Include code when the fix is non-obvious. If multiple approaches
exist, state the tradeoffs.

### Proof-of-Concept (optional)
Foundry test or step-by-step walkthrough. Include only for findings where the
attack path is non-obvious or disputed. State the command to run the test.
```

### 4. Finding Format (Low)

Low findings use the same structure but can be more concise — collapse Impact/Likelihood into shorter paragraphs.

### 5. Finding Format (Informational)

Informational findings are brief — a single paragraph or short section. No Impact/Likelihood/PoC needed.

```markdown
## I-01 — [Title]

[One to three paragraphs describing the issue and recommendation.]
```

### 6. Appendices (optional, add when relevant)

- **Immunefi/Prior Audit Fix Verification** — Table with Bug ID, Title, Status (✅ FIXED / ❌ NOT FIXED / ⚠️ PARTIAL), and evidence.
- **Invariant Verification** — Table listing each protocol invariant and whether it holds, with citations.
- **Access Control Map** — Table mapping each external function to its access control.

## Severity Classification

Use an **Impact × Likelihood** matrix:

| | Likelihood: High | Likelihood: Medium | Likelihood: Low |
|---|---|---|---|
| **Impact: Critical** | Critical | High | Medium |
| **Impact: High** | High | High | Medium |
| **Impact: Medium** | Medium | Medium | Low |
| **Impact: Low** | Low | Low | Info |

**Impact levels:**
- **Critical** — Direct, unconditional loss of user funds or protocol insolvency
- **High** — Conditional fund loss, permanent state corruption, broken core invariant
- **Medium** — Governance disruption, incorrect accounting with limited fund impact, degraded functionality
- **Low** — Gas inefficiency, code quality, theoretical edge cases, design concerns

**Likelihood levels:**
- **High** — Deterministic, triggers on normal usage, no special preconditions
- **Medium** — Requires specific conditions but plausible in production (market conditions, timing, specific parameter values)
- **Low** — Requires irrational actors, extreme edge cases, or privileged access

## Writing Rules

1. **No filler.** Skip "Great finding", "Interestingly", etc. State facts.
2. **Cite exact lines.** Every claim references `file.sol:lineNumber`.
3. **Show code.** Include the relevant snippet inline — don't make the reader go find it.
4. **Trace the flow.** For complex findings, walk through the execution step by step with numbered lists.
5. **Be honest about severity.** If the economic impact is negligible, say so. Don't inflate.
6. **Distinguish duplicates.** If two findings share a root cause, combine them or explicitly note the relationship.
7. **Zero false positives.** If you can't construct a viable attack path or demonstrate the bug, don't report it.
8. **Rounding direction matters.** When reviewing math, always state which direction rounding goes and whether it favors the protocol or users.
9. **Compare implementations.** When a bug exists in one function but is correctly handled elsewhere in the codebase, cite the correct version as evidence.
10. **Platform formatting.** Use markdown tables for structured data. Use fenced code blocks with `solidity` language tag for Solidity snippets.
