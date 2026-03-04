---
name: p2p-network-audit
description: "Security audit for P2P networks, libp2p-based systems, DHT networks, GossipSub implementations, and decentralized messaging protocols."
metadata:
  tags: "security, p2p, libp2p, dht, gossipsub, audit, blockchain"
---

# P2P Network Security Audit

## Overview

This skill provides a comprehensive checklist and methodology for auditing peer-to-peer network security, with focus on libp2p-based systems, Distributed Hash Tables (DHT), GossipSub pub/sub, and decentralized messaging protocols.

**Target Systems:**
- libp2p-based applications (IPFS, Filecoin, Ethereum 2.0, Polkadot)
- Custom DHT/Kademlia implementations
- GossipSub messaging networks
- Decentralized chat/messaging apps
- Blockchain P2P layers

## When to Use This Skill

✅ **Use when:**
- Auditing decentralized application networking layers
- Reviewing P2P protocol implementations
- Assessing libp2p integration security
- Evaluating DHT/Kademlia deployments
- Testing GossipSub or pub/sub messaging
- Investigating P2P DoS vulnerabilities
- Reviewing peer discovery mechanisms
- Assessing NAT traversal implementations

## Core Security Audit Checklist

### 1. 🔍 Identity & Authentication

#### Peer Identity
- [ ] Are peer IDs cryptographically derived from public keys?
- [ ] Is private key material properly protected?
- [ ] Can peer IDs be spoofed or replayed?
- [ ] Is there identity verification on connection establishment?
- [ ] Are identity proofs properly validated?

#### Sybil Resistance
- [ ] What prevents a single attacker from creating unlimited identities?
- [ ] Is there proof-of-work, proof-of-stake, or other Sybil resistance?
- [ ] Are there rate limits on peer connections from single sources?
- [ ] Is reputation or stake factored into routing decisions?
- [ ] Can an attacker cheaply flood the network with fake peers?

### 2. 🌐 DHT / Kademlia Security

#### Eclipse Attack Prevention
- [ ] Can an attacker monopolize a node's routing table?
- [ ] Are routing table entries diversified across the keyspace?
- [ ] Is there randomness in peer selection that prevents targeting?
- [ ] Are bootstrap nodes hardcoded or from trusted sources?
- [ ] Can an attacker isolate specific nodes or keyspace regions?

#### Routing Table Poisoning
- [ ] Are routing table updates authenticated?
- [ ] Can malicious peers inject false routing information?
- [ ] Is there validation of peer reachability before table insertion?
- [ ] Are there eviction policies that prevent malicious persistence?
- [ ] Can an attacker perform route hijacking or traffic interception?

#### DHT Content Security
- [ ] Are DHT values signed by publishers?
- [ ] Can an attacker return false data for lookups?
- [ ] Is there verification that returned peers actually have the content?
- [ ] Are DHT put/get operations rate-limited?
- [ ] Can malicious peers refuse to store or forward data?

### 3. 📡 GossipSub / Pub/Sub Security

#### Message Flooding & Amplification
- [ ] Are there per-peer message rate limits?
- [ ] Can a single peer trigger message amplification across the network?
- [ ] Is there duplicate message detection (message ID dedup)?
- [ ] Are oversized messages rejected?
- [ ] Can an attacker subscribe to topics and refuse to participate?

#### Topic Mesh Security
- [ ] Can an attacker manipulate topic mesh topology (mesh attack)?
- [ ] Are GRAFT/PRUNE operations rate-limited?
- [ ] Is there scoring/reputation for mesh peers?
- [ ] Can malicious peers isolate honest peers from topics?
- [ ] Are there protections against mesh oscillation attacks?

#### Message Authenticity
- [ ] Are messages cryptographically signed by originators?
- [ ] Is signature verification mandatory before forwarding?
- [ ] Can an attacker replay old messages?
- [ ] Are message IDs globally unique and properly validated?
- [ ] Is there timestamp validation to prevent stale messages?

### 4. 🔌 Peer Discovery & Connectivity

#### Bootstrap & Discovery
- [ ] Are bootstrap nodes from trusted, diverse sources?
- [ ] Can an attacker MITM the bootstrap process?
- [ ] Is mDNS discovery isolated to trusted networks?
- [ ] Are peer discovery mechanisms rate-limited?
- [ ] Can malicious peers advertise false multiaddrs?

#### Connection Security
- [ ] Is transport encryption mandatory (TLS, Noise, etc.)?
- [ ] Are connection upgrade protocols authenticated?
- [ ] Can an attacker downgrade to insecure transports?
- [ ] Are there limits on concurrent connections per peer?
- [ ] Is connection handshake DoS-resistant?

#### NAT Traversal & Relays
- [ ] Can relay nodes be abused for amplification attacks?
- [ ] Are relay resources rate-limited per user?
- [ ] Can an attacker cause resource exhaustion via relay abuse?
- [ ] Is relay selection authenticated or based on reputation?
- [ ] Are Circuit Relay v2 limits properly configured?

### 5. 🚫 Denial of Service Vectors

#### Resource Exhaustion
- [ ] Are there connection limits (per IP, per peer ID)?
- [ ] Can an attacker open thousands of connections?
- [ ] Are memory pools bounded for message queues?
- [ ] Is CPU usage limited for signature verification?
- [ ] Are there bandwidth throttles per peer?

#### Protocol-Level DoS
- [ ] Can an attacker send malformed messages to crash nodes?
- [ ] Are there limits on DHT lookups per timeframe?
- [ ] Can an attacker trigger expensive operations repeatedly?
- [ ] Is there backpressure for slow consumers?
- [ ] Are there protections against slowloris-style attacks?

