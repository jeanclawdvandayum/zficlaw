# Escrow & Dispute Systems Audit Skill

A comprehensive auditing framework for smart contract escrow mechanisms, dispute resolution protocols, and optimistic systems.

## 📋 What's Included

### [SKILL.md](./SKILL.md)
Main auditing guide with:
- **Quick audit checklist** (copy-paste ready for audit reports)
- **When to use this skill** (protocol types)
- **Common vulnerability patterns** with code examples
- **Economic attack taxonomy** (griefing, bribery, censorship)
- **Testing approaches** and invariant examples
- **Tools & resources** for deeper analysis

### [references/escrow-patterns.md](./references/escrow-patterns.md)
Design pattern analysis:
- 6 common escrow designs (simple, arbitrated, milestone, optimistic, HTLC, Schelling)
- Security properties of each pattern
- Known vulnerabilities and mitigations
- Anti-patterns to avoid
- Comparison matrix for choosing the right pattern

### [references/dispute-attacks.md](./references/dispute-attacks.md)
Attack vector catalog:
- **Griefing attacks** (low-cost fund locking)
- **Manipulation attacks** (evidence censorship, frontrunning, bribery)
- **Timing attacks** (challenge windows, timeout extension)
- **Economic attacks** (collateral insufficiency, free options)
- **Sybil & stake grinding**
- Griefing ratio analysis framework
- Defense-in-depth checklist

### [references/real-exploits.md](./references/real-exploits.md)
Historical incident analysis:
- **10 major exploits** with full technical breakdowns
- Nomad, Poly Network, Ronin ($625M), Parity ($280M frozen)
- Kleros, Aragon Court, THORChain, Arbitrum
- Root cause analysis for each
- Lessons learned and applied mitigations
- Audit checklist based on past exploits

## 🎯 How to Use

### For Auditors
1. **Start with SKILL.md** - Use the quick checklist during initial review
2. **Reference patterns** - Compare contract design to established patterns in `escrow-patterns.md`
3. **Check attack vectors** - Cross-reference against attacks in `dispute-attacks.md`
4. **Learn from history** - Review similar exploits in `real-exploits.md`

### For Developers
1. Review `escrow-patterns.md` to choose the right design
2. Study vulnerabilities in your chosen pattern
3. Implement mitigations from `dispute-attacks.md`
4. Test against historical exploit scenarios

### For Security Researchers
- Use as taxonomy for new attack discovery
- Submit pull requests with new exploit examples
- Extend economic attack analysis

## 🔍 Key Focus Areas

This skill emphasizes:

✅ **Economic Security**: Griefing ratios, collateral requirements, incentive alignment  
✅ **Timeout Safety**: Challenge windows, deadline bounds, MEV resistance  
✅ **Dispute Resolution**: Evidence handling, arbitrator trust, appeal mechanisms  
✅ **Optimistic Protocols**: Fraud proofs, finalization delays, bond economics  
✅ **Real-World Incidents**: Learning from $1B+ in historical exploits  

## 🛠️ Recommended Tools

- **Static Analysis**: Slither, Mythril, Securify
- **Fuzz Testing**: Echidna, Foundry (invariant tests)
- **Formal Verification**: Certora, K Framework
- **Economic Simulation**: Agent-based modeling for game theory
- **Monitoring**: OpenZeppelin Defender, Tenderly alerts

## 📊 Coverage

**Vulnerability Classes Covered:**
- Fund locking (permanent deadlock)
- Dispute griefing (spam attacks)
- Timeout manipulation (too short/long)
- Collateral insufficiency
- Arbitrator centralization risks
- Evidence submission issues
- Economic attack vectors
- Optimistic fraud proof games

**Protocol Types Covered:**
- Two-party escrow
- Multi-party escrow
- Milestone-based payments
- Optimistic bridges/rollups
- Dispute resolution (Kleros, Aragon)
- Payment channels (Lightning-style HTLCs)
- Crowdsourced arbitration

## 📚 Learning Path

**Beginner → Intermediate:**
1. Read SKILL.md checklist
2. Study Simple Two-Party and Arbitrated patterns
3. Review Nomad and Parity exploits (straightforward bugs)

**Intermediate → Advanced:**
1. Understand optimistic patterns and fraud proofs
2. Study economic attack taxonomy
3. Analyze Arbitrum delay attacks and game theory

**Advanced:**
1. Formal verification of dispute games
2. Novel attack vector research
3. Economic simulation of edge cases

## 🔄 Updates

This skill is based on vulnerabilities known as of **January 2025**. The landscape evolves:

- New exploits emerge → Update `real-exploits.md`
- New patterns deployed → Update `escrow-patterns.md`
- New attack vectors discovered → Update `dispute-attacks.md`

## 🤝 Contributing

Found a vulnerability pattern not covered? Discovered a new exploit?

1. Document the technical details
2. Explain root cause and mitigation
3. Add to appropriate reference document
4. Include links to postmortems/audits

## ⚠️ Disclaimer

This skill provides guidance based on historical research and known vulnerabilities. It is not exhaustive:

- New attack vectors are discovered constantly
- Each protocol has unique risks requiring custom analysis
- Use this as a starting point, not a complete audit
- Always engage professional auditors for production systems

## 📖 Further Resources

- **OpenZeppelin Docs**: Contracts and security patterns
- **Trail of Bits Blog**: Audit insights and tool development
- **Rekt News**: Latest exploit analysis
- **Kleros Research**: Dispute resolution game theory
- **Optimism/Arbitrum Specs**: Optimistic protocol designs

---

**Skill Version**: 1.0  
**Created**: 2025-01-24  
**Maintained By**: Security Research Team  
**License**: MIT (educational use)
