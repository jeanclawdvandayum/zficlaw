# Dispute Resolution Attack Vectors

This document catalogs known attack techniques against dispute resolution systems, with focus on economic griefing, manipulation, and game-theoretic exploits.

## Attack Taxonomy

### 1. Griefing Attacks

**Definition**: Attacker pays cost C to inflict damage D on victim, where D >> C (high griefing ratio).

---

#### 1.1 Low-Cost Dispute Spam

**Attack Vector:**
```solidity
// Vulnerable contract
function dispute() external payable {
    require(msg.value >= 0.01 ether); // $10 dispute fee
    status = Status.Disputed;
    releaseTime = block.timestamp + DISPUTE_PERIOD; // +30 days
}

// Attack: For $10, lock $10,000 for 30 days
function attack() external {
    for (uint i = 0; i < 100; i++) {
        newEscrow.dispute{value: 0.01 ether}();
    }
}
```

**Impact:**
- Attacker spends $1000 to lock $1M across 100 escrows
- Griefing ratio: 1:1000
- Victims lose time value of money, opportunity cost
- Marketplace reputation damage

**Mitigation:**
```solidity
// Fixed: Dispute bond proportional to escrow value
function dispute() external payable {
    uint256 requiredBond = escrowAmount / 2; // 50% of escrowed value
    require(msg.value >= requiredBond);
    disputeBonds[disputeId] = msg.value;
    status = Status.Disputed;
}

// Slashed if dispute frivolous
function resolveDispute(uint256 disputeId, bool disputantWins) external {
    if (!disputantWins) {
        // Slash bond, reward other party
        payable(opponent).transfer(disputeBonds[disputeId]);
    }
}
```

**Real Examples:**
- Early OpenBazaar disputes had low fixed costs
- Some bounty platforms suffered from spam disputes locking payments

---

#### 1.2 Appeal Chain Griefing

**Attack Vector:**
```solidity
// Vulnerable: Unlimited appeals with fixed cost
function appeal(uint256 disputeId) external payable {
    require(msg.value >= 0.1 ether); // Fixed appeal cost
    disputes[disputeId].appealCount++;
    disputes[disputeId].status = Status.UnderAppeal;
    // Escalates to next jury tier
}
```

**Attack:**
1. Lose initial dispute (cost: $100)
2. Appeal to Court of Appeals (cost: $100)
3. Appeal to Supreme Court (cost: $100)
4. Total cost: $300 to lock funds for 90+ days

**Impact:**
- Indefinite delay of legitimate outcomes
- Victim pays legal/arbitration fees at each level
- System congestion from frivolous appeals

**Mitigation:**
```solidity
// Fixed: Exponentially increasing appeal costs
function appeal(uint256 disputeId) external payable {
    uint256 currentAppeal = disputes[disputeId].appealCount;
    uint256 requiredDeposit = BASE_DEPOSIT * (2 ** currentAppeal); // Doubles each time
    require(msg.value >= requiredDeposit);
    
    // Cap appeals
    require(currentAppeal < MAX_APPEALS); // Hard limit of 3-5 appeals
}
```

**Real Examples:**
- Kleros Court of Appeals implements increasing appeal deposits
- Traditional legal systems use cost-shifting for frivolous appeals

---

### 2. Manipulation Attacks

#### 2.1 Evidence Censorship

**Attack Vector:**
Attacker controls infrastructure (frontend, IPFS gateway, RPC node) and prevents victim from submitting evidence.

**Scenario:**
```
1. Buyer purchases item via escrow platform
2. Seller doesn't deliver
3. Buyer initiates dispute
4. Malicious platform frontend "fails" to submit buyer's evidence to blockchain
5. Arbitrator only sees seller's evidence
6. Seller wins dispute
```

**Impact:**
- One-sided rulings due to incomplete information
- Users unaware their evidence wasn't submitted
- Platform can systematically favor one party

**Mitigation:**

