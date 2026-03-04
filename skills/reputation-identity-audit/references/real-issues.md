# Real-World Issues & Security Incidents

Documented vulnerabilities, attacks, and design failures from production reputation and identity systems.

## Gitcoin Passport

### Background
Gitcoin Passport is a multi-signal identity verification system designed to prevent sybil attacks in quadratic funding rounds. Users collect "stamps" from various sources to build a reputation score.

### Issue #1: Twitter Account Farming (2022)

**Attack Vector:**
- Attackers purchased aged Twitter accounts in bulk from account markets
- Each account had genuine followers and activity history
- Used these accounts to farm Gitcoin Passport stamps
- Created multiple Gitcoin identities, each with high Twitter verification scores

**Impact:**
- Thousands of fake identities passed verification
- Manipulated quadratic funding rounds
- Legitimate projects received less funding due to dilution

**Root Cause:**
- Twitter stamp only checked account age and follower count
- No behavioral analysis or activity pattern detection
- Account markets made bulk purchasing economical

**Resolution:**
- Reduced weight of Twitter verification in scoring
- Added more sophisticated Twitter activity analysis
- Introduced holistic scoring requiring diverse stamps

**Lessons:**
- Single verification signals are vulnerable to markets
- Account age alone is not sufficient proof of humanity
- Need multi-signal verification with weighted diversity

### Issue #2: POAP Farming (2022-2023)

**Attack Vector:**
- Virtual events issued POAPs to attendees via claim links
- Bots scraped Discord/Twitter for POAP claim links
- Single operator claimed thousands of POAPs across many wallets
- Used POAP holdings to boost Passport scores

**Impact:**
- POAP holder stamp became unreliable
- Event organizers had to implement additional verification
- Reduced overall confidence in attendance proofs

**Root Cause:**
- Public claim links with no additional verification
- No rate limiting on POAP claims per IP/device
- POAP protocol prioritized accessibility over security

**Resolution:**
- Gitcoin reduced POAP weight in scoring algorithm
- POAP introduced more sophisticated claim methods (QR codes, in-person only)
- Event organizers started using custom verification

**Lessons:**
- Attendance proofs need liveness verification
- Public claim links are vulnerable to bots
- Credentials lose value when easily farmed

### Issue #3: Binary Stamp Model Gaming (2024)

**Attack Vector:**
- New binary model required 21 unique stamps
- Attackers identified cheapest path to 21 stamps
- Bulk-created accounts across easy verification platforms
- Maintained just enough diversity to pass threshold

**Impact:**
- Cost per sybil identity remained economical (~$50-100)
- Large-scale farming still profitable for high-value grants
- Legitimate users frustrated by increasing verification burden

**Root Cause:**
- Fixed threshold created clear target for attackers
- Some stamps significantly easier to obtain than others
- Economic incentives (grant money) exceeded verification costs

**Ongoing Challenges:**
- Arms race between stamp requirements and farmers
- Balancing accessibility for legitimate users vs security
- Need for dynamic scoring and continuous monitoring

### Issue #4: Collusion Networks

**Attack Vector:**
- Groups of real people coordinated to vouch for fake identities
- Each real person created multiple "fake friend" accounts
- Leveraged social graph stamps (BrightID connections)
- Passed verification through authentic-looking social networks

**Impact:**
- Social graph verification became less reliable
- Difficult to detect organized collusion vs genuine community
- Some grant rounds manipulated by coordinated groups

**Detection Methods:**
- Graph analysis identified tightly connected clusters
- Unusual vouching patterns (everyone vouches for everyone)
- Lack of connections outside the closed group
- Similar transaction patterns across cluster

**Mitigation:**
- Reduce weight of social graph from closed networks
- Require diverse external connections
- Implement graph distance analysis
- Community reporting and investigation

## Worldcoin

### Background
Worldcoin uses iris-scanning "orbs" to verify unique human identity, issuing "World ID" credentials and WLD token distributions.

### Issue #1: Biometric Data Collection Concerns (2023)

**Privacy Risks:**
- Iris scans are permanent biometric identifiers
- Data breaches could expose unchangeable identity markers
- Potential for government surveillance and tracking
- No way to "reset" identity if compromised

**Regulatory Issues:**
- Investigations in Kenya, Germany, France
- GDPR compliance questions around consent
- Data storage and processing locations unclear
- Right to deletion conflicts with blockchain immutability

**Worldcoin's Response:**
- Claims iris data is deleted after verification
- Only hash stored on-chain, not raw biometric data
- Open-sourced verification protocol
- Personal Custody option for data control

**Remaining Concerns:**
- Trust in deletion claims (no way to verify)
- Potential for data retention by operators
- Government subpoenas could force data disclosure
- Future use of biometric databases unclear

### Issue #2: Orb Operator Fraud (2023)

**Attack Vector:**
- Third-party orb operators paid per signup
- Some operators created incentives for multiple scans
- Fraudulent signups with fake identities
- Operators kept verification rewards

**Incidents:**
- Reports of operators in developing countries paying people to scan multiple times
- Using makeup/contact lenses to fool iris scanners
- Creating fake accounts to inflate signup numbers
- Insider threats from orb operators

