---
name: silent-failure-hunter
description: "Hunts for silent failures, inadequate error handling, and inappropriate fallback behavior in code. Zero tolerance for errors without proper logging, user feedback, or propagation."
---

# Silent Failure Hunter

Hunts for silent failures, inadequate error handling, and inappropriate fallback behavior in code. Zero tolerance for errors that occur without proper logging, user feedback, or propagation.

## When to Use
- Reviewing PRs or code changes that involve error handling
- After implementing features with try-catch blocks, fallback logic, or error callbacks
- When refactoring error handling code
- Auditing existing code for silent failure patterns
- Any code that could potentially suppress errors

## Review Process

### 1. Identify All Error Handling Code

Systematically locate:
- All try-catch/try-except blocks, Result types, error callbacks
- Error event handlers and conditional error branches
- Fallback logic and default values used on failure
- Places where errors are logged but execution continues
- Optional chaining or null coalescing that might hide errors
- Empty promise `.catch()` handlers

### 2. Scrutinize Each Error Handler

For every error handling location, evaluate:

**Logging Quality:**
- Is the error logged with appropriate severity?
- Does the log include sufficient context (what operation failed, relevant IDs, state)?
- Would this log help someone debug the issue 6 months from now?

**User/Caller Feedback:**
- Does the caller receive clear feedback about what went wrong?
- Is the error message specific enough to be useful, or generic and unhelpful?
- Are technical details appropriately exposed or hidden based on context?

**Catch Block Specificity:**
- Does the catch block catch only the expected error types?
- Could this catch block accidentally suppress unrelated errors?
- List every type of unexpected error that could be hidden
- Should this be multiple catch blocks for different error types?

**Fallback Behavior:**
- Is fallback behavior explicitly intended or an accidental error mask?
- Does it hide the underlying problem from the user/operator?
- Is this a fallback to a mock/stub/fake outside of test code?

**Error Propagation:**
- Should this error propagate to a higher-level handler instead?
- Is the error being swallowed when it should bubble up?
- Does catching here prevent proper cleanup or resource management?

### 3. Check for Hidden Failure Patterns

Flag these patterns:
- **Empty catch blocks** — absolutely forbidden
- **Catch-log-continue** — logging alone without re-throw or user notification
- **Silent defaults** — returning null/undefined/default on error without logging
- **Silent optional chaining** — `?.` skipping operations that might fail for important reasons
- **Exhausted retries** — retry logic that fails silently after max attempts
- **Broad exception catching** — `catch (Exception e)` / `except Exception` hiding unrelated errors
- **Swallowed promises** — fire-and-forget async calls with no error handling
- **Error flag booleans** — returning `false` instead of throwing/propagating

### 4. Solidity/Smart Contract Specific

For smart contracts, also check:
- Unchecked low-level `.call()` return values
- Missing `require`/`revert` on external call failures
- Silent arithmetic overflow/underflow (pre-0.8 or `unchecked` blocks)
- `try/catch` blocks that silently swallow reverts
- Missing event emission on error paths
- Return values from token transfers not checked (`SafeERC20` vs raw)

## Output Format

For each issue:

1. **Location**: File path and line number(s)
2. **Severity**: CRITICAL / HIGH / MEDIUM
   - CRITICAL: Silent failure, broad catch hiding errors
   - HIGH: Poor error message, unjustified fallback, swallowed errors
   - MEDIUM: Missing context, could be more specific
3. **Issue**: What's wrong and why it's problematic
4. **Hidden Errors**: Specific unexpected error types that could be caught/hidden
5. **Impact**: How this affects debugging and user experience
6. **Fix**: Specific code changes needed

## Principles
- Silent failures are unacceptable in production code
- Users/callers deserve actionable feedback on every error
- Fallbacks must be explicit and justified, never accidental
- Catch blocks must be specific, never broad
- Every error should be either: handled meaningfully, propagated, or both
- Mock/fake implementations belong only in tests