**Smart Contract Level:**
```solidity
// Allow direct evidence submission, bypassing frontend
function submitEvidence(
    uint256 disputeId,
    bytes32 evidenceHash,
    string calldata evidenceURI
) external {
    require(msg.sender == disputes[disputeId].buyer || 
            msg.sender == disputes[disputeId].seller);
    require(block.timestamp < disputes[disputeId].evidenceDeadline);
    
    Evidence memory evidence = Evidence({
        submitter: msg.sender,
        hash: evidenceHash,
        uri: evidenceURI,
        timestamp: block.timestamp
    });
    
    disputes[disputeId].evidence.push(evidence);
    emit EvidenceSubmitted(disputeId, msg.sender, evidenceHash);
}
```

**Protocol Level:**
- Publish direct contract interaction guides
- Multiple IPFS/Arweave gateways for decentralized storage
- Evidence submission confirmation receipts
- Penalty for arbitrators who rule without reviewing all evidence

**Real Examples:**
- Centralized marketplace disputes where platform controlled narrative
- Some early blockchain arbitration platforms had single-gateway dependencies

---

#### 2.2 Arbitrator Frontrunning

**Attack Vector:**
```solidity
// Vulnerable: Arbitrator can see evidence then change ruling
function submitEvidence(uint256 disputeId, bytes calldata evidence) external {
    // Evidence visible in mempool
    disputes[disputeId].evidence[msg.sender] = evidence;
}

function finalize(uint256 disputeId, address winner) external onlyArbitrator {
    // Arbitrator can frontrun evidence submission, changing ruling after seeing it
    payable(winner).transfer(disputes[disputeId].amount);
}
```

**Attack:**
1. Arbitrator tentatively decides in favor of Seller
2. Buyer submits damning evidence transaction
3. Arbitrator sees evidence in mempool
4. Arbitrator frontruns with new ruling favoring Buyer (or vice versa for bribe)

**Impact:**
- Arbitrator has unfair information advantage
- Can be bribed by party showing off-chain evidence first
- Undermines trust in arbitration process

**Mitigation:**
```solidity
// Fixed: Commit-reveal pattern
function commitRuling(uint256 disputeId, bytes32 commitment) external onlyArbitrator {
    require(disputes[disputeId].evidenceDeadline < block.timestamp);
    rulingCommitments[disputeId] = commitment;
    commitDeadline[disputeId] = block.timestamp + 1 days;
}

function revealRuling(
    uint256 disputeId,
    address winner,
    bytes32 salt
) external onlyArbitrator {
    require(block.timestamp > commitDeadline[disputeId]);
    require(keccak256(abi.encodePacked(winner, salt)) == rulingCommitments[disputeId]);
    
    // Execute ruling
    payable(winner).transfer(disputes[disputeId].amount);
}
```

**Alternative:**
- Use threshold signatures where arbitrators commit privately
- Evidence deadline must pass before arbitrator decision period begins
- Slashing for arbitrators caught changing rulings based on late evidence

---

#### 2.3 Bribery & Coordination

**Attack Vector:**
In crowd-sourced arbitration (Kleros, Aragon Court), attacker bribes enough jurors to sway vote.

**P+epsilon Attack:**
```
Honest juror expected value: $10 reward for correct vote
Attacker bribe: $11 to vote incorrectly

If attacker can reach 51% of jurors, they coordinate to vote for attacker.
All bribed jurors profit ($11 > $10), attacker steals escrow.
```

**Impact:**
- Undermines Schelling point assumption (vote for truth)
- Can be executed via dark DAOs or off-chain channels
- Larger stakes = larger bribery incentive

**Mitigation Strategies:**

**1. Increasing Appeal Costs:**
```solidity
// Losing party can appeal to larger jury
function appeal(uint256 disputeId) external payable {
    uint256 newJurySize = currentJurySize * 2; // Exponentially more expensive to bribe
    require(msg.value >= BASE_COST * newJurySize);
    // ...
}
```

**2. Secret Juror Selection:**
```solidity
// Jurors selected after commit deadline (can't bribe unknown participants)
function commitPhase() external {
    // All jurors commit to their votes
}

function revealJurors() external {
    // Only after commits, reveal who was selected
    // Too late to coordinate bribes
}
```

