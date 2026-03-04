# Governance Attack Vectors

## Overview

Decentralized governance systems are designed to give token holders control over protocol parameters, upgrades, and treasury management. However, poorly designed governance can be exploited through various attack vectors, often with catastrophic consequences.

## Flash Loan Governance Attacks

### Attack Mechanism

Flash loans allow anyone to borrow massive amounts of tokens within a single transaction without collateral, as long as the loan is repaid before the transaction ends. This enables governance attacks:

```solidity
// VULNERABLE GOVERNANCE
contract VulnerableGovernance {
    IERC20 public governanceToken;
    
    // Uses current balance for voting power - DANGEROUS!
    function vote(uint256 proposalId, bool support) external {
        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        proposals[proposalId].votes[support] += votingPower;
    }
}

// ATTACK
contract GovernanceAttacker {
    function attack(IFlashLoan flashLoan, VulnerableGovernance gov) external {
        // 1. Flash loan 10M tokens
        flashLoan.loan(address(governanceToken), 10_000_000e18, abi.encode(gov));
    }
    
    function onFlashLoan(bytes calldata data) external {
        VulnerableGovernance gov = abi.decode(data, (VulnerableGovernance));
        
        // 2. Vote with borrowed tokens
        gov.vote(maliciousProposalId, true);
        
        // 3. Proposal passes immediately
        gov.execute(maliciousProposalId); // Drain treasury
        
        // 4. Return tokens
        governanceToken.transfer(msg.sender, 10_000_000e18);
    }
}
```

### Real-World Examples

#### Beanstalk Farms (April 2022, $182M)

**Attack Flow:**
1. Attacker flash loaned $1 billion in crypto assets from Aave
2. Swapped for BEAN and deposited to gain Stalks (voting power)
3. Gained 67% voting power
4. Created and instantly passed BIP-18 proposal
5. Proposal called `emergencyCommit()` to execute malicious code
6. Transferred $80M to attacker's wallet
7. Repaid flash loan, kept $80M profit

**Vulnerable Code Pattern:**
```solidity
// Voting power based on current stalk balance
function balanceOfStalk(address account) public view returns (uint256) {
    return s.a[account].s.stalk; // Current balance!
}

// Emergency proposal with no timelock
function emergencyCommit(address target, bytes calldata data) external {
    require(hasSupermajority(), "Need >66% votes");
    target.call(data); // Execute immediately!
}
```

#### MakerDAO Governance Manipulation (October 2020)

**Incident:**
- BProtocol flash loaned 13,000 MKR (~$7M) from Aave/dYdX
- Used borrowed MKR to vote in governance election
- Voted to advance their preferred governance delegates
- Returned the MKR in same transaction

**Impact:** Vote manipulation (not theft, but concerning precedent)

**MakerDAO's Response:** Implemented Governance Security Module (GSM) with delays

### Defense Mechanisms

#### 1. Snapshot-Based Voting

```solidity
// SECURE: Uses historical snapshot
contract SecureGovernance {
    struct Proposal {
        uint256 snapshotBlock;
        mapping(address => uint256) votingPowerAtSnapshot;
        uint256 forVotes;
        uint256 againstVotes;
    }
    
    function propose(...) external returns (uint256 proposalId) {
        proposals[proposalId].snapshotBlock = block.number;
        // Voting power determined at this block
    }
    
    function vote(uint256 proposalId, bool support) external {
        Proposal storage proposal = proposals[proposalId];
        
        // Look up balance at snapshot block
        uint256 votes = governanceToken.getPriorVotes(
            msg.sender, 
            proposal.snapshotBlock
        );
        
        require(votes > 0, "No voting power at snapshot");
        proposal.votes[support] += votes;
    }
}
```

#### 2. Vote Delegation with Lock Period

```solidity
contract TokenWithVoting {
    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }
    
    mapping(address => address) public delegates;
    mapping(address => Checkpoint[]) public checkpoints;
    
    function delegate(address delegatee) external {
        require(delegatee != address(0), "Invalid delegatee");
        
        // Transfer votes from old delegate to new
        _moveDelegates(delegates[msg.sender], delegatee, balanceOf(msg.sender));
        delegates[msg.sender] = delegatee;
    }
    
    function getPriorVotes(address account, uint256 blockNumber) 
        external 
        view 
        returns (uint96) 
    {
        require(blockNumber < block.number, "Not yet determined");
        
        // Binary search through checkpoints
        Checkpoint[] storage ckpts = checkpoints[account];
        if (ckpts.length == 0) return 0;
        
        // ... binary search logic ...
        return ckpts[index].votes;
    }
}
```

#### 3. Time-Weighted Voting Power