**Impact:**
- Credibility of "proof of personhood" undermined
- Some World IDs potentially not unique humans
- Geographic centralization of fraud

**Mitigation:**
- Enhanced liveness detection in orb software
- Operator accountability and auditing
- Cross-reference between orb operators
- Penalties for fraudulent verification

### Issue #3: Accessibility & Centralization (Ongoing)

**Concerns:**
- Limited orb locations (mainly urban, developed countries)
- Physical verification required (excludes disabled, remote users)
- Centralized hardware control (Worldcoin manufactures orbs)
- Hardware failure = identity system failure
- Cost of orbs limits decentralization

**Implications:**
- Geographic bias in identity distribution
- Power concentrated in Worldcoin foundation
- Vulnerable to government intervention/seizure
- Not truly permissionless or censorship-resistant

## Ethereum Name Service (ENS)

### Issue #1: Name Squatting & Impersonation (2017-Present)

**Attack Pattern:**
- Squatters register desirable names (company brands, common words)
- Hold names for ransom or impersonation
- Create phishing attacks using similar names
- Front-run popular name registrations

**Examples:**
- exchange.eth, binance.eth, coinbase.eth squatted early
- Impersonation of celebrities and companies
- Phishing sites using ENS names similar to legitimate projects
- MEV bots front-running name registrations

**Mitigation Attempts:**
- Premium pricing for short names (3-4 characters)
- Commit-reveal registration process
- DNSSEC integration for verified brand names
- Community reporting of impersonation

**Limitations:**
- Can't prevent all squatting without centralized control
- Name disputes require off-chain resolution
- No built-in proof that name holder is legitimate entity

### Issue #2: ENS as Identity Weakness (Ongoing)

**Problem:**
- ENS is transferable, unlike true soulbound credentials
- Users trust "vitalik.eth" but ownership can change
- No on-chain link to real-world identity
- Name can be sold, stolen, or lost

**Implications:**
- Using ENS alone for identity is insecure
- Need additional verification (Twitter link, website)
- Risk of impersonation after name transfer
- Not suitable for critical identity uses

### Issue #3: Subdomain Hijacking (2022)

**Attack Vector:**
- Parent domain owner can update subdomain records
- Some projects issued credentials as ENS subdomains
- Parent domain compromised = all subdomains controllable
- Credentials could be redirected or revoked

**Example:**
```
company.eth → owned by Company DAO
employee1.company.eth → issued to employee
employee2.company.eth → issued to employee

If company.eth is compromised, all employee subdomains can be hijacked
```

**Best Practice:**
- Use ENS for discovery, not as sole credential
- Combine with cryptographic signatures
- Store credentials in smart contracts, not ENS records
- Regular security audits of parent domain controls

## Polygon ID

### Issue #1: Privacy Leakage Through On-Chain Verification (2023)

**Design:**
- Zero-knowledge proof system for private credentials
- Users can prove attributes without revealing full identity
- Verifications happen on-chain for transparency

**Privacy Issue:**
- On-chain transaction reveals verifier address
- Timing analysis can link verifications to individuals
- Multiple verifications create correlation patterns
- Public blockchain = permanent record of verifications

**Example:**
```
User proves "age > 18" to bar.eth at timestamp X
Same user proves "income > $50k" to bank.eth at timestamp Y
Same wallet address → linkable identity profile
```

**Trade-off:**
- On-chain verification = transparency and composability
- Off-chain verification = better privacy, less composability
- No perfect solution for "private but verifiable"

### Issue #2: Oracle Dependency (Ongoing)

**Architecture:**
- Claims are attested by trusted issuers (oracles)
- Users hold ZK credentials based on attestations
- Verification checks oracle signature

**Risks:**
- Centralized issuers (governments, companies)
- Issuer key compromise = fake credentials
- No dispute mechanism if issuer malicious
- Censorship by issuers (refusing to attest)

**Example:**
- Government ID issuer goes rogue
- Issues credentials to bots or fake identities
- Entire system security depends on issuer honesty
- Users have no recourse if falsely denied

## Proof of Humanity

### Issue #1: Video Deepfake Attacks (2021-2022)

**Verification Process:**
- Users submit video holding sign with Ethereum address
- Community vouches for legitimate videos
- Challenged videos go to dispute resolution

**Attack Attempts:**
- Early deepfake videos created to fool verification
- Used existing public videos of real people
- Attempted to register multiple identities as same person
- Social engineering to get vouches

**Detection:**
- Community identified suspicious patterns
- Required live video with specific randomized requirements
- Multi-round challenge-response added
- Improved liveness detection

**Ongoing Arms Race:**
- Deepfake technology improving rapidly
- Video verification becoming less reliable
- Need for additional verification layers
- Moving toward multi-modal verification

### Issue #2: Vouching Cartels (2022)

**Vulnerability:**
- Users need existing members to vouch for them
- Vouchers risk deposit if vouching for bot
- Economic incentives for "vouching services"

