# Mathematical Invariants for Payment Streaming Protocols

These properties **must always hold true** in a secure streaming protocol. If any invariant can be violated, there's a vulnerability.

## Core Invariants

### INV-1: Conservation of Funds
**Property:** Total funds in contract = Sum of all active stream deposits - Sum of all withdrawn amounts

```solidity
// Must always be true
assert(token.balanceOf(address(this)) == totalDeposited - totalWithdrawn);
```

**Test:**
```solidity
function invariant_conservationOfFunds() public {
    uint256 contractBalance = token.balanceOf(address(streaming));
    uint256 expectedBalance = 0;
    
    for (uint256 i = 0; i < streamCount; i++) {
        if (!streams[i].cancelled) {
            expectedBalance += streams[i].deposit - streams[i].withdrawn;
        }
    }
    
    assertEq(contractBalance, expectedBalance, "Funds conservation violated");
}
```

### INV-2: Withdrawal Cap
**Property:** For any stream, `withdrawn amount ≤ streamed amount ≤ deposited amount`

```solidity
// Must always be true for stream S
assert(S.withdrawn <= streamedAmount(S) <= S.deposit);
```

**Test:**
```solidity
function invariant_withdrawalCap(uint256 streamId) public view {
    Stream memory s = streams[streamId];
    uint256 streamed = calculateStreamed(streamId);
    
    assert(s.withdrawn <= streamed);
    assert(streamed <= s.deposit);
}
```

**Why it matters:** If violated, recipient can drain more than deposited → protocol insolvency.

### INV-3: Monotonic Time Progress
**Property:** Once time advances, withdrawable amount can only increase (until stream ends)

```solidity
// For stream S at time T1 and T2 where T2 > T1:
assert(withdrawable(S, T2) >= withdrawable(S, T1));
```

**Exception:** Withdrawable amount can decrease only when:
1. Recipient withdraws (reduces `withdrawable` but increases `withdrawn`)
2. Stream is cancelled

**Test:**
```solidity
function invariant_monotonicWithdrawable() public {
    uint256 streamId = createTestStream();
    uint256 withdrawable1 = streaming.withdrawable(streamId);
    
    vm.warp(block.timestamp + 100);  // Advance time
    
    uint256 withdrawable2 = streaming.withdrawable(streamId);
    assertGe(withdrawable2, withdrawable1, "Withdrawable decreased without action");
}
```

### INV-4: Rate Consistency
**Property:** `ratePerSecond * duration = deposited amount` (within rounding error)

```solidity
// Must be approximately true
assert(S.ratePerSecond * S.duration <= S.deposit + ROUNDING_TOLERANCE);
assert(S.ratePerSecond * S.duration >= S.deposit - ROUNDING_TOLERANCE);
```

**Test:**
```solidity
function invariant_rateConsistency(uint256 streamId) public view {
    Stream memory s = streams[streamId];
    uint256 totalFromRate = s.ratePerSecond * s.duration;
    
    // Allow 1 wei per second of rounding error
    uint256 tolerance = s.duration;
    
    assertApproxEqAbs(totalFromRate, s.deposit, tolerance, "Rate inconsistent");
}
```

**Why it matters:** If rate is miscalculated, recipient gets more or less than intended.

### INV-5: No Phantom Funds
**Property:** Sum of all withdrawable amounts across all streams ≤ contract balance

```solidity
// Must always be true
uint256 totalWithdrawable = 0;
for each stream S:
    totalWithdrawable += withdrawable(S);

assert(totalWithdrawable <= token.balanceOf(address(this)));
```

**Test:**
```solidity
function invariant_noPhantomFunds() public view {
    uint256 totalWithdrawable = 0;
    
    for (uint256 i = 0; i < streamCount; i++) {
        if (!streams[i].cancelled) {
            totalWithdrawable += streaming.withdrawable(i);
        }
    }
    
    uint256 balance = token.balanceOf(address(streaming));
    assertLe(totalWithdrawable, balance, "Phantom funds detected");
}
```

**Why it matters:** If violated, protocol is insolvent - can't fulfill all obligations.

## Stream Lifecycle Invariants

### INV-6: Stream State Consistency
**Property:** A stream cannot be both active and cancelled

```solidity
assert(!(S.active == true && S.cancelled == true));
```

### INV-7: Cancellation Finality
**Property:** Once cancelled, a stream's withdrawn amount cannot increase

```solidity
// If S.cancelled == true at time T1, then at time T2 > T1:
assert(S.withdrawn[T2] == S.withdrawn[T1]);
```

