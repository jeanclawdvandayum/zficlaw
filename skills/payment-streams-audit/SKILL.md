---
name: payment-streams-audit
description: "Comprehensive checklist for auditing payment streaming protocols (Sablier, Superfluid, vesting, subscriptions)"
metadata:
  category: security-audit
  tags: "defi, streaming, vesting, payment, audit, security"
  version: "1.0.0"
  created: "2025-02-05"
---

# Payment Streaming Protocol Audit

## When to Use

Use this skill when auditing:
- **Streaming payment protocols** (Sablier, Superfluid, custom implementations)
- **Vesting contracts** (token unlocks over time)
- **Subscription systems** (recurring payments)
- **Payroll contracts** (salary streaming)
- **Any contract with time-based fund distribution**

## Core Audit Checklist

### 1. Stream Math & Precision
- [ ] **Rate calculation overflow/underflow** - Check all multiplications involving rates, durations, and amounts
- [ ] **Division precision loss** - Verify rounding direction (favor payer vs payee?)
- [ ] **Rate per second calculations** - `amount / duration` must not truncate to zero
- [ ] **Accumulated amount precision** - Check `rate * elapsed_time` for large time spans
- [ ] **Token decimals handling** - Low-decimal tokens (USDC=6) vs high-decimal (DAI=18)
- [ ] **Time unit conversions** - Seconds, blocks, days - ensure consistency

### 2. Balance Accounting
- [ ] **Double-withdraw prevention** - Can funds be claimed multiple times?
- [ ] **Phantom balance creation** - Can accounting be manipulated to show more than deposited?
- [ ] **Withdrawal cap enforcement** - Ensure withdrawn ≤ streamed amount
- [ ] **Multi-stream isolation** - Streams shouldn't affect each other's balances
- [ ] **Deposit vs streamed tracking** - Separate accounting for deposited vs distributed amounts
- [ ] **Remainder handling** - What happens to unstreamed funds after cancellation?

### 3. Time Manipulation
- [ ] **block.timestamp dependencies** - Can miners manipulate by ~15 seconds?
- [ ] **Start time validation** - Can start time be in the past? Far future?
- [ ] **End time validation** - Must be > start time, reasonable duration
- [ ] **Cliff period logic** - Zero withdrawals before cliff, then full accrual?
- [ ] **Time travel scenarios** - What if block.timestamp jumps backward (rare but possible)?

### 4. Cancellation & Revocation
- [ ] **Who can cancel?** - Sender only? Recipient? Both?
- [ ] **Partial withdrawal then cancel** - Correct remaining balance calculation?
- [ ] **Cancel idempotency** - Can't cancel twice and drain funds
- [ ] **Refund calculation** - Sender gets unstreamed amount, recipient gets streamed amount
- [ ] **Status updates** - Stream marked as cancelled, can't withdraw after
- [ ] **Re-entrancy during cancel** - Callbacks to malicious recipient during refund?

### 5. Withdrawal Patterns
- [ ] **Reentrancy protection** - CEI pattern (Checks-Effects-Interactions)?
- [ ] **Recipient control** - Can recipient set arbitrary withdrawal address?
- [ ] **Approve + transferFrom pattern** - Safer than direct recipient.call
- [ ] **Gas griefing** - Malicious recipient can't DOS withdrawals for sender
- [ ] **Withdrawal hooks** - If callbacks exist, are they safe?

### 6. Access Control
- [ ] **Stream creation permissions** - Who can create streams?
- [ ] **Parameter modification** - Can rate/recipient/duration be changed mid-stream?
- [ ] **Delegate withdrawal** - Can others withdraw on recipient's behalf?
- [ ] **Admin privileges** - Can admin pause, upgrade, or drain funds?
- [ ] **Permission revocation** - Can permissions be removed mid-stream?

### 7. Edge Cases
- [ ] **Zero amount streams** - Rejected or handled gracefully?
- [ ] **Infinite duration** - Streams that never end?
- [ ] **Same sender/recipient** - Self-streaming, does accounting break?
- [ ] **Multiple concurrent streams** - Same sender/recipient pair, different IDs?
- [ ] **Paused contract state** - What happens to time accounting during pause?

## Red Flags 🚩

**CRITICAL:**
- Direct `call()` or `transfer()` to recipient without reentrancy guard
- `unchecked` blocks around math with user-supplied values
- Missing validation on start/end times
- No withdrawal cap checks (can claim more than streamed)
- Admin can change stream parameters mid-flight

**HIGH:**
- Using `block.number` instead of `block.timestamp` for long-term streams
- Rounding errors that accumulate over many small withdrawals
- No event emission on critical state changes
- Missing zero-address checks for recipient
- Centralized cancel permissions (only sender, not recipient)

**MEDIUM:**
- Complex cliff calculations without thorough testing
- Gas-inefficient loops over active streams
- No dust amount handling (tiny remainders stuck forever)
- Missing pausability for emergency situations

## Common Vulnerability Patterns

See `references/attack-patterns.md` for detailed exploitation scenarios.

## Mathematical Invariants

See `references/math-invariants.md` for properties that must always hold.

## Real-World Exploits

See `references/real-exploits.md` for documented incidents and postmortems.

## Testing Recommendations

1. **Fuzz testing** - Random amounts, durations, withdrawal timing
2. **Time-warp testing** - Advance time to various points in stream lifecycle
3. **Boundary testing** - Max uint256, zero values, off-by-one scenarios
4. **Multi-stream testing** - Concurrent streams, overlapping lifetimes
5. **Attack simulation** - Malicious recipient contracts, reentrancy attempts

## References

- [Sablier Audits](https://github.com/sablier-labs/audits)
- [Superfluid Documentation](https://docs.superfluid.finance/superfluid/protocol-overview/in-depth-overview/super-agreements)
- [OpenZeppelin Vesting Contracts](https://docs.openzeppelin.com/contracts/4.x/api/finance)
- Trail of Bits: DeFi Security Best Practices

## Tools

- **Slither** - Static analysis for common patterns
- **Echidna** - Fuzzing for invariant testing
- **Foundry** - Property-based testing with time manipulation
- **Manticore** - Symbolic execution for math verification

---

**Remember:** Streaming protocols handle continuous fund flows. Even small precision errors or timing bugs can lead to significant losses over time. Always verify mathematical correctness before auditing logic.
