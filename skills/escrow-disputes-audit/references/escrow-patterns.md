# Common Escrow Patterns

This document catalogs standard escrow designs, their security properties, and common pitfalls.

## Pattern 1: Simple Two-Party Escrow

### Design
```solidity
contract SimpleEscrow {
    address public buyer;
    address public seller;
    uint256 public amount;
    bool public buyerApproved;
    bool public sellerApproved;
    
    function release() external {
        require(msg.sender == buyer || msg.sender == seller);
        if (msg.sender == buyer) buyerApproved = true;
        if (msg.sender == seller) sellerApproved = true;
        
        if (buyerApproved && sellerApproved) {
            payable(seller).transfer(amount);
        }
    }
}
```

### Properties
- ✅ Simple to understand
- ✅ No third party needed in happy path
- ❌ Deadlock if parties disagree
- ❌ No refund mechanism
- ❌ No timeout handling

### Vulnerabilities
1. **Permanent Lock**: If buyer refuses to approve, funds locked forever
2. **Seller Griefing**: Seller can refuse to approve even after receiving goods
3. **No Dispute Path**: Disagreements have no resolution

### Improvements
- Add timeout after which buyer can cancel and withdraw
- Add arbitrator as tiebreaker
- Implement partial approval with staged releases

---

## Pattern 2: Arbitrated Escrow

### Design
```solidity
contract ArbitratedEscrow {
    address public buyer;
    address public seller;
    address public arbitrator;
    uint256 public amount;
    uint256 public arbitratorFee;
    
    enum Status { Created, Disputed, Resolved }
    Status public status;
    
    function initiateDispute() external payable {
        require(msg.sender == buyer || msg.sender == seller);
        require(msg.value >= arbitratorFee);
        status = Status.Disputed;
    }
    
    function resolve(address winner) external {
        require(msg.sender == arbitrator);
        require(status == Status.Disputed);
        
        payable(winner).transfer(amount);
        payable(arbitrator).transfer(arbitratorFee);
        status = Status.Resolved;
    }
}
```

### Properties
- ✅ Deadlock resolution via arbitrator
- ✅ Clear dispute path
- ❌ Arbitrator is single point of trust
- ❌ No evidence submission mechanism
- ❌ Arbitrator can be bribed

### Vulnerabilities
1. **Arbitrator Collusion**: Malicious arbitrator sides with party offering bribe
2. **Frontrunning**: Arbitrator sees evidence and changes decision before finalization
3. **No Appeals**: Single arbitrator decision is final
4. **Censorship**: Arbitrator could refuse to resolve, locking funds

### Improvements
- Multi-signature arbitration panel
- Commit-reveal for arbitrator decisions
- Evidence submission with hash commitments
- Appeal mechanism to higher authority
- Arbitrator staking/slashing for accountability

---

## Pattern 3: Milestone-Based Escrow

### Design
```solidity
contract MilestoneEscrow {
    struct Milestone {
        uint256 amount;
        bool approved;
        bool paid;
    }
    
    Milestone[] public milestones;
    address public buyer;
    address public seller;
    
    function approveMilestone(uint256 index) external {
        require(msg.sender == buyer);
        require(!milestones[index].approved);
        milestones[index].approved = true;
    }
    
    function claimMilestone(uint256 index) external {
        require(msg.sender == seller);
        require(milestones[index].approved);
        require(!milestones[index].paid);
        
        milestones[index].paid = true;
        payable(seller).transfer(milestones[index].amount);
    }
}
```

### Properties
- ✅ Reduces risk by staged payments
- ✅ Buyer can stop payments if dissatisfied
- ✅ Encourages incremental delivery
- ❌ Each milestone can still deadlock
- ❌ No partial milestone approval

### Vulnerabilities
1. **Final Milestone Hostage**: Buyer withholds last payment for leverage
2. **No Refunds**: If project cancelled, no mechanism to return unspent funds
3. **Accumulating Risk**: Seller risk increases with each completed milestone

### Improvements
- Automatic approval after timeout period
- Dispute resolution per milestone
- Partial payment releases (50% automatic, 50% on approval)
- Cancellation with pro-rated refunds

---

## Pattern 4: Optimistic Escrow

