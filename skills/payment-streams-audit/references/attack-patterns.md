# Attack Patterns in Payment Streaming Protocols

## 1. Rounding Exploitation

### The Attack
Attacker creates many small streams to accumulate rounding errors in their favor.

```solidity
// VULNERABLE: Truncation to zero
function ratePerSecond(uint256 amount, uint256 duration) public pure returns (uint256) {
    return amount / duration;  // If amount < duration, returns 0!
}

// Example: 100 tokens over 1000 seconds = 0.1 per second → truncates to 0
// Attacker streams 100 tokens but recipient can withdraw nothing!
```

**Fix:** Use higher precision arithmetic or minimum rate validation:
```solidity
function ratePerSecond(uint256 amount, uint256 duration) public pure returns (uint256) {
    uint256 rate = amount / duration;
    require(rate > 0 || amount == 0, "Amount too small for duration");
    return rate;
}
```

**Variant:** The opposite - rounding in recipient's favor allows draining more than deposited:
```solidity
// VULNERABLE: Cumulative rounding up
function withdrawable(uint256 streamId) public view returns (uint256) {
    uint256 elapsed = block.timestamp - stream.startTime;
    // If rounding up here, small repeated withdrawals can exceed deposit
    return (stream.ratePerSecond * elapsed + 999) / 1000;  // Rounds up
}
```

## 2. Withdrawal Reentrancy

### The Attack
Malicious recipient reenters withdrawal function before state is updated.

```solidity
// VULNERABLE: State update after external call
function withdraw(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    uint256 amount = withdrawable(streamId);
    
    token.transfer(msg.sender, amount);  // ❌ External call first
    stream.withdrawn += amount;          // ❌ State update after
}
```

**Attack contract:**
```solidity
contract MaliciousRecipient {
    uint256 count = 0;
    
    receive() external payable {
        if (count < 10) {
            count++;
            streamingContract.withdraw(streamId);  // Reenter!
        }
    }
}
```

**Fix:** Follow Checks-Effects-Interactions pattern:
```solidity
function withdraw(uint256 streamId) external nonReentrant {
    Stream storage stream = streams[streamId];
    uint256 amount = withdrawable(streamId);
    
    stream.withdrawn += amount;          // ✅ State update first
    token.transfer(msg.sender, amount);  // ✅ External call after
}
```

## 3. Phantom Balance Creation

### The Attack
Exploit accounting bug to create withdrawable balance that exceeds deposited amount.

```solidity
// VULNERABLE: No cap on withdrawal
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    uint256 elapsed = block.timestamp - stream.startTime;
    uint256 streamed = stream.ratePerSecond * elapsed;
    
    return streamed - stream.withdrawn;  // ❌ No check that streamed <= deposited
}
```

**Attack scenario:**
1. Create stream with 1000 tokens, duration 100 seconds (rate = 10/sec)
2. Cancel stream after 50 seconds (500 tokens streamed)
3. If cancellation doesn't update `ratePerSecond`, time keeps running
4. After another 50 seconds, `streamed = 10 * 100 = 1000` tokens
5. But only 500 tokens remain in contract!

**Fix:** Cap withdrawable amount:
```solidity
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    uint256 elapsed = block.timestamp - stream.startTime;
    uint256 streamed = stream.ratePerSecond * elapsed;
    
    // Cap at deposited amount
    if (streamed > stream.deposit) {
        streamed = stream.deposit;
    }
    
    return streamed - stream.withdrawn;
}
```

## 4. Time Manipulation (Minor)

### The Attack
Miners can manipulate `block.timestamp` by ~15 seconds to extract slight advantage.

```solidity
// VULNERABLE: Sensitive to small time changes
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    uint256 elapsed = block.timestamp - stream.startTime;  // ❌ Miner can +15 sec
    return stream.ratePerSecond * elapsed - stream.withdrawn;
}
```

**Impact:**
- For a stream of 1000 tokens/day, 15 seconds = 0.17 tokens
- Not critical for most use cases, but can matter for:
  - Very high-value streams (millions/day)
  - Precise cliff timing (unlock at exactly T+30 days)
  - MEV opportunities (front-run large withdrawal)

