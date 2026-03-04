# P2P Network Attack Vectors

Comprehensive technical reference for common attack patterns against peer-to-peer networks, DHTs, and decentralized messaging systems.

---

## 1. Eclipse Attacks

### Overview
An eclipse attack isolates a target node by monopolizing its peer connections, allowing the attacker to control the victim's view of the network.

### Attack Mechanics

**DHT/Kademlia Eclipse:**
1. **Target Selection**: Attacker identifies victim node ID in the DHT keyspace
2. **ID Generation**: Attacker generates many peer IDs close to victim (XOR distance)
3. **Table Poisoning**: Malicious peers aggressively respond to routing table lookups
4. **Isolation**: Victim's k-buckets fill with attacker-controlled peers
5. **Exploitation**: Attacker controls all routing, data retrieval, and network view

**Connection-Level Eclipse:**
- Fill victim's connection slots with attacker-controlled peers
- Prevent victim from discovering honest peers
- MITM all incoming/outgoing traffic

### Impact
- Complete isolation from honest network
- False data injection (DHT poisoning)
- Censorship of specific content
- Double-spend attacks (blockchain context)
- Traffic analysis and deanonymization

### Detection
- Monitor routing table diversity
- Track connection churn patterns
- Verify peer reachability independently
- Measure network view consistency with trusted nodes

### Mitigations
- **Diverse peer selection**: Don't just choose closest peers
- **Test-before-add**: Verify peer reachability before routing table insertion
- **Random eviction**: Periodically replace table entries with random peers
- **Multiple bootstrap sources**: Don't rely on single entry points
- **Anomaly detection**: Monitor for sudden routing table homogeneity

---

## 2. Sybil Attacks

### Overview
Creating multiple fake identities (Sybil nodes) to gain disproportionate influence over the network.

### Attack Mechanics

**Identity Generation:**
- Generate thousands of peer IDs with minimal cost
- Position Sybil nodes strategically in keyspace
- Outnumber honest nodes in specific regions

**Attack Variations:**

**Sybil for Eclipse:** Surround target with Sybil identities

**Sybil for Vote Manipulation:** Overwhelm reputation/consensus systems

**Sybil for DoS:** Consume network resources with fake peers

**Sybil for Surveillance:** Monitor large portions of network traffic

### Impact
- Compromise DHT integrity
- Manipulate reputation systems
- Execute eclipse attacks at scale
- Degrade network performance
- Compromise privacy/anonymity
- Manipulate content routing

### Detection Challenges
- Difficult to distinguish legitimate peers from Sybil nodes
- Distributed systems lack central identity verification
- IP-based detection defeated by botnets/cloud VMs

### Mitigations
- **Proof-of-Work**: Expensive peer ID generation (Bitcoin-style)
- **Proof-of-Stake**: Tie identity to scarce resource (tokens, reputation)
- **Social Graph**: Leverage trust relationships (not always available)
- **IP Diversity**: Limit peers per subnet (weak but helpful)
- **Temporal Analysis**: New peers have lower trust initially
- **Resource Proof**: Require computational or storage commitments
- **Invite Systems**: Restricted entry via existing members

---

## 3. GossipSub Attacks

### Overview
Exploiting pub/sub messaging systems, particularly GossipSub used in libp2p networks.

### Attack Vectors

#### 3.1 Message Flooding
**Mechanism:**
- Subscribe to popular topics
- Spam messages at maximum rate
- Exploit eager-push propagation in GossipSub

**Impact:**
- Network-wide bandwidth exhaustion
- CPU exhaustion from signature verification
- Memory exhaustion from message queues

**Mitigations:**
- Per-peer message rate limits
- Topic-based rate limiting
- Peer scoring with message rate factor
- Backpressure mechanisms

#### 3.2 IHAVE/IWANT Amplification
**Mechanism:**
- Send IHAVE announcements for non-existent messages
- Force peers to send IWANT requests
- Never deliver actual messages
- Waste bandwidth and peer state

**Impact:**
- Bandwidth exhaustion from useless requests
- Degraded message delivery latency
- Peer resource exhaustion

**Mitigations:**
- Limit IWANT requests per peer
- Penalize peers with low delivery rates
- Timeout on unfulfilled IHAVE promises

#### 3.3 Mesh Manipulation (Grayhole)
**Mechanism:**
- Join topic mesh as a full peer
- Accept GRAFT but don't forward messages
- Act as a "black hole" in the mesh

**Impact:**
- Messages lost in transit
- Degraded topic reliability
- Increased latency for affected paths

**Mitigations:**
- Peer scoring based on message delivery
- Opportunistic grafting to maintain mesh health
- PRUNE low-scoring peers aggressively

#### 3.4 GRAFT Flooding
**Mechanism:**
- Send excessive GRAFT messages to join mesh
- Force peers to maintain large mesh state
- Repeatedly PRUNE and GRAFT (mesh churn)