### Design
```solidity
contract OptimisticEscrow {
    uint256 public constant CHALLENGE_PERIOD = 7 days;
    
    struct Proposal {
        address recipient;
        uint256 amount;
        uint256 timestamp;
        bool executed;
        bool challenged;
    }
    
    mapping(uint256 => Proposal) public proposals;
    
    function proposeRelease(address recipient, uint256 amount) external {
        require(msg.sender == seller);
        uint256 id = nextProposalId++;
        proposals[id] = Proposal({
            recipient: recipient,
            amount: amount,
            timestamp: block.timestamp,
            executed: false,
            challenged: false
        });
    }
    
    function challenge(uint256 proposalId) external payable {
        require(msg.sender == buyer);
        require(msg.value >= DISPUTE_BOND);
        require(!proposals[proposalId].executed);
        
        proposals[proposalId].challenged = true;
        // Initiate dispute resolution...
    }
    
    function executeProposal(uint256 proposalId) external {
        Proposal storage p = proposals[proposalId];
        require(!p.executed);
        require(!p.challenged);
        require(block.timestamp >= p.timestamp + CHALLENGE_PERIOD);
        
        p.executed = true;
        payable(p.recipient).transfer(p.amount);
    }
}
```

### Properties
- ✅ Optimistic execution without delay in happy path (after challenge period)
- ✅ Challenge mechanism protects buyer
- ✅ Scales to frequent releases
- ❌ Requires monitoring during challenge window
- ❌ Challenge period adds latency

### Vulnerabilities
1. **Short Challenge Window**: 7 days may be insufficient if buyer is unavailable
2. **Spam Proposals**: Seller could spam proposals to overwhelm buyer's monitoring
3. **Low Challenge Bond**: If bond too low, frivolous challenges lock funds
4. **No Evidence**: Challenge lacks context about why it's disputed

### Improvements
- Longer challenge windows for high-value proposals
- Rate limiting on proposals
- Evidence submission with challenges
- Graduated challenge periods (longer for larger amounts)

---

## Pattern 5: Hash Time-Locked Contract (HTLC)

### Design
```solidity
contract HTLC {
    bytes32 public hashlock;
    uint256 public timelock;
    address public recipient;
    address public sender;
    
    function claim(bytes32 preimage) external {
        require(msg.sender == recipient);
        require(sha256(abi.encodePacked(preimage)) == hashlock);
        require(block.timestamp < timelock);
        
        payable(recipient).transfer(address(this).balance);
    }
    
    function refund() external {
        require(msg.sender == sender);
        require(block.timestamp >= timelock);
        
        payable(sender).transfer(address(this).balance);
    }
}
```

### Properties
- ✅ Atomic swaps across chains
- ✅ No third-party arbitrator needed
- ✅ Guaranteed refund path
- ❌ Requires recipient to know preimage
- ❌ Timelock must be carefully coordinated

### Vulnerabilities
1. **Preimage Exposure**: Once claimed on one chain, preimage public for others
2. **Timing Attacks**: Short timelocks can be exploited with network delays
3. **MEV Frontrunning**: Attacker sees preimage in mempool, frontruns claim
4. **Free Option Problem**: Recipient has option to claim or not based on price changes

### Improvements
- Longer timelocks with sufficient buffer
- Submarine sends / commit-reveal for claims
- Coordination across multiple hops with decreasing timelocks
- Scripted watchtowers for automatic claiming

---

## Pattern 6: Schelling Point Jury (Kleros-Style)

### Design
```solidity
contract SchellingJury {
    struct Dispute {
        uint256 choices;
        uint256[] votes;
        uint256 totalStaked;
        mapping(address => uint256) stakes;
        mapping(address => uint256) commits;
    }
    
    function commit(uint256 disputeId, bytes32 commitment) external {
        // Juror commits hash of their vote
        disputes[disputeId].commits[msg.sender] = commitment;
    }
    
    function reveal(uint256 disputeId, uint256 vote, bytes32 salt) external {
        // Verify commitment matches
        require(keccak256(abi.encodePacked(vote, salt)) == 
                disputes[disputeId].commits[msg.sender]);
        
        disputes[disputeId].votes.push(vote);
    }
    
    function redistribute(uint256 disputeId) external {
        // Calculate consensus
        uint256 winningVote = getMajority(disputeId);
        
        // Reward coherent jurors, penalize incoherent
        // (Simplified - actual implementation more complex)
        for (each juror) {
            if (juror.vote == winningVote) {
                reward(juror);
            } else {
                slash(juror);
            }
        }
    }
}
```