**Mitigation:** Accept this risk for most cases, or:
- Use oracle timestamps for critical operations
- Use `block.number` instead (but variable block times introduce other issues)
- Add slippage tolerance for withdrawals

## 5. Cancellation Race Condition

### The Attack
Recipient races to withdraw before sender cancels, extracting more than intended.

**Scenario:**
1. Sender creates 1000-token stream over 100 seconds
2. At T+50 seconds, sender decides to cancel (500 tokens streamed)
3. Recipient front-runs the cancel transaction
4. Recipient withdraws 500 tokens
5. Sender's cancel transaction executes, tries to refund sender
6. If cancellation logic assumes recipient hasn't withdrawn, accounting breaks

```solidity
// VULNERABLE: Assumes no withdrawal before cancel
function cancel(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    require(msg.sender == stream.sender, "Not sender");
    
    uint256 elapsed = block.timestamp - stream.startTime;
    uint256 streamed = stream.ratePerSecond * elapsed;
    
    // ❌ Doesn't account for already-withdrawn amount
    token.transfer(stream.recipient, streamed);
    token.transfer(stream.sender, stream.deposit - streamed);
    
    delete streams[streamId];
}
```

**Fix:** Track withdrawn amount:
```solidity
function cancel(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    require(msg.sender == stream.sender, "Not sender");
    
    uint256 elapsed = block.timestamp - stream.startTime;
    uint256 streamed = stream.ratePerSecond * elapsed;
    uint256 recipientOwed = streamed - stream.withdrawn;  // ✅ Subtract withdrawn
    
    if (recipientOwed > 0) {
        token.transfer(stream.recipient, recipientOwed);
    }
    
    uint256 senderRefund = stream.deposit - streamed;
    if (senderRefund > 0) {
        token.transfer(stream.sender, senderRefund);
    }
    
    delete streams[streamId];
}
```

## 6. Multi-Stream Accounting Confusion

### The Attack
Create multiple streams with same sender/recipient to confuse accounting.

```solidity
// VULNERABLE: Single balance tracking for sender
mapping(address => uint256) public senderBalance;

function createStream(...) external {
    senderBalance[msg.sender] -= amount;  // ❌ What if sender has multiple streams?
}

function cancel(uint256 streamId) external {
    senderBalance[stream.sender] += refundAmount;  // ❌ Can overflow or be exploited
}
```

**Attack scenario:**
1. Create two streams: StreamA (1000 tokens) and StreamB (1000 tokens)
2. `senderBalance[attacker] = initialBalance - 2000`
3. Cancel StreamA, get refund of 500 tokens
4. `senderBalance[attacker] = initialBalance - 2000 + 500`
5. If vulnerable, cancel StreamA again (if not marked cancelled)
6. `senderBalance[attacker] = initialBalance - 2000 + 500 + 500` ← profit!

**Fix:** Per-stream accounting, not per-address:
```solidity
struct Stream {
    uint256 deposit;
    uint256 withdrawn;
    bool cancelled;
    // ... other fields
}

mapping(uint256 => Stream) public streams;

function cancel(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    require(!stream.cancelled, "Already cancelled");  // ✅ Idempotency check
    stream.cancelled = true;
    // ... refund logic using stream.deposit and stream.withdrawn
}
```

## 7. Integer Overflow in Rate Calculation

### The Attack
Cause overflow when calculating `rate * time` for large values.

```solidity
// VULNERABLE: No overflow protection (pre-Solidity 0.8.0)
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    uint256 elapsed = block.timestamp - stream.startTime;
    
    // ❌ Can overflow if rate is large and elapsed is large
    uint256 streamed = stream.ratePerSecond * elapsed;
    
    return streamed - stream.withdrawn;
}
```

**Attack scenario:**
- `ratePerSecond = 2^200` (maliciously high)
- `elapsed = 2^56` seconds
- `rate * elapsed = 2^256` → overflow to 0!
- Recipient can't withdraw anything despite stream running

**Fix (Solidity 0.8.0+):** Built-in overflow protection, but still validate inputs:
```solidity
function createStream(uint256 amount, uint256 duration) external {
    uint256 rate = amount / duration;
    require(rate > 0, "Amount too small");
    
    // Additional safety: Check that rate * duration doesn't overflow
    require(rate * duration <= amount + duration, "Invalid rate calculation");
    
    // ... create stream
}
```

