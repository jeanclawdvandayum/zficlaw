# Reputation & Identity System Audit Skill

A comprehensive security auditing framework for on-chain reputation systems, soulbound tokens (SBTs), and decentralized identity verification protocols.

## Overview

This skill provides structured guidance for security researchers and auditors evaluating Web3 identity and reputation systems. It covers technical vulnerabilities, game-theoretic attack vectors, privacy considerations, and real-world lessons from production systems.

## Skill Structure

```
reputation-identity-audit/
├── README.md                          # This file
├── SKILL.md                           # Main audit checklist and methodology
└── references/
    ├── sybil-resistance.md            # Anti-sybil mechanisms deep-dive
    ├── soulbound-security.md          # SBT implementation security
    └── real-issues.md                 # Documented incidents and lessons
```

## Quick Start

1. **Start with [SKILL.md](SKILL.md)** - Core audit checklist covering:
   - When to use this skill
   - Quick audit checklist (7 major categories)
   - Common vulnerability patterns with code examples
   - Game theory and economic considerations

2. **Deep-dive into references as needed:**
   - **[sybil-resistance.md](references/sybil-resistance.md)** - If auditing sybil prevention mechanisms
   - **[soulbound-security.md](references/soulbound-security.md)** - If reviewing SBT implementations  
   - **[real-issues.md](references/real-issues.md)** - For case studies and lessons learned

## Key Audit Categories

### 🛡️ Technical Security
- SBT transfer prevention (ERC-721 override completeness)
- Oracle manipulation and data integrity
- Smart contract access controls and upgradeability
- Key management and recovery mechanisms
- Metadata immutability and content addressing

### 🎮 Game Theory & Economics
- Reputation farming and gaming attacks
- Sybil attack cost-benefit analysis
- Collusion detection and prevention
- Incentive alignment for honest behavior
- Market manipulation risks

### 🕵️ Privacy & Compliance
- On-chain data exposure and correlation
- Zero-knowledge proof implementation
- GDPR compliance (right to deletion)
- Selective disclosure mechanisms
- Biometric data handling

### 🌐 Systemic Risks
- Centralization points and single points of failure
- Cross-chain identity bridging security
- Dispute and appeal mechanisms
- Censorship resistance
- Long-term sustainability

## When to Use This Skill

Apply this audit framework when reviewing:

- **Reputation Systems** - Community scores, credit ratings, trust metrics
- **Soulbound Tokens** - Non-transferable credentials and achievements
- **Identity Verification** - KYC/KYB, proof-of-personhood, unique human verification
- **Voting & Governance** - Reputation-weighted decision making
- **Airdrop Distribution** - Anti-sybil token allocation
- **Credential Systems** - Educational records, professional certifications

## Coverage

### Systems Analyzed
- **Gitcoin Passport** - Multi-signal sybil resistance
- **Worldcoin** - Biometric proof-of-personhood
- **Ethereum Name Service (ENS)** - Decentralized naming
- **Polygon ID** - Zero-knowledge credentials
- **Proof of Humanity** - Social verification
- **Optimism Attestation Station** - Open attestation layer

### Vulnerability Types
- Transfer bypass in soulbound tokens
- Oracle manipulation via flash loans
- Reputation self-boosting and wash trading
- Sybil attacks through cheap identity creation
- Privacy leakage via on-chain correlation
- Centralized oracle key compromise
- Account farming and credential marketplaces
- Deepfake and biometric spoofing

### Standards Covered
- **ERC-5192** - Minimal Soulbound NFTs
- **ERC-4973** - Account-bound Tokens
- **ERC-721** - NFT standard (with transfer restrictions)
- **W3C DIDs** - Decentralized Identifiers
- **W3C VCs** - Verifiable Credentials

## Usage Examples

### Auditing a Soulbound Token Contract

```solidity
// 1. Check SKILL.md "Soulbound Token Implementation" section
// 2. Verify all transfer functions explicitly revert
// 3. Review references/soulbound-security.md for:
//    - Transfer bypass patterns
//    - Recovery mechanism risks
//    - Revocation security
// 4. Cross-reference with real-issues.md for known vulnerabilities
```

### Evaluating Sybil Resistance

```markdown
1. Identify verification mechanisms used
2. Consult references/sybil-resistance.md for:
   - Mechanism comparison matrix
   - Known attack vectors
   - Cost-benefit analysis
3. Use SKILL.md "Sybil Resistance" checklist
4. Review relevant incidents in real-issues.md
```

### Oracle Security Review

```markdown
1. Check SKILL.md "Oracle & Verification Risks" section
2. Review references/real-issues.md for oracle incidents
3. Verify multi-oracle aggregation
4. Check commit-reveal schemes for freeloading prevention
5. Analyze economic cost of manipulation
```

## Code Example Highlights

The skill includes secure and vulnerable code patterns for:

- ✅ / ❌ SBT transfer prevention
- ✅ / ❌ Oracle manipulation resistance  
- ✅ / ❌ Reputation self-boosting prevention
- ✅ / ❌ Centralized vs decentralized verification
- ✅ / ❌ Metadata mutability

See [SKILL.md](SKILL.md#common-vulnerability-patterns) for full examples.

## Real-World Lessons

Key takeaways from production incidents:

1. **Single signals fail** - Multi-signal verification is essential
2. **Economics matter** - If benefit > cost, systems will be gamed
3. **Privacy is hard** - On-chain verification creates correlation risks
4. **No perfect recovery** - Soulbound + recovery = inherent tension
5. **Markets emerge** - Valuable credentials will be bought/sold
6. **Community crucial** - Decentralized systems need active governance

See [real-issues.md](references/real-issues.md) for detailed case studies.

## Contributing

This skill is designed to evolve with the ecosystem. To contribute:

1. Document new incidents in `references/real-issues.md`
2. Add vulnerability patterns to `SKILL.md`
3. Update anti-sybil mechanisms in `references/sybil-resistance.md`
4. Submit emerging SBT security issues to `references/soulbound-security.md`

## Resources

**Research Papers:**
- "Decentralized Society: Finding Web3's Soul" (Buterin et al., 2022)
- "SoK: Oracles from the Ground Truth to Market Manipulation" (Eskandari et al., 2021)

**Security Tools:**
- Slither - Static analysis for Solidity
- Mythril - Security analysis tool
- Echidna - Fuzzing tool for smart contracts

**Audit Firms:**
- OpenZeppelin, Trail of Bits, Consensys Diligence, Hacken, Code4rena

**Standards:**
- https://eips.ethereum.org/EIPS/eip-5192 (Soulbound NFTs)
- https://www.w3.org/TR/did-core/ (Decentralized Identifiers)

---

**Version:** 1.0.0  
**Created:** 2026-02-05  
**Maintainer:** Security Research Team  
**License:** MIT (for documentation), Audit use unrestricted