**3. Futarchy / Prediction Markets:**
```solidity
// Jurors bet on outcome, market price reflects true probability
// Bribery must overcome entire market, not just 51% of jurors
```

**4. External Reputation Systems:**
- Juror identity tied to long-term reputation
- Bribery cost > lifetime expected earnings from honest participation

**Real Examples:**
- Theoretical attacks on Augur, Kleros
- Historical vote-buying in traditional shareholder governance
- "Nothing at stake" problem in early PoS systems

---

### 3. Timing Attacks

#### 3.1 Challenge Window Exploitation

**Attack Vector:**
```solidity
// Vulnerable: Too short challenge window
function proposeWithdrawal(uint256 amount) external {
    proposals[nextId++] = Proposal({
        amount: amount,
        timestamp: block.timestamp
    });
}

function finalizeWithdrawal(uint256 proposalId) external {
    require(block.timestamp >= proposals[proposalId].timestamp + 1 hours);
    // Process withdrawal
}
```

**Attack:**
1. Attacker proposes fraudulent withdrawal at 3 AM (victim sleeping)
2. After 1 hour, finalized before victim can challenge
3. Funds stolen

**Impact:**
- Human monitoring cannot keep up with short windows
- Timezone attacks targeting when victim likely offline
- Network congestion can prevent timely challenges

**Mitigation:**
```solidity
// Fixed: Realistic challenge periods
uint256 public constant CHALLENGE_PERIOD = 7 days; // Standard for mainnet bridges

// OR: Different periods based on amount
function getChallengeWindow(uint256 amount) internal pure returns (uint256) {
    if (amount < 1 ether) return 24 hours;
    if (amount < 10 ether) return 3 days;
    return 7 days;
}
```

**Best Practices:**
- Minimum 24 hours for any valuable operation
- 7 days standard for high-value bridges
- Layer 2s: 1 week to account for L1 congestion
- Consider timezone diversity of participants

---

#### 3.2 Timeout Extension Griefing

**Attack Vector:**
```solidity
// Vulnerable: Dispute extends timeout indefinitely
function dispute() external payable {
    require(msg.value >= DISPUTE_FEE);
    deadline = block.timestamp + DISPUTE_RESOLUTION_TIME; // Extends deadline
}

function resolveDispute(bool buyerWins) external onlyArbitrator {
    if (!buyerWins) {
        // Allow seller to withdraw
    }
    deadline = block.timestamp + DISPUTE_RESOLUTION_TIME; // Wait, extends again?
}
```

**Attack:**
- Attacker initiates dispute
- Resolution favors victim
- Attacker immediately disputes again
- Infinite loop locks funds forever

**Mitigation:**
```solidity
// Fixed: Hard maximum deadline
uint256 public immutable MAX_ESCROW_DURATION = 90 days;
uint256 public createdAt;

function dispute() external payable {
    require(block.timestamp < createdAt + MAX_ESCROW_DURATION);
    // ...
}

function emergencyWithdraw() external {
    require(block.timestamp >= createdAt + MAX_ESCROW_DURATION);
    // Return funds to buyer after absolute deadline
    payable(buyer).transfer(address(this).balance);
}
```

---

#### 3.3 MEV Frontrunning of Challenges

**Attack Vector:**
```solidity
// Vulnerable: Challenge can be frontrun to finalize first
function challenge(uint256 proposalId) external payable {
    require(msg.value >= CHALLENGE_BOND);
    proposals[proposalId].challenged = true;
}

function finalize(uint256 proposalId) external {
    require(!proposals[proposalId].challenged);
    require(block.timestamp >= proposals[proposalId].deadline);
    // Transfer funds...
}
```

**Attack:**
1. Victim submits challenge transaction
2. Attacker sees it in mempool
3. Attacker frontruns with finalize() using higher gas
4. Victim's challenge reverts (already finalized)

**Impact:**
- Malicious proposers can steal funds even when challenged
- MEV bots can extract value by frontrunning legitimate challenges