**Test:**
```solidity
function invariant_cancellationFinality() public {
    uint256 streamId = createTestStream();
    
    vm.warp(block.timestamp + 50);
    streaming.cancel(streamId);
    
    uint256 withdrawnAtCancel = streams[streamId].withdrawn;
    
    vm.warp(block.timestamp + 1000);
    
    assertEq(streams[streamId].withdrawn, withdrawnAtCancel, "Withdrawn changed after cancel");
}
```

### INV-8: Start/End Time Ordering
**Property:** For any stream, `startTime < endTime` (if not infinite)

```solidity
assert(S.startTime < S.endTime || S.endTime == type(uint256).max);
```

### INV-9: Cliff Precedence
**Property:** If cliff exists, `startTime ≤ cliffTime < endTime`

```solidity
assert(S.startTime <= S.cliffTime && S.cliffTime < S.endTime);
```

**Test:**
```solidity
function invariant_cliffOrdering(uint256 streamId) public view {
    Stream memory s = streams[streamId];
    
    if (s.cliffTime > 0) {
        assert(s.startTime <= s.cliffTime);
        assert(s.cliffTime < s.endTime);
    }
}
```

## Arithmetic Invariants

### INV-10: No Overflow in Streamed Calculation
**Property:** `ratePerSecond * elapsed` must not overflow (Solidity 0.8.0+ automatically checks)

```solidity
// For any stream S and elapsed time E:
assert(S.ratePerSecond * E < type(uint256).max);
```

**Practical check:**
```solidity
function invariant_noOverflow(uint256 streamId) public view {
    Stream memory s = streams[streamId];
    uint256 maxElapsed = type(uint256).max / s.ratePerSecond;
    
    // If stream can run longer than maxElapsed, it will overflow
    assertGt(maxElapsed, s.duration, "Potential overflow in streamed calculation");
}
```

### INV-11: Division Safety
**Property:** Rate calculation must not truncate to zero (unless deposit is zero)

```solidity
assert(deposit > 0 implies ratePerSecond > 0);
```

**Test:**
```solidity
function invariant_nonZeroRate(uint256 streamId) public view {
    Stream memory s = streams[streamId];
    
    if (s.deposit > 0) {
        assertGt(s.ratePerSecond, 0, "Rate is zero despite non-zero deposit");
    }
}
```

### INV-12: Rounding Favorability
**Property:** Rounding errors should consistently favor either payer or payee (document which)

**Convention 1 (Favor Payer):**
```solidity
// streamed = floor(rate * elapsed)
// Recipient gets slightly less
```

**Convention 2 (Favor Payee):**
```solidity
// streamed = ceil(rate * elapsed)
// Recipient gets slightly more
```

**Test consistency:**
```solidity
function invariant_roundingConsistency() public {
    // Create stream with amount that causes rounding
    uint256 streamId = streaming.createStream(1000, 3);  // 1000 / 3 = 333.333...
    
    vm.warp(block.timestamp + 1);
    uint256 streamed1 = streaming.calculateStreamed(streamId);  // Should be 333 (floor) or 334 (ceil)
    
    vm.warp(block.timestamp + 1);
    uint256 streamed2 = streaming.calculateStreamed(streamId);
    
    vm.warp(block.timestamp + 1);
    uint256 streamed3 = streaming.calculateStreamed(streamId);
    
    // Total should be 999 (floor) or 1002 (ceil), but NOT mixed
    uint256 total = streamed3;
    assert(total == 999 || total == 1002);
    assert(total != 1000 && total != 1001);  // Inconsistent rounding
}
```

## Multi-Stream Invariants

### INV-13: Stream Isolation
**Property:** Withdrawing from stream A does not affect withdrawable amount of stream B

```solidity
// Given streams A and B:
uint256 withdrawableB_before = withdrawable(B);
withdraw(A);
uint256 withdrawableB_after = withdrawable(B);

assert(withdrawableB_before == withdrawableB_after);
```

**Test:**
```solidity
function invariant_streamIsolation() public {
    uint256 streamA = createTestStream();
    uint256 streamB = createTestStream();
    
    uint256 withdrawableB_before = streaming.withdrawable(streamB);
    
    streaming.withdraw(streamA);
    
    uint256 withdrawableB_after = streaming.withdrawable(streamB);
    
    assertEq(withdrawableB_before, withdrawableB_after, "Stream isolation violated");
}
```

### INV-14: Unique Stream IDs
**Property:** Each stream has a unique identifier

```solidity
// For any two streams A and B:
assert(A.id != B.id);
```

## Cancellation Invariants

### INV-15: Refund Correctness
**Property:** On cancellation, `senderRefund + recipientPayment + alreadyWithdrawn = originalDeposit`

```solidity
assert(refund + payment + S.withdrawn == S.deposit);
```