**Impact:**
- Memory exhaustion from mesh state
- CPU exhaustion from mesh management
- Network churn and instability

**Mitigations:**
- Rate limit GRAFT acceptance per peer
- Penalize excessive PRUNE/GRAFT patterns
- Mesh size limits

#### 3.5 Message Replay
**Mechanism:**
- Capture valid signed messages
- Replay them later or in different contexts
- Bypass signature verification (message is valid)

**Impact:**
- Duplicate processing
- State confusion
- Cache poisoning

**Mitigations:**
- Include timestamp in signed payload
- Validate message freshness
- Maintain time-windowed seen cache
- Include context (chain head, epoch) in messages

---

## 4. DHT-Specific Attacks

### 4.1 Routing Table Poisoning
**Mechanism:**
- Respond to FIND_NODE with malicious peer addresses
- Inject false routing information
- Gradually replace honest peers in routing tables

**Impact:**
- Traffic redirection to attacker
- Data unavailability
- Eclipse attack enablement

**Mitigations:**
- Verify peer reachability before table insertion
- Cryptographic verification of peer IDs
- Regular routing table refresh
- Multiple redundant lookups

### 4.2 Sybil-Based Content Poisoning
**Mechanism:**
- Create Sybil nodes responsible for target content hash
- Return false/corrupted data for DHT GET requests
- Refuse to store data for DHT PUT requests

**Impact:**
- Data unavailability
- False data injection
- Censorship

**Mitigations:**
- Content-addressed storage (verify hash)
- Signature verification on mutable data
- Redundant storage across multiple providers
- Provider diversity requirements

### 4.3 Churn Attack
**Mechanism:**
- Rapidly join and leave the network
- Force constant routing table updates
- Exploit join/leave handler inefficiencies

**Impact:**
- CPU/bandwidth exhaustion from churn handling
- Routing table instability
- Lookup failures

**Mitigations:**
- Rate limit routing table updates
- Maintain stable peer set separate from churn
- Increase trust of long-lived peers

---

## 5. Peer Discovery Attacks

### 5.1 Bootstrap Node Compromise
**Mechanism:**
- Compromise or impersonate bootstrap nodes
- Return only attacker-controlled peers
- Achieve immediate eclipse on new joiners

**Impact:**
- Complete control over new nodes
- Network partition
- Widespread eclipse attacks

**Mitigations:**
- Multiple diverse bootstrap sources
- Hardcode bootstrap peer IDs (not just IPs)
- Out-of-band bootstrap verification
- Gradual trust increase for bootstrap peers

### 5.2 mDNS Spoofing (Local Network)
**Mechanism:**
- On local network, spoof mDNS announcements
- Advertise fake peers
- MITM local peer discovery

**Impact:**
- Local network eclipse
- Traffic interception
- Privacy compromise

**Mitigations:**
- Restrict mDNS to trusted networks
- Require connection authentication
- Prefer explicit bootstrap over mDNS

### 5.3 DHT Crawler/Monitoring
**Mechanism:**
- Systematically crawl DHT by walking routing tables
- Build complete network graph
- Monitor all peer connections and content

**Impact:**
- Privacy loss
- Network topology exposure
- Targeted attack planning

**Mitigations:**
- Limit routing table responses
- Randomize response ordering
- Rate limit queries from single sources

---

## 6. NAT Traversal & Relay Attacks

### 6.1 Relay Amplification
**Mechanism:**
- Use Circuit Relay as amplification vector
- Send small request, relay forwards large response
- Target victim with reflected traffic

**Impact:**
- Amplification DDoS
- Relay resource exhaustion
- Bandwidth abuse

**Mitigations:**
- Rate limit relay bandwidth per client
- Require authentication for relay use
- Implement Circuit Relay v2 limits
- Monitor relay usage patterns

### 6.2 Relay Resource Exhaustion
**Mechanism:**
- Open many circuits through relay
- Hold connections open indefinitely
- Exhaust relay connection/memory limits

**Impact:**
- Relay node unavailability
- Degraded NAT traversal for honest users

**Mitigations:**
- Connection limits per peer
- Timeout idle circuits
- Resource quotas per client
- Reservation system (Relay v2)

### 6.3 Hole Punching Abuse
**Mechanism:**
- Exploit STUN/TURN servers for mapping
- Use AutoNAT for reflection attacks
- Trigger excessive hole punching attempts

**Impact:**
- Network scanning via STUN reflection
- DDoS via triggered connections
- Resource exhaustion

**Mitigations:**
- Rate limit AutoNAT/hole punching requests
- Require proof-of-work for expensive operations
- Monitor for abuse patterns

---

## 7. Denial of Service Vectors

### 7.1 Connection Flooding
**Mechanism:**
- Open thousands of connections from distributed sources
- Exhaust file descriptors, memory, or connection tables
- Prevent legitimate peer connections

**Impact:**
- Complete node unavailability
- Network partition
- Service disruption

