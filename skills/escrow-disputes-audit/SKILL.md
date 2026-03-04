---
name: escrow-disputes-audit
description: "Security audit framework for escrow mechanisms, dispute resolution, and optimistic protocols in smart contracts."
---

# Escrow & Dispute Systems Audit

**Type:** Security Research  
**Domain:** Smart Contract Auditing  
**Focus:** Escrow mechanisms, dispute resolution, optimistic protocols  
**Difficulty:** Advanced  

## When to Use This Skill

Use this auditing framework when reviewing:

- **Escrow Contracts**: Multi-party fund custody with release conditions
- **Dispute Resolution Systems**: Kleros, Aragon Court, custom arbitration
- **Optimistic Protocols**: Rollups, bridges, optimistic oracle systems
- **Payment Channels**: State channels, HTLCs, conditional payments
- **Marketplace Escrow**: P2P platforms, freelance systems, custody services
- **Cross-chain Bridges**: Particularly optimistic bridge designs

## Quick Audit Checklist

### 🔐 Escrow Fund Security

- [ ] **Reentrancy Protection**: All fund transfers protected (CEI pattern, ReentrancyGuard)
- [ ] **Fund Locking**: Can funds become permanently locked? Check all exit paths
- [ ] **Release Conditions**: Are release conditions complete and unambiguous?
- [ ] **Partial Releases**: If supported, validate accounting doesn't allow over-withdrawal
- [ ] **Refund Mechanisms**: Guaranteed refund path for all parties under all conditions
- [ ] **Fee Skimming**: Validate fee calculations don't allow value extraction exploits
- [ ] **Token Compatibility**: ERC-20 fee-on-transfer, rebasing, pausable tokens handled correctly
- [ ] **ETH vs Token**: Separate accounting if both are supported
- [ ] **Selfdestruct Reception**: Contract can receive force-sent ETH without breaking accounting

### ⚖️ Dispute Resolution

- [ ] **Evidence Submission**: Timestamped, immutable, size-limited, spam-protected
- [ ] **Evidence Censorship**: Can parties be prevented from submitting evidence?
- [ ] **Dispute Initiation Cost**: High enough to prevent spam, low enough to be accessible
- [ ] **Ruling Execution**: Automatic and guaranteed after dispute resolves
- [ ] **Appeal Process**: If present, validate appeal window and escalation costs
- [ ] **Arbitrator Trust**: Is arbitrator role centralized? Can it be frontrun or manipulated?
- [ ] **Griefing Vectors**: Can disputes be used to lock funds maliciously?
- [ ] **Collateral Requirements**: Adequate to prevent frivolous disputes
- [ ] **Schelling Point**: If using crowd arbitration, check for coordination vulnerabilities

### ⏰ Timeout & Time Manipulation

- [ ] **Timeout Durations**: Neither too short (frontrun) nor too long (capital lockup griefing)
- [ ] **Block Timestamp**: Using `block.timestamp` safely (not for critical randomness)
- [ ] **Challenge Windows**: Long enough for honest challengers, short enough to prevent griefing
- [ ] **Deadline Extensions**: Can deadlines be manipulated to extend arbitrarily?
- [ ] **Expired State Handling**: All timeout branches tested and handled correctly
- [ ] **Priority Order**: Time-sensitive operations have clear ordering guarantees
- [ ] **MEV Resistance**: Time-sensitive actions resistant to miner/validator manipulation

### 🎲 Optimistic Protocol Patterns

- [ ] **Fraud Proof Submission**: Anyone can submit? Bounded execution? Complete state verification?
- [ ] **Dispute Bond**: Adequate to prevent spam, slashed on false challenges
- [ ] **Finalization**: Cannot finalize during active disputes
- [ ] **Withdrawal Delays**: Sufficient for dispute game to resolve
- [ ] **State Commitment**: Hash commitments correctly verify full state transitions
- [ ] **Bisection Game**: If used, validate binary search bounds and termination
- [ ] **Base Layer Dependency**: Correct L1 state root / block hash verification
- [ ] **Blacklist/Censorship**: Optimistic proposers cannot censor withdrawals indefinitely

### 💰 Economic Attack Vectors

- [ ] **Collateral Ratio**: Dispute bonds > potential gain from attack
- [ ] **Griefing Ratio**: Cost to griefing attacker > cost to victim (ideally 1:1 or worse for attacker)
- [ ] **Flash Loan Attacks**: Temporary capital cannot manipulate dispute outcomes
- [ ] **Sybil Resistance**: Multiple identities cannot amplify voting/arbitration power unfairly
- [ ] **Stake Grinding**: Validators/arbitrators cannot manipulate selection via repeated attempts
- [ ] **MEV Extraction**: Dispute resolution doesn't create extractable MEV opportunities
- [ ] **Bribery Resistance**: Arbitrators/validators resistant to out-of-band bribery
- [ ] **Exit Scam Prevention**: Escrow agents/operators cannot drain funds and disappear

### 🎯 Centralization & Trust Assumptions

- [ ] **Admin Privileges**: Document all privileged roles and their powers
- [ ] **Arbitrator Set**: Single arbitrator? DAO? Decentralized pool?
- [ ] **Upgrade Mechanism**: If upgradeable, validate timelock and governance safeguards
- [ ] **Oracle Dependency**: External price feeds or data sources trusted appropriately
- [ ] **Key Management**: Multi-sig requirements for critical operations
- [ ] **Emergency Actions**: Pause/emergency withdrawal powers documented and justified