**Test:**
```solidity
function invariant_cancellationSplit() public {
    uint256 streamId = streaming.createStream(1000, 100);
    
    vm.warp(block.timestamp + 50);  // 50% through stream
    
    uint256 withdrawn = 200;
    streaming.withdraw(streamId, withdrawn);
    
    uint256 balanceSender = token.balanceOf(sender);
    uint256 balanceRecipient = token.balanceOf(recipient);
    
    streaming.cancel(streamId);
    
    uint256 refund = token.balanceOf(sender) - balanceSender;
    uint256 payment = token.balanceOf(recipient) - balanceRecipient;
    
    assertEq(refund + payment + withdrawn, 1000, "Cancellation split incorrect");
}
```

### INV-16: Idempotent Cancellation
**Property:** Cancelling twice does not change state or balances

```solidity
// State after cancel(S):
State1 = getState(S);

// Try to cancel again:
cancel(S);  // Should revert or no-op

State2 = getState(S);
assert(State1 == State2);
```

## Edge Case Invariants

### INV-17: Zero Amount Handling
**Property:** Zero-amount streams are either rejected or handled gracefully

```solidity
// Option 1: Reject at creation
function createStream(uint256 amount, ...) {
    require(amount > 0, "Zero amount");
}

// Option 2: Handle gracefully
assert(withdrawable(zeroAmountStream) == 0 at all times);
```

### INV-18: Past Start Time Streams
**Property:** If stream starts in the past, streamed amount calculated correctly

```solidity
// If startTime < block.timestamp:
uint256 elapsed = block.timestamp - startTime;
uint256 streamed = min(rate * elapsed, deposit);

assert(streamed >= initialStreamedAmount);
```

## Token-Specific Invariants

### INV-19: Balance Consistency with Token Decimals
**Property:** All amounts respect token decimals (no fractional wei for 0-decimal tokens)

```solidity
// For token with D decimals:
assert(amount % (10 ** (18 - D)) == 0);
```

### INV-20: Fee-on-Transfer Token Handling
**Property:** If supporting fee-on-transfer tokens, actual received amount is tracked

```solidity
uint256 balanceBefore = token.balanceOf(address(this));
token.transferFrom(sender, address(this), amount);
uint256 balanceAfter = token.balanceOf(address(this));

uint256 actualReceived = balanceAfter - balanceBefore;
assert(S.deposit == actualReceived);  // Not the amount parameter!
```

---

## Testing Framework Example

### Foundry Invariant Testing

```solidity
contract StreamingInvariantTest is Test {
    StreamingProtocol streaming;
    
    function setUp() public {
        streaming = new StreamingProtocol();
    }
    
    // Foundry will call this repeatedly with random inputs
    function invariant_conservationOfFunds() public view {
        uint256 balance = token.balanceOf(address(streaming));
        uint256 expected = streaming.totalDeposited() - streaming.totalWithdrawn();
        assertEq(balance, expected);
    }
    
    function invariant_noPhantomFunds() public view {
        uint256 totalWithdrawable = 0;
        for (uint256 i = 0; i < streaming.streamCount(); i++) {
            totalWithdrawable += streaming.withdrawable(i);
        }
        assertLe(totalWithdrawable, token.balanceOf(address(streaming)));
    }
}
```

### Echidna Invariant Testing

```solidity
contract EchidnaTest {
    StreamingProtocol streaming;
    
    function echidna_conservation_of_funds() public view returns (bool) {
        return token.balanceOf(address(streaming)) == 
               streaming.totalDeposited() - streaming.totalWithdrawn();
    }
    
    function echidna_no_phantom_funds() public view returns (bool) {
        uint256 totalWithdrawable = 0;
        for (uint256 i = 0; i < streaming.streamCount(); i++) {
            totalWithdrawable += streaming.withdrawable(i);
        }
        return totalWithdrawable <= token.balanceOf(address(streaming));
    }
}
```

---

## Invariant Violation Response

When an invariant is violated during audit:

1. **Document the violation** - Which invariant, under what conditions
2. **Assess severity** - Can it lead to fund loss? DOS? Incorrect accounting?
3. **Identify root cause** - Logic error, missing check, race condition?
4. **Propose fix** - Minimal change to restore invariant
5. **Add test** - Regression test for this specific violation

**Example Report:**
```
FINDING: INV-5 Violation (No Phantom Funds)

Condition: After cancelling a stream mid-flight, the sum of all withdrawable
amounts exceeds contract balance.

Root Cause: cancel() doesn't account for already-withdrawn funds when
calculating recipient payment.

Severity: Critical - Protocol insolvency

Fix: Line 45 - Change to:
  uint256 recipientOwed = streamed - stream.withdrawn;
```

---

**Remember:** Invariants are your safety net. Write tests that assert these properties hold under all circumstances. If you can break an invariant, you've found a bug.