```solidity
contract TimeWeightedGovernance {
    struct VotingPower {
        uint256 amount;
        uint256 lockedUntil;
        uint256 multiplier; // Longer lock = higher multiplier
    }
    
    mapping(address => VotingPower) public votingPower;
    
    function lockTokens(uint256 amount, uint256 lockDuration) external {
        require(lockDuration >= MIN_LOCK, "Lock too short");
        
        governanceToken.transferFrom(msg.sender, address(this), amount);
        
        uint256 multiplier = calculateMultiplier(lockDuration);
        votingPower[msg.sender] = VotingPower({
            amount: amount,
            lockedUntil: block.timestamp + lockDuration,
            multiplier: multiplier
        });
    }
    
    function calculateMultiplier(uint256 duration) internal pure returns (uint256) {
        // 1 week = 1x, 1 year = 4x (example)
        return 1e18 + (duration * 3e18 / 365 days);
    }
    
    function getVotingPower(address account) public view returns (uint256) {
        VotingPower memory vp = votingPower[account];
        return (vp.amount * vp.multiplier) / 1e18;
    }
}
```

#### 4. Quorum Requirements

```solidity
contract GovernanceWithQuorum {
    uint256 public constant QUORUM_PERCENTAGE = 4; // 4% of total supply
    
    function propose(...) external returns (uint256) {
        require(
            governanceToken.getPriorVotes(msg.sender, block.number - 1) 
            >= proposalThreshold,
            "Below proposal threshold"
        );
        // Create proposal
    }
    
    function execute(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.state == ProposalState.Succeeded, "Not succeeded");
        
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 totalSupply = governanceToken.totalSupplyAt(proposal.snapshotBlock);
        
        // Require quorum
        require(
            totalVotes >= (totalSupply * QUORUM_PERCENTAGE) / 100,
            "Quorum not reached"
        );
        
        require(proposal.forVotes > proposal.againstVotes, "Not passed");
        
        // Execute
        _execute(proposal);
    }
}
```

## Timelock Bypass Attacks

### Attack Vectors

#### 1. Short Timelock Delays

```solidity
// RISKY: 1 hour delay
contract ShortTimelock {
    uint256 public constant DELAY = 1 hours;
    
    function execute(Transaction memory txn) external {
        require(block.timestamp >= txn.eta, "Too early");
        require(block.timestamp <= txn.eta + GRACE_PERIOD, "Expired");
        
        txn.target.call(txn.data); // Execute after 1 hour!
    }
}
```

**Problem:** 1 hour is insufficient for community monitoring and reaction.

**Recommendation:** Minimum 24-48 hours for critical operations.

#### 2. Missing Timelock Coverage

```solidity
// VULNERABLE: Some functions bypass timelock
contract IncompleteTimelock {
    address public timelock;
    
    // Goes through timelock ✓
    function setFeeRate(uint256 rate) external {
        require(msg.sender == timelock, "Must use timelock");
        feeRate = rate;
    }
    
    // Bypasses timelock! ✗
    function emergencySetFeeRate(uint256 rate) external onlyOwner {
        feeRate = rate; // No timelock!
    }
}
```

**Fix:** All sensitive parameters should go through timelock or have separate emergency process with multi-sig.

#### 3. Timelock Parameter Manipulation

```solidity
// DANGEROUS: Admin can change timelock delay
contract ConfigurableTimelock {
    uint256 public delay;
    address public admin;
    
    function setDelay(uint256 newDelay) external {
        require(msg.sender == admin, "Not admin");
        delay = newDelay; // Can be set to 0!
    }
}
```

**Attack:** Admin sets delay to 0, executes malicious transaction immediately.

**Fix:**
```solidity
uint256 public constant MIN_DELAY = 2 days;
uint256 public constant MAX_DELAY = 30 days;

function setDelay(uint256 newDelay) external {
    require(msg.sender == address(this), "Must go through timelock");
    require(newDelay >= MIN_DELAY && newDelay <= MAX_DELAY, "Invalid delay");
    delay = newDelay;
}
```

### Compound Timelock Pattern (Best Practice)

