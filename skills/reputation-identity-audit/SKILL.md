---
name: reputation-identity-audit
description: "Audit on-chain reputation, soulbound tokens, and identity verification systems"
metadata:
  tags: "security, audit, web3, reputation, identity, sbt, sybil"
  version: "1.0.0"
  author: "Security Research Team"
  created: "2026-02-05"
---

# Reputation & Identity System Audit

A comprehensive auditing skill for evaluating security, game theory, and implementation risks in on-chain reputation systems, soulbound tokens (SBTs), and decentralized identity verification protocols.

## When to Use This Skill

Apply this audit framework when reviewing:

- **Reputation Systems**: On-chain credit scores, community standings, participation metrics
- **Soulbound Tokens (SBTs)**: Non-transferable credential tokens, achievements, certifications
- **Identity Verification**: KYC/KYB protocols, proof-of-personhood, unique human verification
- **Credential Systems**: Educational records, work history, skill attestations
- **Voting/Governance**: Quadratic voting, conviction voting, reputation-weighted governance
- **Airdrop/Distribution**: Anti-sybil mechanisms for token distributions
- **Cross-chain Identity**: Identity bridges, multi-chain reputation aggregation

## Quick Audit Checklist

### 🎯 Core Security Checks

#### Soulbound Token Implementation
- [ ] **Non-transferability enforcement**: Check that `transferFrom`, `safeTransferFrom`, and `approve` are disabled or always revert
- [ ] **Wallet recovery mechanism**: How do users recover SBTs if wallet is lost/compromised?
- [ ] **Revocation controls**: Who can burn/revoke SBTs? Is there a dispute process?
- [ ] **Minting authorization**: Multi-sig? DAO? Single admin? Centralization risk?
- [ ] **ERC-5192 compliance**: If claiming "soulbound," verify Locked event emission
- [ ] **Private key hygiene**: Are users warned about wallet security? Hardware wallet support?
- [ ] **Metadata immutability**: Can token metadata be changed post-mint? By whom?

#### Sybil Resistance
- [ ] **Cost of identity creation**: Economic cost to create fake identities (gas + fees)
- [ ] **Biometric requirements**: Face/iris/fingerprint scanning? Privacy implications?
- [ ] **Social graph analysis**: Does system analyze connections to detect bots?
- [ ] **Behavioral analysis**: Time-based reputation building to prevent instant farming?
- [ ] **Multi-signal verification**: Combining multiple proof types (CAPTCHA + social + on-chain activity)?
- [ ] **Attack cost analysis**: What's the dollar cost to create 1000 fake identities?
- [ ] **Collateral requirements**: Do users stake tokens that can be slashed?

#### Oracle & Verification Risks
- [ ] **Oracle centralization**: Single data source or aggregated from multiple providers?
- [ ] **Off-chain infrastructure security**: API security, database hardening, access control
- [ ] **Data freshness**: How often is oracle data updated? Can stale data be exploited?
- [ ] **Dispute mechanism**: Can users challenge incorrect verification results?
- [ ] **Oracle key management**: Are signing keys secured? Multi-sig? Hardware security?
- [ ] **Fallback behavior**: What happens if oracle goes offline or provides bad data?
- [ ] **Commit-reveal schemes**: Are they used to prevent freeloading/mirroring attacks?

#### Reputation Gaming & Farming
- [ ] **Self-dealing**: Can users create multiple accounts and boost each other?
- [ ] **Wash trading**: Can reputation be farmed through circular transactions?
- [ ] **Time manipulation**: Can users game timestamps or block numbers for advantage?
- [ ] **Collusion detection**: Are there mechanisms to detect coordinated farming?
- [ ] **Diminishing returns**: Do repeated actions yield less reputation over time?
- [ ] **Context separation**: Is reputation siloed per application or global?
- [ ] **Negative reputation**: Can bad actors be flagged? Is there a recovery path?

#### Privacy vs Auditability
- [ ] **Data minimization**: Is only necessary identity data collected?
- [ ] **Zero-knowledge proofs**: Are ZK-SNARKs/STARKs used to verify without revealing?
- [ ] **Selective disclosure**: Can users prove attributes without revealing full identity?
- [ ] **On-chain exposure**: What personal data is permanently on-chain vs off-chain?
- [ ] **GDPR compliance**: Right to be forgotten vs blockchain immutability conflict
- [ ] **Correlation attacks**: Can multiple credentials be linked to deanonymize users?
- [ ] **Surveillance risks**: Who can aggregate reputation data for profiling?

#### Reputation Decay & Recovery
- [ ] **Time-based decay**: Does reputation automatically decrease over time?
- [ ] **Activity requirements**: Must users maintain activity to keep reputation?
- [ ] **Recovery mechanisms**: Can users rebuild reputation after slashing/decay?
- [ ] **Penalty proportionality**: Are penalties fair relative to violations?
- [ ] **Grace periods**: Are there warnings before reputation loss?
- [ ] **Irreversible loss**: Are there actions that permanently destroy reputation?

#### Cross-Chain & Interoperability
- [ ] **Bridge security**: How are credentials transferred across chains? Trusted relays?
- [ ] **Canonical source of truth**: Which chain is authoritative for identity?
- [ ] **Sync failures**: What happens if cross-chain message fails?
- [ ] **Double-spend prevention**: Can same credential be used on multiple chains?
- [ ] **Chain-specific context**: Is reputation normalized across different chain ecosystems?
- [ ] **Bridge upgradability**: Can bridge contracts be upgraded? By whom?

### 🎮 Game Theory & Economic Concerns