**Mitigation:**
```solidity
// Fixed: Challenge period before finalization
function finalize(uint256 proposalId) external {
    Proposal storage p = proposals[proposalId];
    require(block.timestamp >= p.deadline + CHALLENGE_PERIOD);
    require(!p.challenged);
    // ...
}

// OR: Two-step finalization
function requestFinalization(uint256 proposalId) external {
    proposals[proposalId].finalizationRequested = block.timestamp;
}

function finalize(uint256 proposalId) external {
    require(block.timestamp >= proposals[proposalId].finalizationRequested + 1 hours);
    // Gives time for challenges
}
```

---

### 4. Economic Attacks

#### 4.1 Collateral Insufficiency

**Attack Vector:**
```solidity
// Vulnerable: Can propose withdrawal of $1M with only $1K stake
function proposeWithdrawal(uint256 amount) external payable {
    require(msg.value >= 0.1 ether); // ~$100
    proposals[msg.sender] = Proposal({
        amount: amount, // Could be 10000 ether
        bond: msg.value
    });
}
```

**Attack:**
1. Attacker stakes $100
2. Proposes to withdraw $1,000,000
3. If caught, loses $100
4. If succeeds (victim offline, censorship), gains $1M
5. Expected value: 0.01% success rate still profitable ($10,000 expected value vs $100 cost)

**Impact:**
- Rational to attempt theft with low collateral
- Victim must maintain perfect uptime to prevent loss

**Mitigation:**
```solidity
// Fixed: Collateral proportional to claim
function proposeWithdrawal(uint256 amount) external payable {
    uint256 requiredBond = amount / 10; // 10% collateral
    require(msg.value >= requiredBond);
    
    proposals[nextId++] = Proposal({
        amount: amount,
        bond: msg.value,
        proposer: msg.sender
    });
}

// Slash bond if challenge successful
function slashProposer(uint256 proposalId) internal {
    Proposal storage p = proposals[proposalId];
    payable(challenger).transfer(p.bond); // Challenger gets slashed funds
}
```

**Industry Standards:**
- Optimism: Full bond for fault proofs
- Arbitrum: Economic security via staking
- Polygon zkEVM: Cryptographic finality (no bonds needed)

---

#### 4.2 Free Option Problem

**Attack Vector:**
In time-locked contracts (HTLCs), recipient has option to claim or let expire based on market movements.

**Scenario:**
```
Alice and Bob set up HTLC atomic swap:
- Alice locks 10 ETH (worth $10,000)
- Bob locks 20,000 USDC
- 24-hour timelock

Hour 12: ETH pumps to $1,200 (10 ETH = $12,000)
Bob decides: Claim swap (get $12k ETH for $10k USDC) ✓
OR: Let expire (save $2k) ✗

Hour 12: ETH dumps to $800 (10 ETH = $8,000)
Bob decides: Let expire ✓
OR: Claim swap (lose $2k) ✗

Bob has free option on ETH price for 24 hours.
```

**Impact:**
- Unfair to Alice who is "short" the option
- Longer timelocks = more valuable option
- Exploitable in volatile markets

**Mitigation:**
- Shorter timelocks reduce option value (but increase timing risk)
- Option premium: Require small fee for initiating swap
- Symmetrical risk: Both parties post collateral
- Use of oracles to adjust amounts based on market price

**Real Examples:**
- Lightning Network HTLCs have this issue
- Mitigated by short timeouts (40 blocks ≈ 10 minutes)

---

### 5. Sybil & Stake Grinding Attacks

#### 5.1 Sybil Voting

**Attack Vector:**
In jury systems with per-address voting:

```solidity
// Vulnerable: 1 address = 1 vote
function vote(uint256 disputeId, bool inFavorOfBuyer) external {
    require(!hasVoted[disputeId][msg.sender]);
    votes[disputeId][inFavorOfBuyer]++;
    hasVoted[disputeId][msg.sender] = true;
}

function resolveDispute(uint256 disputeId) external {
    bool buyerWins = votes[disputeId][true] > votes[disputeId][false];
    // ...
}
```

**Attack:**
1. Attacker creates 1000 addresses
2. Each votes in favor of attacker
3. Overwhelms honest voters

