# Real P2P Security Incidents

Documentation of actual security vulnerabilities, attacks, and incidents from libp2p, IPFS, Filecoin, Ethereum, and other P2P networks.

---

## 1. IPFS Incidents

### 1.1 IPFS DHT Sybil Attack (2020)

**Incident**: Massive Sybil attack on IPFS DHT with hundreds of thousands of fake peers.

**Timeline**:
- Detected in May 2020
- Attackers generated peer IDs with specific prefixes
- Overwhelmed routing tables across the network
- Caused lookup failures and degraded performance

**Attack Details**:
- ~200,000 Sybil peers
- Targeted specific keyspace regions
- Used cloud infrastructure to generate IDs
- Exploited lack of Sybil resistance in DHT

**Impact**:
- Network-wide DHT disruption
- Content lookup failures
- Increased latency for DHT operations
- Exposed fundamental DHT vulnerability

**Response**:
- Implemented peer scoring improvements
- Added IP diversity checks
- Improved routing table management
- Enhanced monitoring and alerting

**Lessons Learned**:
- DHT requires Sybil resistance mechanisms
- IP-based filtering is necessary but insufficient
- Network monitoring is critical for attack detection
- Routing table diversity enforcement needed

**References**:
- [IPFS DHT Sybil Attack Report](https://blog.ipfs.tech/2020-05-20-dht-hardening/)

---

### 1.2 Bitswap Amplification DoS (2019)

**Incident**: Discovery of amplification vulnerability in Bitswap protocol.

**Vulnerability**:
- Attacker sends small WANT-BLOCK request
- Victim responds with full block (up to 256 KB)
- Amplification factor: ~2000x
- Can be used for DDoS reflection attacks

**Attack Scenario**:
```
1. Attacker spoofs victim IP
2. Sends WANT-BLOCK requests to many IPFS nodes
3. Nodes send full blocks to victim
4. Victim overwhelmed with unsolicited traffic
```

**Impact**:
- Potential for large-scale DDoS
- Bandwidth exhaustion
- IPFS nodes as unwitting amplifiers

**Mitigation**:
- Implemented rate limiting on block responses
- Added peer reputation system
- Changed to WANT-HAVE (metadata) by default
- Only send full blocks to trusted peers

**CVE**: Not formally assigned

**References**:
- Bitswap protocol updates (2019-2020)

---

### 1.3 IPFS Gateway Enumeration (Ongoing)

**Issue**: Public IPFS gateways can be used to enumerate pinned content.

**Privacy Implications**:
- Requesting content reveals interest
- Hosting content reveals inventory
- Traffic analysis can deanonymize users
- Gateway logs expose access patterns

**Attack Scenarios**:
- Surveillance of sensitive content access
- Censorship targeting
- User profiling

**Mitigations**:
- Use private gateways
- Implement content encryption
- Use anonymous access methods (Tor)
- Minimize gateway usage

**Status**: Inherent to current IPFS design

---

## 2. Ethereum P2P Incidents

### 2.1 Ethereum Eclipse Attack Research (2018)

**Research**: "Low-Resource Eclipse Attacks on Ethereum's Peer-to-Peer Network" by Marcus et al.

**Findings**:
- Eclipse attacks feasible with ~2 machines and moderate bandwidth
- Attacker can monopolize victim's peer connections
- Enables double-spend, consensus manipulation, mining attacks

**Attack Method**:
1. Attacker generates many peer IDs
2. Positions peers near victim in DHT
3. Exhausts victim's connection slots
4. Controls victim's view of blockchain

**Cost Analysis**:
- ~$1,500 per month to eclipse a node
- 2-3 machines sufficient
- Attack duration: hours to days

**Impact**:
- Transaction censorship
- Consensus disruption
- Mining advantages

**Response**:
- Connection diversity improvements
- Peer selection randomization
- Enode URL restrictions
- Monitoring tools

**References**:
- [Marcus et al. 2018 Paper](https://www.cs.bu.edu/~goldbe/projects/eclipseEth.pdf)

---

### 2.2 Ethereum Consensus Layer DoS (2021)

**Incident**: DoS vulnerability in Ethereum 2.0 consensus clients.

**Vulnerability**:
- Malicious peers send invalid attestations
- Triggers expensive signature verification
- Exhausts CPU resources
- Causes node stalls and missed duties

**Affected Clients**:
- Prysm (patched in v1.3.8)
- Lighthouse (patched in v1.4.0)
- Other clients implemented mitigations

**Attack Details**:
- Send malformed or invalid BLS signatures
- Force signature verification on every message
- Asymmetric cost: cheap to send, expensive to verify
- Can be amplified via GossipSub

**Impact**:
- Validator downtime
- Missed attestations and proposals
- Network instability

**Mitigation**:
- Early validation of message structure
- Rate limiting per peer
- Peer scoring for invalid messages
- Cache validation results

**CVE**: Various (client-specific)

**References**:
- Ethereum consensus client security advisories (2021)

---

### 2.3 Ethereum Discovery v4 Endpoint Proof DoS (2020)

**Vulnerability**: DoS in Ethereum Discovery v4 protocol.

**Details**:
- Endpoint proof validation was expensive
- Attacker sends many discovery packets with invalid proofs
- Forces expensive crypto operations
- Exhausts CPU resources

**Attack Vector**:
```
1. Send PING with invalid endpoint proof
2. Node attempts to validate proof
3. Validation fails after expensive computation
4. Repeat thousands of times
```

**Impact**:
- Discovery service disruption
- Peer discovery failures
- Node resource exhaustion

**Mitigation**:
- Cheap validation before expensive operations
- Rate limiting on discovery packets
- Peer reputation tracking
- Discovery v5 improvements

**Status**: Resolved, prompted upgrade to Discovery v5

---

## 3. Filecoin Incidents

### 3.1 Filecoin GossipSub Spam (2020-2021)

**Incident**: Block propagation attacks on Filecoin network.

**Attack**:
- Malicious miners spam invalid blocks
- Blocks propagate via GossipSub
- Network resources exhausted validating spam
- Delays legitimate block propagation

**Technical Details**:
- Invalid blocks are "cheap" to create
- Validation is expensive (proof verification)
- GossipSub amplifies spam network-wide
- Caused chain instability

**Impact**:
- Network slowdowns
- Increased orphan rate
- Miner disruption
- Wasted bandwidth and compute

**Response**:
- Implemented GossipSub v1.1 peer scoring
- Added block validation scoring
- Penalized peers for invalid blocks
- Rate limiting on block messages

**Lessons**:
- Validation cost asymmetry is dangerous
- Peer scoring is essential for consensus networks
- Application-level validation must be fast

---

### 3.2 Filecoin Retrieval Miner DoS (2021)

**Issue**: Retrieval miners vulnerable to resource exhaustion.

**Attack**:
- Client requests many retrievals simultaneously
- Miner allocates resources per request
- Resources exhausted before payment
- Client abandons requests

**Impact**:
- Miner downtime
- Economic attack (lost revenue)
- Network retrieval unavailability

**Mitigation**:
- Payment channels with upfront deposits
- Resource reservation system
- Connection limits per client
- Retrieval quotas

**Status**: Ongoing improvements in retrieval markets

---

## 4. Bitcoin P2P Incidents

### 4.1 Bitcoin Eclipse Attack (2015)

**Research**: "Eclipse Attacks on Bitcoin's Peer-to-Peer Network" by Heilman et al.

**Key Findings**:
- Attackers can eclipse Bitcoin nodes with limited resources
- Monopolize victim's 125 connection slots
- Only requires control of the victim's /16 subnet or AS

**Attack Vectors**:
- **Restart attack**: Fill connection slots during node restart
- **Table overflow**: Flood addr messages to poison AddrMan
- **BGP hijacking**: Control victim's network path

**Impact**:
- Double-spend attacks
- Mining pool disruption (selfish mining)
- Transaction censorship
- 0-confirmation fraud

**Bitcoin Core Response**:
- Anchor connections (persisted peers)
- Diversify peer selection
- Rate limit addr messages
- Test-before-evict for existing peers
- Randomized eviction

**References**:
- [Heilman et al. 2015 Paper](https://eprint.iacr.org/2015/263.pdf)

---

### 4.2 Bitcoin P2P Network DoS (2018)

**CVE-2018-17144**: Critical inflation bug with DoS component.

**Vulnerability**:
- Malicious peers could trigger node crashes
- DoS via specially crafted blocks
- Combined with consensus bug (inflation)

**Impact**:
- Widespread node crashes
- Network instability
- Emergency patching required

**Response**:
- Emergency Bitcoin Core release (0.16.3)
- Coordinated disclosure and patching
- Network monitoring during upgrade

**Lessons**:
- P2P layer is critical attack surface
- Fuzzing and testing essential
- Coordinated disclosure procedures needed

---

## 5. Polkadot / Substrate Incidents

### 5.1 Polkadot Discovery DHT Issues (2020)

**Issue**: DHT discovery problems in Polkadot network.

**Problems**:
- Validators failing to discover each other
- DHT lookups timing out
- Network partitions

**Root Causes**:
- Insufficient DHT server nodes
- NAT traversal failures
- Bootstrap node overload

**Impact**:
- Delayed block finality
- Validator disconnections
- Network instability

**Resolution**:
- Increased bootstrap node capacity
- Improved NAT traversal (Circuit Relay)
- DHT configuration tuning
- Dedicated discovery infrastructure

---

### 5.2 Substrate Notification Protocol Spam (2021)

**Vulnerability**: DoS in Substrate's notification protocol.

**Attack**:
- Spam notification protocol handshakes
- Exhaust node resources
- Prevent legitimate peer connections

**Mitigation**:
- Rate limiting on handshakes
- Connection prioritization
- Peer banning for abuse

**Status**: Patched in Substrate releases

---

## 6. BitTorrent DHT Incidents

### 6.1 BitTorrent DHT Sybil Attacks (Ongoing)

**Issue**: Large-scale Sybil attacks on BitTorrent DHT.

**Research Findings**:
- Academic research demonstrated massive Sybil networks
- Attackers monitor significant portion of DHT traffic
- Used for surveillance and research

**Attack Scale**:
- Millions of Sybil nodes observed
- Coverage of large keyspace regions
- Persistent monitoring infrastructure

**Privacy Implications**:
- Content access surveillance
- User behavior tracking
- Copyright enforcement (DMCA)

**Defenses**:
- Limited due to open network design
- BEP 0042: DHT Security Extension
- Rate limiting improvements

**Status**: Ongoing arms race

---

## 7. Academic Research Findings

### 7.1 "Hijacking Bitcoin: Routing Attacks" (2017)

**Research**: Apostolaki et al., 2017

**Key Findings**:
- BGP hijacking can partition Bitcoin network
- 13 AS operators can isolate 30% of nodes
- Only 3-4 ASes needed for specific attacks

**Attack Types**:
- **Partition attack**: Isolate network segments
- **Delay attack**: Slow block propagation

**Real-World Feasibility**: HIGH

**Impact**:
- Double-spend
- Selfish mining
- Consensus manipulation

**References**:
- [Apostolaki et al. 2017](https://btc-hijack.ethz.ch/)

---

### 7.2 GossipSub v1.1 Security Analysis (2020)

**Study**: Least Authority security audit of GossipSub v1.1

**Findings**:
- v1.0 vulnerable to multiple attacks
- v1.1 significantly improves security
- Peer scoring is effective defense
- Configuration is critical

**Identified Attacks (v1.0)**:
- Sybil attacks on mesh
- Cold boot attacks (joining/leaving)
- Flood publishing
- Mesh manipulation

**v1.1 Improvements**:
- Comprehensive peer scoring
- IP colocation penalties
- Opportunistic grafting
- Adaptive gossip

**References**:
- [GossipSub v1.1 Spec](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md)

---

### 7.3 "Low-Cost Traffic Analysis" on P2P Networks (2019)

**Research**: Multiple studies on P2P privacy

**Findings**:
- Traffic analysis reveals user behavior
- Timing attacks can deanonymize users
- Intersection attacks effective on pub/sub
- Metadata leaks even with encryption

**Affected Systems**:
- Bitcoin (transaction broadcasting)
- IPFS (content access patterns)
- Ethereum (validator identity)

**Defenses**:
- Tor/VPN usage
- Dummy traffic/cover traffic
- Dandelion protocol (Bitcoin)
- Mix networks

---

## 8. libp2p Specific CVEs

### 8.1 js-libp2p WebSocket DoS (2020)

**Vulnerability**: WebSocket connection exhaustion.

**Details**:
- Attacker opens many WebSocket connections
- Browser/node resources exhausted
- No connection limits enforced

**Impact**:
- js-libp2p node DoS
- Browser tab crashes

**Fix**: Connection manager improvements

---

### 8.2 go-libp2p Noise Protocol Implementation Bug (2021)

**Issue**: Handshake failure in certain scenarios.

**Details**:
- Edge case in Noise handshake
- Could cause connection failures
- Exploitable for targeted DoS

**Fix**: Patched in go-libp2p-noise v0.3.0

---

## 9. Lessons Learned

### Common Themes

1. **Sybil Resistance is Critical**
   - Almost all P2P networks face Sybil attacks
   - No silver bullet solution
   - Requires multiple defense layers

2. **Validation Cost Asymmetry is Dangerous**
   - Cheap to send, expensive to verify = DoS
   - Validate structure before crypto operations
   - Rate limiting essential

3. **DHT Security is Hard**
   - Eclipse attacks are practical and cheap
   - Routing table diversity crucial
   - Bootstrap security often overlooked

4. **GossipSub v1.1 is Necessary**
   - v1.0 is vulnerable to multiple attacks
   - Peer scoring provides robust defense
   - Proper configuration is critical

5. **Resource Limits are Essential**
   - Unbounded resources = DoS vulnerability
   - Every protocol operation needs limits
   - Monitoring is critical

6. **Privacy Requires Additional Layers**
   - P2P networks leak metadata
   - Traffic analysis is practical
   - E2EE insufficient for anonymity

### Best Practices

✅ **Do**:
- Implement comprehensive peer scoring
- Use multiple diverse bootstrap sources
- Rate limit all expensive operations
- Monitor network health continuously
- Fuzz protocol implementations
- Keep libp2p libraries updated
- Use Circuit Relay v2 (not v1)
- Enforce transport security

❌ **Don't**:
- Disable security for "performance"
- Use single bootstrap nodes
- Trust peer-provided data without validation
- Ignore resource management
- Assume honest majority
- Overlook NAT traversal abuse
- Skip security audits

---

## 10. Ongoing Threats

### Current Attack Landscape (2025)

- **Sybil attacks**: Remain primary threat
- **Eclipse attacks**: Still practical and cheap
- **GossipSub spam**: Ongoing in various networks
- **NAT relay abuse**: Growing concern
- **Privacy attacks**: Increasing sophistication

### Emerging Concerns

- **AI-driven attacks**: Adaptive attack patterns
- **Quantum threats**: Future cryptographic breaks
- **State-level attacks**: Nation-state DHT surveillance
- **Economic attacks**: Incentive manipulation in token networks

---

## Resources for Incident Tracking

- [IPFS Security Advisories](https://github.com/ipfs/go-ipfs/security/advisories)
- [Ethereum Security Research](https://github.com/ethereum/research/tree/master/security)
- [libp2p Security Issues](https://github.com/libp2p/libp2p/issues?q=is%3Aissue+label%3Asecurity)
- [Bitcoin Core CVE List](https://bitcoincore.org/en/security-advisories/)
- Academic conferences: IEEE S&P, NDSS, CCS, USENIX Security

---

**Last Updated**: 2025-01-26

**Note**: This document summarizes publicly disclosed incidents. Many vulnerabilities are privately disclosed and patched before public disclosure. Always check latest security advisories for specific projects.