**Mitigations:**
- Connection limits (global, per-IP, per-peer-ID)
- Connection rate limiting
- Early connection drops for malicious patterns
- Resource reservation for known-good peers

### 7.2 Slowloris (Slow Protocol)
**Mechanism:**
- Open connections but send data very slowly
- Exploit protocol parsers that wait for complete messages
- Hold resources indefinitely

**Impact:**
- Resource exhaustion
- Connection table filling
- Degraded performance

**Mitigations:**
- Timeout incomplete protocol handshakes
- Minimum throughput requirements
- Kill slow connections aggressively

### 7.3 Computational DoS
**Mechanism:**
- Send messages requiring expensive verification
- Exploit asymmetric crypto costs (signature verification)
- Trigger expensive DHT lookups

**Impact:**
- CPU exhaustion
- Message processing delays
- Lookup failures

**Mitigations:**
- Rate limit expensive operations
- Verify cheap properties first (size, structure)
- Cache verification results
- Prioritize known-good peers

### 7.4 Memory Exhaustion
**Mechanism:**
- Send large messages or many messages
- Exploit unbounded caches (message ID cache)
- Fill message queues faster than processing

**Impact:**
- Out-of-memory crashes
- Swap thrashing
- System instability

**Mitigations:**
- Bounded message queues with backpressure
- Maximum message sizes
- Bounded caches with eviction policies
- Memory monitoring and circuit breakers

---

## 8. Privacy Attacks

### 8.1 Traffic Analysis
**Mechanism:**
- Monitor network traffic patterns
- Correlate message timing and sizes
- Deanonymize content publishers/subscribers

**Impact:**
- Loss of anonymity
- User activity profiling
- Content censorship targeting

**Mitigations:**
- Traffic padding to uniform sizes
- Random delays
- Onion routing or mix networks
- Cover traffic

### 8.2 Intersection Attacks
**Mechanism:**
- Monitor topic subscriptions across time
- Correlate peers subscribed to multiple topics
- Deanonymize by interest intersection

**Impact:**
- User identification
- Interest profiling
- Targeted surveillance

**Mitigations:**
- Private subscriptions (encrypted interests)
- Subscription anonymity sets
- Decoy subscriptions

### 8.3 Timing Attacks
**Mechanism:**
- Measure message propagation delays
- Triangulate message origin
- Identify content publishers

**Impact:**
- Publisher deanonymization
- Location approximation
- Targeted attacks

**Mitigations:**
- Random propagation delays
- Onion routing
- Uniform forwarding patterns
- Plausible deniability (forward messages you didn't originate)

---

## 9. Protocol-Level Exploits

### 9.1 Protocol Downgrade
**Mechanism:**
- Manipulate multistream-select negotiation
- Force use of weaker encryption or no encryption
- Exploit backward compatibility

**Impact:**
- Plaintext communication
- Weaker cryptography
- Protocol vulnerability exploitation

**Mitigations:**
- Enforce minimum security levels
- Disable insecure legacy protocols
- Mandatory transport encryption

### 9.2 Parser Exploits
**Mechanism:**
- Send malformed protocol messages
- Trigger buffer overflows, integer overflows
- Exploit deserialization vulnerabilities

**Impact:**
- Remote code execution
- Denial of service
- Memory corruption

**Mitigations:**
- Fuzzing protocol parsers
- Safe parsing libraries
- Input validation
- Memory-safe languages

### 9.3 State Machine Confusion
**Mechanism:**
- Send messages in unexpected protocol states
- Exploit missing state validation
- Trigger undefined behavior

**Impact:**
- Protocol deadlocks
- Resource leaks
- Crashes

**Mitigations:**
- Explicit state machine validation
- Reject messages in wrong states
- Comprehensive protocol testing

---

## Attack Combinations

Many attacks are more effective when combined:

- **Sybil + Eclipse**: Use Sybil nodes to eclipse targets
- **Eclipse + DHT Poisoning**: Total control of victim's data access
- **GossipSub Flood + Mesh Manipulation**: Amplify damage via broken mesh
- **Connection Flood + Computational DoS**: Exhaust multiple resource types
- **Bootstrap Compromise + Sybil**: Immediate network-wide compromise

## References & Further Reading

- "Eclipse Attacks on Bitcoin's Peer-to-Peer Network" (Heilman et al., 2015)
- "The Sybil Attack" (Douceur, 2002)
- "Kademlia: A Peer-to-peer Information System Based on the XOR Metric" (Maymounkov & Mazières, 2002)
- GossipSub v1.1 Security Audit (Least Authority, 2020)
- "Low-Resource Eclipse Attacks on Ethereum's Peer-to-Peer Network" (Marcus et al., 2018)
- libp2p Security Considerations (Protocol Labs)
- "The BitTorrent DHT Security Threat Model" (Bernhard, 2008)

---

**Last Updated**: 2025-01-26