**Attack:**
- Groups formed to vouch for fake identities
- Split vouching deposit if successful
- Coordinated challenge defense
- Systematic gaming of vouching mechanism

**Impact:**
- Multiple fake identities registered
- Reduced trust in vouching mechanism
- Increased scrutiny on new registrations
- Community split over how to address

**Mitigation:**
- Increased vouching requirements
- Reputation-weighted vouching power
- Stricter penalties for bad vouches
- Community investigation of suspicious patterns

## Optimism Attestation Station

### Issue #1: Attestation Spam (2023)

**Problem:**
- Anyone can issue attestations to any address
- No cost or permission required
- Wallets flooded with meaningless attestations
- Signal-to-noise ratio collapsed

**Impact:**
- Legitimate attestations buried in spam
- User experience degraded
- Difficult to determine which attestations matter
- Attestation marketplaces needed curation

**Responses:**
- UI filtering by trusted attesters
- Reputation systems for attesters
- User controls to ignore certain attesters
- Cost mechanisms considered but not implemented

### Issue #2: Negative Attestations (Design Challenge)

**Issue:**
- System allows negative attestations (e.g., "is scammer")
- No dispute or removal process
- False accusations cause reputational harm
- Defamation risk

**Trade-offs:**
- Censorship-resistant = can't delete attestations
- Uncensorable = vulnerable to abuse
- Free speech vs reputation protection
- No clear resolution

**Current State:**
- Negative attestations exist but UI discourages
- Community norms emerging
- Counter-attestations as defense
- Legal uncertainty around on-chain defamation

## Lessons Across All Systems

### Universal Vulnerabilities

1. **Single Point of Failure:**
   - Centralized oracles, admins, or verifiers
   - Key compromise = system compromise
   - Need decentralization at every layer

2. **Economic Attack Vectors:**
   - If benefit > cost, system will be gamed
   - Markets emerge for any valuable credential
   - Need multi-layered cost structures

3. **Privacy vs Security Trade-off:**
   - Public verification = correlation risk
   - Private verification = less composable
   - ZK helps but doesn't solve everything

4. **Recovery Paradox:**
   - True soulbound = lost wallet = lost identity
   - Recovery mechanism = attack surface
   - No perfect solution exists

5. **Reputation Markets:**
   - Any valuable reputation will be bought/sold
   - Account markets, vouching services, credential rental
   - Can't fully prevent off-chain coordination

### Best Practices Learned

✅ **Multi-Signal Verification:**
- Never rely on single proof type
- Combine Web2 + Web3 + biometric + social + behavioral
- Weight signals by sybil resistance strength

✅ **Continuous Verification:**
- One-time checks are insufficient
- Behavioral monitoring over time
- Reputation decay for inactive accounts

✅ **Economic Sustainability:**
- Verification costs must be reasonable long-term
- Can't rely on perpetual token incentives
- Need real value creation, not just farming

✅ **Privacy by Default:**
- Minimize on-chain personal data
- Use ZK proofs where possible
- Give users control over disclosures

✅ **Dispute Mechanisms:**
- False positives/negatives will happen
- Users need recourse and appeal
- Balance automation with human judgment

✅ **Community Involvement:**
- Decentralized systems need community governance
- Crowd wisdom detects novel attacks
- Regular audits and updates required

## Ongoing Research Areas

**Unsolved Problems:**

1. **Biometric Privacy:**
   - How to verify personhood without collecting/storing biometrics?
   - Can ZK proofs of biometric uniqueness work?
   - What happens when biometric databases leak?

2. **Credential Marketplaces:**
   - Can we prevent off-chain sale of soulbound credentials?
   - Is behavioral verification sufficient deterrent?
   - How to handle legitimate credential transfers (job change)?

3. **Cross-Chain Identity:**
   - How to sync identity across 100+ chains securely?
   - Which chain is canonical source of truth?
   - Bridge security for identity vs assets?

4. **AI & Bots:**
   - As AI improves, can it pass human verification?
   - Will proof-of-personhood become impossible?
   - Need new verification paradigms?

5. **Regulatory Compliance:**
   - GDPR right to deletion vs blockchain immutability
   - KYC requirements vs privacy
   - Jurisdiction for decentralized identity?

## Resources & Further Reading

**Incident Reports:**
- Paradigm Blog: "So You Want to Use a Price Oracle" - Oracle attack case studies
- Rekt News: Ongoing DeFi exploit coverage
- OpenZeppelin Security Audits: Public audit reports

**Research:**
- "Decentralized Society: Finding Web3's Soul" - Buterin, Weyl, Ohlhaver (2022)
- "SoK: Oracles from the Ground Truth to Market Manipulation" - Eskandari et al. (2021)
- "The State of Sybil Attacks" - Gitcoin Research (2023)

**Monitoring:**
- Immunefi Bug Bounties: Active vulnerability reports
- Code4rena Audit Contests: Crowd-sourced audits
- Etherscan Contract Verification: Public code review

---

**Last Updated:** 2026-02-05  
**Maintainer:** Security Research Team  
**Note:** This is a living document. Submit PRs with new incidents and lessons learned.