#### Network-Level DoS
- [ ] Can an attacker partition the network?
- [ ] Are there protections against routing disruption?
- [ ] Can malicious peers blackhole traffic?
- [ ] Is there distributed ban/reputation sharing?
- [ ] Can an attacker isolate critical network infrastructure?

### 6. 🔐 Message & Data Security

#### End-to-End Encryption
- [ ] Is E2EE implemented for sensitive data?
- [ ] Are ephemeral keys used for forward secrecy?
- [ ] Can intermediate peers read message contents?
- [ ] Is metadata (sender, recipient, size) protected?
- [ ] Are there protections against traffic analysis?

#### Replay & Freshness
- [ ] Are messages timestamped and validated?
- [ ] Can old messages be replayed successfully?
- [ ] Is there a nonce or sequence number system?
- [ ] How long are message IDs cached for deduplication?
- [ ] Can an attacker exploit the dedup cache?

#### Data Availability
- [ ] Can an attacker prevent data retrieval?
- [ ] Is there redundancy for critical data?
- [ ] Are content providers incentivized to remain honest?
- [ ] Can malicious providers return corrupted data?
- [ ] Is there verification (hashing) for retrieved content?

### 7. 🏛️ Architecture Review

#### Centralization Risks
- [ ] Are there single points of failure?
- [ ] Do hardcoded bootstrap nodes create central risk?
- [ ] Can a small set of peers control network behavior?
- [ ] Is there geographical or organizational centralization?
- [ ] Are there incentive misalignments that favor centralization?

#### Upgrade & Governance
- [ ] How are protocol upgrades deployed?
- [ ] Can an attacker exploit version mismatches?
- [ ] Is there backward compatibility that preserves security?
- [ ] Are deprecated features properly disabled?
- [ ] Can governance be attacked or manipulated?

## Red Flags in P2P Design

🚩 **Critical Issues:**
- No signature verification on DHT or gossip messages
- Unlimited connections or message rates per peer
- Hardcoded or single bootstrap node dependencies
- No Sybil resistance mechanisms
- Unauthenticated peer discovery
- Missing transport encryption enforcement
- No eclipse attack mitigations in DHT
- Unbounded resource consumption (memory, CPU, bandwidth)

⚠️ **Warning Signs:**
- Reliance on IP addresses for identity or reputation
- Complex protocol that's hard to implement correctly
- No peer scoring or reputation system
- Missing rate limits on expensive operations
- No circuit breakers for DoS conditions
- Inadequate testing of adversarial scenarios
- Missing monitoring/observability for attacks

## Testing Methodology

### 1. Network Simulation
```bash
# Use testground or custom simnet for adversarial testing
- Spawn malicious nodes with modified behavior
- Test eclipse attacks by surrounding target nodes
- Inject Sybil nodes and measure impact
- Simulate network partitions and delays
```

### 2. Protocol Fuzzing
```bash
# Fuzz libp2p handshakes, DHT messages, GossipSub
- Send malformed protocol messages
- Test edge cases in parsers
- Attempt protocol downgrades
- Validate error handling
```

### 3. Load Testing
```bash
# Stress test with realistic adversarial loads
- Connection flooding
- Message spam across topics
- DHT query storms
- Relay abuse scenarios
```

### 4. Traffic Analysis
```bash
# Monitor for metadata leaks and timing attacks
- Analyze message patterns
- Correlate peers with activities
- Measure timing side channels
- Test anonymity properties
```

## Tools & Resources

**Analysis Tools:**
- `libp2p-daemon` - Standalone libp2p daemon for testing
- `gossipsub-simulator` - GossipSub network simulator
- `DHT-crawler` - Crawl and analyze DHT networks
- `peergos/nabu` - P2P network analysis
- Wireshark with libp2p dissectors

**Key Resources:**
- libp2p specifications (https://github.com/libp2p/specs)
- GossipSub spec (v1.1 with hardening)
- Kademlia paper (Maymounkov & Mazières)
- Ethereum P2P security research
- IPFS security documentation

**References:**
- See `references/attack-vectors.md` for detailed attack descriptions
- See `references/libp2p-security.md` for libp2p-specific concerns
- See `references/real-incidents.md` for documented P2P exploits

## Reporting Guidelines

**Security Report Structure:**
1. **Executive Summary** - High-level findings
2. **Architecture Overview** - P2P topology and design
3. **Critical Findings** - Exploitable vulnerabilities
4. **Attack Scenarios** - Practical exploitation paths
5. **Medium/Low Issues** - Design weaknesses
6. **Recommendations** - Prioritized mitigations
7. **Testing Evidence** - PoCs, logs, network captures

**Severity Classification:**
- **Critical**: Active exploitation leads to network compromise, eclipse attacks, complete DoS
- **High**: Sybil attacks, message forgery, significant resource exhaustion
- **Medium**: Partial DoS, metadata leaks, reputation manipulation
- **Low**: Minor information disclosure, edge case handling

## Common Mitigations

### Eclipse Attack Defense
- Randomized routing table management
- Multiple diverse bootstrap sources
- Regular routing table refresh with random peers
- Cross-verification of DHT responses

### Sybil Attack Defense
- Proof-of-work on peer ID generation
- Connection limits per IP/subnet
- Reputation/stake-based routing
- Temporal analysis of peer behavior

### GossipSub Hardening
- Peer scoring (v1.1+)
- Message rate limiting
- IWANT/IHAVE request limits
- Mesh peer selection based on reputation

### DoS Prevention
- Connection throttling
- Backpressure mechanisms
- Resource quotas per peer
- Circuit breakers for anomalous behavior

---

## Skill Maintenance

**Last Updated**: 2025-01-26
**Maintainer**: Security Research Team
**Related Skills**: blockchain-audit, api-security, cryptography-review

For detailed technical references, see the `references/` directory.