## 8. Dust Accumulation DOS

### The Attack
Create many streams with tiny amounts to lock up protocol with unclaimable dust.

```solidity
// VULNERABLE: No minimum stream amount
function createStream(uint256 amount, uint256 duration) external {
    // ❌ Allows amount = 1 wei over 1000 seconds
    streams[nextId++] = Stream({
        amount: amount,
        duration: duration,
        ratePerSecond: amount / duration  // = 0 for small amounts!
    });
}
```

**Attack impact:**
- Create 10,000 streams with 1 wei each
- Gas cost to iterate over streams becomes prohibitive
- Protocol state bloated with useless data
- If there's a "sweep all" function, it becomes unusable

**Fix:** Enforce minimum stream amount:
```solidity
uint256 public constant MIN_STREAM_AMOUNT = 1000;  // Example: 1000 wei minimum

function createStream(uint256 amount, uint256 duration) external {
    require(amount >= MIN_STREAM_AMOUNT, "Amount too small");
    require(amount / duration > 0, "Duration too long for amount");
    // ... create stream
}
```

## 9. Cliff Period Bypass

### The Attack
Exploit incorrect cliff logic to withdraw funds before cliff ends.

```solidity
// VULNERABLE: Incorrect cliff check
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    
    // ❌ Wrong: Allows withdrawal at exactly cliffTime
    if (block.timestamp < stream.cliffTime) {
        return 0;
    }
    
    uint256 elapsed = block.timestamp - stream.startTime;
    return stream.ratePerSecond * elapsed - stream.withdrawn;
}
```

**Issue:** If `cliffTime` is meant to be exclusive (withdraw AFTER cliff), but check uses `<` instead of `<=`, funds unlocked one second early.

**Fix:**
```solidity
function withdrawable(uint256 streamId) public view returns (uint256) {
    Stream storage stream = streams[streamId];
    
    // ✅ No withdrawal until cliff has passed
    if (block.timestamp <= stream.cliffTime) {
        return 0;
    }
    
    // After cliff, all vested funds are available
    uint256 elapsed = block.timestamp - stream.startTime;
    return stream.ratePerSecond * elapsed - stream.withdrawn;
}
```

## 10. ERC777 / Hook-Based Reentrancy

### The Attack
If protocol supports ERC777 or tokens with transfer hooks, malicious token can reenter.

```solidity
// VULNERABLE: Supports arbitrary ERC20 tokens
function withdraw(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    uint256 amount = withdrawable(streamId);
    
    stream.withdrawn += amount;  // State updated
    
    // ❌ If token is ERC777, this triggers a hook to recipient
    // Recipient can call cancel() here!
    IERC20(stream.token).transfer(msg.sender, amount);
}

function cancel(uint256 streamId) external {
    Stream storage stream = streams[streamId];
    // During the ERC777 hook above, cancel can be called
    // This can break accounting if not careful
    // ...
}
```

**Fix:** Use reentrancy guards on ALL external functions:
```solidity
function withdraw(uint256 streamId) external nonReentrant {
    // ... safe
}

function cancel(uint256 streamId) external nonReentrant {
    // ... safe
}
```

Or whitelist only safe tokens (USDC, DAI, WETH).

---

## Summary Table

| Attack | Severity | Common? | Fix Complexity |
|--------|----------|---------|----------------|
| Rounding Exploitation | Medium | High | Low |
| Withdrawal Reentrancy | Critical | Medium | Low (use guard) |
| Phantom Balance | Critical | Medium | Medium |
| Time Manipulation | Low | Low | Accept risk |
| Cancellation Race | High | High | Medium |
| Multi-Stream Confusion | High | Medium | Low |
| Integer Overflow | Medium | Low (0.8.0+) | Low |
| Dust DOS | Medium | Low | Low |
| Cliff Period Bypass | Medium | Medium | Low |
| ERC777 Reentrancy | High | Low | Low (use guard) |

---

**Audit Tip:** Always check the interaction between withdrawal, cancellation, and balance accounting. Most exploits involve state inconsistencies between these operations.
