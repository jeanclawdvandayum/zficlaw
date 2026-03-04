---
name: code-simplifier
description: "Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Use after implementing features, when reviewing overly complex code, or when asked to clean up or simplify code."
---

# Code Simplifier

Simplifies and refines code for clarity, consistency, and maintainability while preserving all functionality. Focuses on recently modified code unless instructed otherwise.

## When to Use
- After implementing a feature, before committing
- When reviewing code that feels overly complex
- When refactoring for readability
- When asked to "clean up" or "simplify" code

## Process

1. **Identify scope** — Recently modified code sections (check `git diff` or `git diff --staged`), or the specific files/functions the user points to.

2. **Analyze for simplification opportunities:**
   - Unnecessary complexity and deep nesting
   - Redundant code, dead code, unused abstractions
   - Unclear variable/function names
   - Overly clever one-liners or nested ternaries
   - Duplicated logic that should be consolidated
   - Comments that describe obvious code (remove) vs missing comments for non-obvious logic (add)

3. **Apply refinements that PRESERVE FUNCTIONALITY:**
   - Reduce nesting (early returns, guard clauses)
   - Replace nested ternaries with if/else or switch
   - Extract well-named helper functions for repeated patterns
   - Simplify conditional logic (De Morgan's, boolean simplification)
   - Remove unnecessary intermediate variables (or add them when a one-liner is unclear)
   - Prefer explicit over implicit — clarity beats brevity

4. **Verify:**
   - All original features, outputs, and behaviors remain intact
   - Tests still pass (run them if available)
   - The code is actually simpler, not just different

## Principles

- **Never change what the code does** — only how it does it
- **Clarity over cleverness** — explicit readable code > compact clever code
- **Balance** — don't over-simplify. Helpful abstractions that improve organization should stay
- **Respect project conventions** — follow whatever style the codebase already uses
- **Surgical edits** — change only what needs simplifying, don't rewrite everything

## Anti-Patterns to Fix
- Deeply nested if/else chains → early returns
- `if (condition) { return true } else { return false }` → `return condition`
- Repeated `.filter().map()` chains on same array → single `.reduce()` or loop
- Nested ternaries → switch/if-else
- Boolean parameters that change function behavior → separate functions
- Try/catch wrapping non-throwing code
- `async` on functions that don't `await`

## Anti-Patterns to AVOID Creating
- Dense one-liners that require mental parsing
- Over-abstraction ("AbstractFactoryFactory")
- Premature DRY — some duplication is clearer than forced abstraction
- Removing helpful type annotations for brevity
- Combining unrelated concerns into one function