**Mitigation:**
```solidity
// Fixed: Stake-weighted voting
function vote(uint256 disputeId, bool inFavorOfBuyer) external {
    uint256 voterStake = stakedTokens[msg.sender];
    require(voterStake > 0);
    require(!hasVoted[disputeId][msg.sender]);
    
    votes[disputeId][inFavorOfBuyer] += voterStake; // Weighted by stake
    hasVoted[disputeId][msg.sender] = true;
}
```

**Alternative Mitigations:**
- Identity verification (KYC) - centralizes system
- Proof of personhood (BrightID, Worldcoin)
- Quadratic voting (cost scales with votes²)
- Reputation-weighted voting

---

#### 5.2 Stake Grinding

**Attack Vector:**
Attacker manipulates selection process by repeatedly trying until favorable.

```solidity
// Vulnerable: Predictable randomness
function selectArbitrator() internal view returns (address) {
    uint256 randomIndex = uint256(blockhash(block.number - 1)) % arbitrators.length;
    return arbitrators[randomIndex];
}
```

**Attack:**
1. Attacker sees they aren't selected
2. Submits transaction in next block
3. Different blockhash → different selection
4. Repeats until selected or friend is selected

**Mitigation:**
```solidity
// Fixed: Commit-reveal with VRF
function requestArbitrator(uint256 disputeId) external {
    // Use Chainlink VRF for verifiable randomness
    uint256 requestId = COORDINATOR.requestRandomWords(
        keyHash,
        subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
    );
    requestToDispute[requestId] = disputeId;
}

function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    uint256 disputeId = requestToDispute[requestId];
    uint256 index = randomWords[0] % arbitrators.length;
    disputes[disputeId].arbitrator = arbitrators[index];
}
```

---

## Griefing Ratio Analysis

**Formula:**
```
Griefing Ratio = (Cost to Victim) / (Cost to Attacker)
```

**Acceptable Ratios:**
- ≤ 1:1 - Excellent (attacker loses at least as much as victim)
- 1:1 to 10:1 - Acceptable (attacker pays meaningful cost)
- 10:1 to 100:1 - Dangerous (cheap to grief)
- > 100:1 - Critical (fix immediately)

**Examples:**

| Attack | Attacker Cost | Victim Cost | Ratio | Assessment |
|--------|--------------|-------------|-------|------------|
| Spam disputes ($10 fee, $1000 locked) | $10 | $1000 | 100:1 | 🔴 Critical |
| Adequate dispute bond (50%) | $500 | $1000 | 2:1 | 🟢 Good |
| Appeal with escalating cost | $1000 | $500 | 1:2 | 🟢 Excellent |
| Flash loan attack (borrowed capital) | $10 gas | $100,000 | 10,000:1 | 🔴 Critical |

---

## Defense in Depth Checklist

- [ ] **Economic Alignment**: Attacker loses more than victim in griefing
- [ ] **Timeout Bounds**: Maximum duration regardless of disputes
- [ ] **Collateral Requirements**: Proportional to claim size
- [ ] **Appeal Limits**: Cap on number of appeals
- [ ] **Escalating Costs**: Each appeal costs more than previous
- [ ] **Commit-Reveal**: Prevents frontrunning and manipulation
- [ ] **Evidence Immutability**: Cannot censor or modify after submission
- [ ] **Monitoring Tools**: Watchtowers / bots for challenge detection
- [ ] **Slashing Mechanisms**: Bad actors lose stake
- [ ] **Multi-Layer Security**: Appeals to higher/larger juries
- [ ] **Time-Weighted Participation**: Long-term participants favored over short-term
- [ ] **Reputation Systems**: Track arbitrator/juror history

---

**Further Reading:**
- "On Griefing and the Construction of Blockchain Protocols" (Teutsch et al.)
- Kleros Whitepaper (Schelling Point mechanics)
- Optimism Cannon Dispute Game Specification
- "SoK: Decentralized Exchanges (DEX) with Automated Market Maker (AMM) protocols" (Zhou et al.)