### 🐛 Implementation Details

- [ ] **Integer Overflow/Underflow**: Use Solidity 0.8+ or SafeMath
- [ ] **Division Before Multiplication**: Precision loss in fee/reward calculations
- [ ] **Array Iteration**: Unbounded loops that could hit gas limits
- [ ] **Storage Collisions**: If using proxy patterns, storage layout verified
- [ ] **Delegate Call Safety**: No unprotected delegatecall to user input
- [ ] **Access Control**: Function visibility and modifiers correctly applied

## Common Vulnerability Patterns

### 1. **Fund Locking via Deadline Expiry**
```solidity
// VULNERABLE: Funds locked if both parties inactive after timeout
function release() external {
    require(block.timestamp < deadline, "Expired");
    // ... release logic
}
// FIX: Add emergency withdrawal after extended timeout
```

### 2. **Dispute Griefing via Low Cost**
```solidity
// VULNERABLE: Attacker can spam disputes for 0.01 ETH, locking 10 ETH
function dispute() external payable {
    require(msg.value >= 0.01 ether);
    status = Status.Disputed;
}
// FIX: Require dispute bond >= escrowed amount or significant fraction
```

### 3. **Arbitrator Frontrunning**
```solidity
// VULNERABLE: Arbitrator can see evidence and change ruling before finalization
function submitEvidence(bytes calldata evidence) external {
    disputeEvidence = evidence;
}
function finalizeRuling() external onlyArbitrator {
    // Arbitrator can frontrun evidence submission
}
// FIX: Commit-reveal for evidence or immutable evidence period before ruling
```

### 4. **Inadequate Withdrawal Delay**
```solidity
// VULNERABLE: 1-block withdrawal delay insufficient for dispute
function withdraw() external {
    require(block.number > proposalBlock + 1);
    // Process withdrawal
}
// FIX: Use realistic challenge period (e.g., 7 days for mainnet bridges)
```

### 5. **Collateral Insufficiency**
```solidity
// VULNERABLE: Attacker stakes $100, can steal $10,000
function proposeWithdrawal(uint256 amount) external payable {
    require(msg.value >= 0.1 ether); // ~$100
    proposals[msg.sender] = amount; // Could be $10,000
}
// FIX: Collateral proportional to claim amount
```

## Economic Attack Taxonomy

### Griefing Attacks
**Definition**: Attacker pays cost C to inflict damage D on victim where D >> C

**Example**: Spam disputes locking merchant funds for minimal deposit
**Mitigation**: Ensure griefing ratio ≤ 1 (attacker loses at least as much as victim)

### 51% / Majority Attacks
**Definition**: Majority of validators/arbitrators collude for dishonest ruling

**Example**: Kleros jurors coordinate to vote incorrectly and split victim's stake
**Mitigation**: Schelling point mechanisms, appeal to larger jury, external accountability

### Censorship Attacks
**Definition**: Privileged party prevents legitimate actions (evidence, challenges, withdrawals)

**Example**: Optimistic sequencer refuses to include fraud proofs in batch
**Mitigation**: Force-inclusion mechanisms, bypass to L1, decentralized sequencing

### Finality Delays
**Definition**: Attacker indefinitely extends dispute period to lock funds

**Example**: Repeatedly appealing to higher courts with nominal costs
**Mitigation**: Exponentially increasing appeal costs, hard finality deadlines

### Bribery / P+epsilon Attacks
**Definition**: Attacker bribes validators/arbitrators with slightly more than honest earnings

**Example**: Pay Kleros jurors to vote incorrectly via side channel
**Mitigation**: Commit-reveal voting, secret staking, external reputation systems

## Real-World Exploit References

See detailed documentation in:
- `references/real-exploits.md` - Documented incidents with postmortems
- `references/dispute-attacks.md` - Griefing and manipulation techniques
- `references/escrow-patterns.md` - Common designs and their tradeoffs

## Tools & Resources

### Audit Reports
- Trail of Bits audits (Optimism, Arbitrum)
- OpenZeppelin audits (Kleros, Aragon)
- Consensys Diligence (various dispute protocols)

### Testing Approaches
1. **Unit Tests**: All state transitions and edge cases
2. **Fuzz Testing**: Echidna/Foundry for arithmetic and state invariants
3. **Formal Verification**: Certora/K Framework for critical properties
4. **Economic Simulation**: Agent-based modeling for game theory attacks
5. **Time Manipulation**: Test with Foundry vm.warp for all timeout scenarios

### Key Invariants to Test
```solidity
// Total escrowed funds must always equal sum of individual balances
assert(address(this).balance == sumOfBalances);

// After dispute resolves, exactly one party wins (no double-spend)
assert(winnerPaid && !loserPaid || !winnerPaid && loserPaid);

// Funds cannot be locked beyond maximum timeout
assert(canWithdraw(buyer) || canWithdraw(seller) || inDispute);
```

## Further Reading

- **SWC Registry**: SWC-105 (Unprotected Ether Withdrawal), SWC-114 (Tx.Origin Auth)
- **Kleros Research**: [kleros.io/research](https://kleros.io/research) - Schelling point mechanics
- **Optimism Specs**: Dispute game specifications and security model
- **Arbitrum Research**: BOLD dispute protocol whitepaper
- **DeFi Security Summit**: Past talks on bridge exploits and dispute resolution

---

**Last Updated**: 2025-01-24  
**Maintained By**: Security Research Team  
**Version**: 1.0