### Properties
- ✅ Crowdsourced arbitration
- ✅ Game-theoretic incentive alignment
- ✅ Resistant to individual corruption
- ❌ Vulnerable to majority collusion
- ❌ Requires sufficient juror participation

### Vulnerabilities
1. **P+epsilon Attacks**: Attacker bribes jurors to vote incorrectly
2. **Coordination Games**: Jurors coordinate off-chain for incorrect ruling
3. **Rational Ignorance**: Jurors vote randomly if research cost > expected reward
4. **Whale Attacks**: Large stakeholders can dominate outcomes
5. **Apathy Attacks**: Low participation allows small groups to control outcome

### Improvements
- Multi-layer appeals with increasing jury sizes
- Reputation systems with long-term consequences
- Secret staking to prevent targeted bribery
- Minimum participation thresholds
- Time-weighted voting to favor long-term participants

---

## Anti-Patterns to Avoid

### ❌ Unbounded Loops
```solidity
// BAD: Can run out of gas with many milestones
function releaseAll() external {
    for (uint i = 0; i < milestones.length; i++) {
        payable(seller).transfer(milestones[i].amount);
    }
}
```

### ❌ Ether Transfer without Check
```solidity
// BAD: If recipient is contract without payable fallback, funds locked
seller.transfer(amount);

// GOOD: Use call and handle failure
(bool success, ) = seller.call{value: amount}("");
require(success, "Transfer failed");
```

### ❌ State Before External Call
```solidity
// BAD: Reentrancy vulnerability
payable(msg.sender).transfer(amount);
released[escrowId] = true;

// GOOD: Checks-Effects-Interactions
released[escrowId] = true;
payable(msg.sender).transfer(amount);
```

### ❌ Implicit Trust Assumptions
```solidity
// BAD: Admin can drain all escrows
function emergencyWithdraw() external onlyOwner {
    payable(owner).transfer(address(this).balance);
}

// GOOD: Per-escrow withdrawals with timelock and governance
```

---

## Comparison Matrix

| Pattern | Trust Required | Deadlock Risk | Gas Cost | Dispute Cost | Best For |
|---------|---------------|---------------|----------|--------------|----------|
| Simple Two-Party | None | High | Low | N/A | Trusted relationships |
| Arbitrated | Arbitrator | Low | Medium | Low | General purpose |
| Milestone | Buyer | Medium | Medium | Per milestone | Long projects |
| Optimistic | Minimal | Low | Low | Medium | High frequency |
| HTLC | None | None | Low | N/A | Atomic swaps |
| Schelling | Jury | Low | High | High | High stakes disputes |

---

## Security Checklist by Pattern

When auditing, verify:

**All Patterns:**
- [ ] Reentrancy protection
- [ ] Integer overflow protection
- [ ] Access control on all functions
- [ ] Emergency withdrawal path exists
- [ ] Events emitted for all state changes

**Arbitrated:**
- [ ] Arbitrator can't unilaterally withdraw
- [ ] Evidence submission is immutable
- [ ] Multiple arbitrators or appeal mechanism
- [ ] Arbitrator fee reasonable and capped

**Milestone:**
- [ ] Milestone amounts sum to total escrow
- [ ] No double-payment possible
- [ ] Approved but unclaimed milestones tracked
- [ ] Cancellation/refund logic correct

**Optimistic:**
- [ ] Challenge period sufficient for monitoring
- [ ] Challenge bond adequate to prevent spam
- [ ] Proposal rate limiting implemented
- [ ] Finalization delay prevents frontrunning

**HTLC:**
- [ ] Timelock sufficient for coordination
- [ ] No signature malleability (use sha256 not ecdsa)
- [ ] Preimage length validated
- [ ] Refund path always available

**Schelling:**
- [ ] Commit-reveal properly implemented
- [ ] Minimum quorum enforced
- [ ] Appeal mechanism with higher stakes
- [ ] Random juror selection (no grinding)
- [ ] Rewards > cost of coherent voting

---

**References:**
- OpenZeppelin Escrow contracts
- Kleros whitepaper on Schelling point dispute resolution
- HTLC specifications from Lightning Network
- Various audit reports from Trail of Bits, ConsenSys, OpenZeppelin