```solidity
contract Timelock {
    uint256 public constant GRACE_PERIOD = 14 days;
    uint256 public constant MINIMUM_DELAY = 2 days;
    uint256 public constant MAXIMUM_DELAY = 30 days;
    
    address public admin;
    uint256 public delay;
    
    mapping(bytes32 => bool) public queuedTransactions;
    
    event QueueTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data,
        uint256 eta
    );
    
    event CancelTransaction(bytes32 indexed txHash);
    event ExecuteTransaction(bytes32 indexed txHash);
    
    function queueTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public returns (bytes32) {
        require(msg.sender == admin, "Must be admin");
        require(
            eta >= block.timestamp + delay,
            "Must satisfy delay"
        );
        
        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = true;
        
        emit QueueTransaction(txHash, target, value, signature, data, eta);
        return txHash;
    }
    
    function cancelTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public {
        require(msg.sender == admin, "Must be admin");
        
        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        queuedTransactions[txHash] = false;
        
        emit CancelTransaction(txHash);
    }
    
    function executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data,
        uint256 eta
    ) public payable returns (bytes memory) {
        require(msg.sender == admin, "Must be admin");
        
        bytes32 txHash = keccak256(
            abi.encode(target, value, signature, data, eta)
        );
        require(queuedTransactions[txHash], "Not queued");
        require(block.timestamp >= eta, "Too early");
        require(block.timestamp <= eta + GRACE_PERIOD, "Expired");
        
        queuedTransactions[txHash] = false;
        
        bytes memory callData = bytes(signature).length == 0
            ? data
            : abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(success, "Transaction execution reverted");
        
        emit ExecuteTransaction(txHash);
        return returnData;
    }
}
```

## Emergency Pause/Unpause Risks

### The Pause Mechanism

```solidity
import "@openzeppelin/contracts/security/Pausable.sol";

contract MyProtocol is Pausable {
    function deposit() external whenNotPaused {
        // Deposit logic
    }
    
    function withdraw() external whenNotPaused {
        // Withdrawal logic
    }
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
}
```

### Vulnerability Scenarios

#### 1. Centralized Pause Control

```solidity
// RISKY: Single address can freeze protocol
address public pauser = 0x1234...; // EOA

function pause() external {
    require(msg.sender == pauser, "Not pauser");
    _pause();
}
```

**Risks:**
- Private key compromise → attacker freezes protocol
- Malicious owner → rugs by pausing withdrawals
- Lost key → protocol permanently frozen if only unpause method

**Better:**
```solidity
// Multi-sig control
address public pauserMultisig = 0xMultiSig...;

// Or decentralized pause guardians
mapping(address => bool) public pauseGuardians;
uint256 public pauseGuardianCount;

function pause() external {
    require(pauseGuardians[msg.sender], "Not guardian");
    _pause();
}
```

#### 2. No Unpause Mechanism

```solidity
// DANGEROUS: Can pause but not unpause!
function pause() external onlyOwner {
    _pause();
}

// Missing: unpause function
```

**Impact:** Protocol permanently frozen if paused.

#### 3. Blanket Pause

```solidity
// Pauses EVERYTHING including withdrawals
modifier whenNotPaused() {
    require(!paused, "Paused");
    _;
}

function deposit() external whenNotPaused { }
function withdraw() external whenNotPaused { } // Users can't withdraw!
function trade() external whenNotPaused { }
```

**Better: Granular Pause**
```solidity
bool public depositsEnabled = true;
bool public withdrawalsEnabled = true;
bool public tradingEnabled = true;

modifier whenDepositsEnabled() {
    require(depositsEnabled, "Deposits paused");
    _;
}

modifier whenWithdrawalsEnabled() {
    require(withdrawalsEnabled, "Withdrawals paused");
    _;
}

// In emergency: pause deposits/trading but allow withdrawals
function emergencyPause() external onlyOwner {
    depositsEnabled = false;
    tradingEnabled = false;
    // withdrawalsEnabled stays true - users can exit
}
```

#### 4. No Time Limit on Pause

```solidity
// Can be paused forever
function pause() external onlyOwner {
    _pause();
}
```

**Better: Auto-Unpause**
```solidity
uint256 public pausedUntil;
uint256 public constant MAX_PAUSE_DURATION = 7 days;

function pause(uint256 duration) external onlyOwner {
    require(duration <= MAX_PAUSE_DURATION, "Duration too long");
    pausedUntil = block.timestamp + duration;
    _pause();
}

modifier whenNotPaused() {
    if (paused() && block.timestamp >= pausedUntil) {
        _unpause(); // Auto-unpause
    }
    require(!paused(), "Paused");
    _;
}
```

#### 5. Pause Before Exploit

Attacker with admin access:
```solidity
// 1. Pause protocol
pause();

// 2. Frontrun user transactions (MEV)
// 3. Steal sandwich opportunities
// 4. Unpause
unpause();
```

**Mitigation:**
- Multi-sig for pause
- On-chain pause reasons
- Timelock for unpause
- Monitoring and alerts

### Best Practice: OpenZeppelin Pausable + Timelock