#### Incentive Alignment
- [ ] **Honest behavior incentivized**: Is telling the truth more profitable than lying?
- [ ] **Attack profitability**: Cost-benefit analysis of gaming the system
- [ ] **Staking mechanics**: Are collateral requirements sufficient to deter attacks?
- [ ] **Slashing conditions**: Are penalties clear and enforceable?
- [ ] **Whale accumulation**: Can large holders dominate reputation systems?

#### Market Manipulation
- [ ] **Reputation markets**: Can reputation be bought/sold indirectly (account sales)?
- [ ] **Delegation risks**: If voting power can be delegated, can it be rented?
- [ ] **Proof-of-work bypasses**: Can users outsource identity tasks to others?
- [ ] **Lending/borrowing**: Can credentials be temporarily transferred via DeFi?

#### Systemic Risks
- [ ] **Centralization pressure**: Do economies of scale favor large operators?
- [ ] **Plutocracy risk**: Does reputation correlate too strongly with wealth?
- [ ] **Censorship resistance**: Can authorities block identity verification?
- [ ] **Exit strategy**: Can users migrate to alternative systems?

### 🔍 Implementation Quality

#### Smart Contract Security
- [ ] **Reentrancy protection**: ReentrancyGuard on state-changing functions
- [ ] **Access control**: Proper use of modifiers (onlyOwner, onlyMinter, etc.)
- [ ] **Integer overflow/underflow**: Using SafeMath or Solidity 0.8+
- [ ] **Gas optimization**: Efficient storage patterns, batch operations
- [ ] **Upgrade path**: Transparent proxy? Timelock? Immutable?
- [ ] **Emergency pause**: Circuit breaker for critical vulnerabilities?

#### Testing & Verification
- [ ] **Test coverage**: >90% line coverage, edge cases tested
- [ ] **Formal verification**: Critical functions formally verified
- [ ] **Economic simulations**: Agent-based modeling of attack scenarios
- [ ] **Professional audit**: Reputable firm audit with remediations completed
- [ ] **Bug bounty**: Active program with appropriate rewards

## Common Vulnerability Patterns

### 🚨 Critical Issues

**SBT Transfer Bypass**
```solidity
// VULNERABLE: Missing override or incorrect revert
function transferFrom(address from, address to, uint256 tokenId) public override {
    // Empty function or insufficient check
}

// SECURE: Explicitly revert all transfer attempts
function transferFrom(address from, address to, uint256 tokenId) public pure override {
    revert("SoulBound: Transfer not allowed");
}
```

**Oracle Manipulation via Flash Loans**
```solidity
// VULNERABLE: Using spot price directly
uint256 price = IUniswapPair(pair).getCurrentPrice();

// SECURE: Use time-weighted average price (TWAP)
uint256 price = oracle.consult(token, 1e18); // 10-minute TWAP
```

**Reputation Self-Boosting**
```solidity
// VULNERABLE: No self-referral prevention
function vouche(address target) external {
    reputation[target] += 1; // Can vouch for yourself with alt account
}

// SECURE: Prevent direct circular vouching
function vouch(address target) external {
    require(target != msg.sender, "Cannot vouch for yourself");
    require(!vouches[target][msg.sender], "Already vouched");
    // Additional: Check for reciprocal vouching patterns
}
```

**Centralized Oracle Key Compromise**
```solidity
// VULNERABLE: Single admin can update any identity
function verifyIdentity(address user, bytes memory proof) external onlyOwner {
    isVerified[user] = true;
}

// SECURE: Multi-sig or decentralized verification
function verifyIdentity(
    address user, 
    bytes memory proof,
    bytes[] memory signatures
) external {
    require(signatures.length >= QUORUM, "Insufficient signatures");
    // Verify signatures from multiple trusted verifiers
}
```

### ⚠️ High-Risk Patterns

**Sybil Attack via Cheap Identity**
- Creating identities costs less than the benefit gained
- No rate limiting on account creation
- Instant reputation without time-gating

**Privacy Leakage via On-Chain Data**
- Full names, addresses, or biometric data stored on-chain
- Metadata URIs pointing to personal information
- Correlation between wallet addresses and real identities

**Reputation Farming via Wash Trading**
- Users create circular transaction patterns
- Trading with self-controlled accounts
- No detection of coordinated behavior

**Oracle Freeloading**
- Nodes copy data from public APIs without verification
- No commit-reveal scheme to prevent data copying
- Centralization of data sources

## Real-World Incidents

See [references/real-issues.md](references/real-issues.md) for documented vulnerabilities from:
- Gitcoin Passport sybil attacks and farming strategies
- Worldcoin privacy concerns and biometric data risks
- ENS name squatting and impersonation
- Polygon ID and on-chain privacy tradeoffs
- Various SBT implementations with transfer vulnerabilities

## References

- [Sybil Resistance Patterns](references/sybil-resistance.md) - Anti-sybil mechanisms and their tradeoffs
- [Soulbound Token Security](references/soulbound-security.md) - SBT implementation best practices
- [Real Issues & Incidents](references/real-issues.md) - Case studies from production systems

## Additional Resources

**Research Papers:**
- "Decentralized Society: Finding Web3's Soul" - Vitalik Buterin et al. (2022)
- "SoK: Oracles from the Ground Truth to Market Manipulation" - Eskandari et al. (2021)
- "A First Look at Identity Management Schemes on the Blockchain" - Dunphy & Petitcolas (2018)

**Standards:**
- EIP-5192: Minimal Soulbound NFTs
- EIP-4973: Account-bound Tokens
- W3C Decentralized Identifiers (DIDs)
- W3C Verifiable Credentials Data Model

**Tools:**
- Chainlink Oracles for decentralized data feeds
- Tellor for censorship-resistant oracle data
- Semaphore for zero-knowledge identity proofs
- Gitcoin Passport for anti-sybil verification

---

**Last Updated:** 2026-02-05  
**Maintainer:** Security Research Team  
**Skill Version:** 1.0.0