```solidity
contract SecureProtocol is Pausable {
    address public immutable timelock;
    address public immutable emergencyMultisig;
    uint256 public pausedAt;
    uint256 public constant MAX_PAUSE = 7 days;
    
    constructor(address _timelock, address _multisig) {
        timelock = _timelock;
        emergencyMultisig = _multisig;
    }
    
    // Regular operations go through timelock
    function setParameter(uint256 value) external {
        require(msg.sender == timelock, "Must use timelock");
        parameter = value;
    }
    
    // Emergency pause requires multi-sig
    function emergencyPause() external {
        require(msg.sender == emergencyMultisig, "Not authorized");
        pausedAt = block.timestamp;
        _pause();
        emit EmergencyPause(msg.sender, block.timestamp);
    }
    
    // Unpause goes through timelock for deliberation
    function unpause() external {
        require(msg.sender == timelock, "Must use timelock");
        _unpause();
        emit Unpaused(block.timestamp);
    }
    
    // Auto-unpause after max duration
    modifier whenNotPausedOrExpired() {
        if (paused() && block.timestamp >= pausedAt + MAX_PAUSE) {
            _unpause();
        }
        require(!paused(), "Paused");
        _;
    }
    
    // Critical: Allow withdrawals even when paused
    function emergencyWithdraw() external {
        // No pause check - always allowed
        uint256 balance = balances[msg.sender];
        balances[msg.sender] = 0;
        token.transfer(msg.sender, balance);
    }
}
```

## Vote Buying and Bribery

### Bribery Platforms

Some protocols explicitly enable vote buying:
- **Votium**: Bribes for Curve gauge votes
- **Hidden Hand**: Bribery marketplace for various protocols
- **Redacted Cartel**: Vote aggregation and bribery

### Risks

```solidity
// Protocol wants their Curve pool to get emissions
// Bribes Curve voters to vote for their pool
// Effectively "buying" governance

// This can lead to:
// 1. Governance capture by highest bidder
// 2. Voter apathy (just vote for bribes, not protocol health)
// 3. Plutocracy (whales extract maximum value)
```

### Defenses

1. **Vote Escrow (ve) Model** (Curve, Balancer):
```solidity
// Lock tokens for up to 4 years
// Longer lock = more voting power
// Can't be flash loaned
// Creates long-term alignment
```

2. **Delegation Safeguards**:
```solidity
contract SafeDelegation {
    mapping(address => uint256) public delegationLockUntil;
    
    function delegate(address delegatee) external {
        require(
            block.timestamp >= delegationLockUntil[msg.sender],
            "Delegation locked"
        );
        
        // Minimum 7 days before can re-delegate
        delegationLockUntil[msg.sender] = block.timestamp + 7 days;
        
        _delegate(msg.sender, delegatee);
    }
}
```

3. **Conviction Voting**:
```solidity
// Votes accumulate weight over time
// Longer you vote for something, more weight it has
// Prevents last-minute pile-ons
```

## Proposal Execution Risks

### Front-Running Proposal Execution

```solidity
// Attacker sees proposal in mempool
// Front-runs with preparatory transaction
// Exploits the state change

// Example: Proposal increases price feed
// Attacker front-runs with large buy
// Proposal executes, price increases
// Attacker sells for profit
```

**Mitigation:**
```solidity
// Randomized execution window
uint256 executionWindow = proposal.eta + (block.number % 100) * 12;

// Or commit-reveal for execution
```

### Proposal Parameter Validation

```solidity
// VULNERABLE: No bounds checking
function setFeeRate(uint256 rate) external {
    require(msg.sender == governance, "Not governance");
    feeRate = rate; // Could be 100% or 0!
}

// SECURE: Bounded parameters
function setFeeRate(uint256 rate) external {
    require(msg.sender == governance, "Not governance");
    require(rate >= MIN_FEE && rate <= MAX_FEE, "Out of bounds");
    
    emit FeeRateChanged(feeRate, rate);
    feeRate = rate;
}
```

## Complete Governance Security Checklist

- [ ] **Snapshot-based voting** (not current balance)
- [ ] **Minimum timelock** of 24-48 hours
- [ ] **Quorum requirements** (minimum participation)
- [ ] **Proposal threshold** (minimum tokens to propose)
- [ ] **Vote delegation** with lock period
- [ ] **Multi-sig admin** (not single EOA)
- [ ] **Parameter bounds** on all governance-controlled values
- [ ] **Emergency pause** via multi-sig
- [ ] **Granular pause** (not blanket freeze)
- [ ] **Max pause duration** with auto-unpause
- [ ] **Emergency withdrawal** always enabled
- [ ] **Cancellation mechanism** for malicious proposals
- [ ] **Execution bounds** (max changes per proposal)
- [ ] **Time-weighted voting** consideration
- [ ] **Clear documentation** of governance process

## Resources

- [Compound Governance](https://github.com/compound-finance/compound-protocol/tree/master/contracts/Governance)
- [OpenZeppelin Governor](https://docs.openzeppelin.com/contracts/4.x/api/governance)
- [Beanstalk Post-Mortem](https://bean.money/blog/beanstalk-post-mortem)
- [MakerDAO Governance Security Module](https://docs.makerdao.com/smart-contract-modules/governance-module)
- [Snapshot Documentation](https://docs.snapshot.org/)
