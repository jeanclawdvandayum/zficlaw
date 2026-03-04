# libp2p Security Considerations

Deep dive into security aspects specific to libp2p implementations, configurations, and common pitfalls.

---

## Overview

libp2p is a modular networking stack for P2P applications, used by IPFS, Filecoin, Ethereum 2.0, Polkadot, and others. This document covers libp2p-specific security concerns beyond general P2P attack vectors.

## libp2p Architecture Components

### Core Components
- **Transport Layer**: TCP, QUIC, WebSocket, WebRTC
- **Security Layer**: TLS 1.3, Noise Protocol
- **Stream Multiplexing**: yamux, mplex
- **Peer Routing**: DHT (Kademlia), mDNS, rendezvous
- **Content Routing**: DHT-based content discovery
- **Pub/Sub**: GossipSub, FloodSub
- **NAT Traversal**: AutoNAT, Circuit Relay, Hole Punching
- **Peer Discovery**: Bootstrap, DHT walking, mDNS

---

## 1. Transport Security

### 1.1 Mandatory Encryption

**Issue**: libp2p allows disabling transport security for testing.

**Risk**:
- Plaintext communication in production
- Credential leakage
- Message tampering

**Audit Checks**:
```go
// Go example - ensure security is not disabled
// BAD:
securityNone := libp2p.NoSecurity

// GOOD:
securityTLS := libp2p.Security(tls.ID, tls.New)
securityNoise := libp2p.Security(noise.ID, noise.New)
```

**Recommendations**:
- ✅ Enforce TLS 1.3 or Noise Protocol
- ✅ Never use `NoSecurity` in production
- ✅ Reject connections without encryption
- ✅ Audit configuration for disabled security

### 1.2 Transport Selection

**Issue**: Different transports have different security properties.

**Transport Comparison**:
| Transport | Security | NAT Traversal | Performance |
|-----------|----------|---------------|-------------|
| TCP+Noise | ✅ Strong | ❌ Poor | ⚡ Fast |
| QUIC | ✅ Strong (TLS 1.3) | ✅ Good | ⚡ Fast |
| WebSocket | ⚠️ Depends on WS security | ❌ Poor | 🐌 Moderate |
| WebRTC | ✅ DTLS | ✅ Excellent | ⚡ Fast |

**Audit Checks**:
- Verify transport encryption is enforced
- Check if insecure WebSocket (ws://) is disabled
- Prefer QUIC or WebRTC for public networks

---

## 2. Peer Identity & Authentication

### 2.1 Peer ID Generation

**Secure Generation**:
```javascript
// Peer ID is derived from public key
const peerId = await PeerId.create({ bits: 2048, keyType: 'RSA' })
// OR
const peerId = await PeerId.create({ keyType: 'Ed25519' })
```

**Audit Checks**:
- [ ] Are peer IDs cryptographically derived from public keys?
- [ ] Is key material >= 2048 bits (RSA) or Ed25519?
- [ ] Are private keys stored securely (not in code/config)?
- [ ] Is peer ID verified during connection handshake?

**Vulnerability**: If peer IDs can be spoofed or are not tied to crypto keys, identity attacks become trivial.

### 2.2 Connection Security Handshake

**Noise Protocol Flow**:
1. Peers exchange ephemeral keys
2. Compute shared secret
3. Authenticate via static keys (peer IDs)
4. Establish encrypted channel

**TLS 1.3 Flow**:
1. Standard TLS 1.3 handshake
2. Peer IDs embedded in certificate extensions
3. Verify peer ID matches public key

**Audit Checks**:
- Verify handshake completes before data exchange
- Ensure peer ID is validated against certificate
- Check for protocol downgrade attacks
- Verify ephemeral keys are used (forward secrecy)

---

## 3. DHT (Kademlia) Configuration

### 3.1 Routing Table Security

**Critical Configuration**:
```go
// Go-libp2p DHT options
dht.RoutingTableRefreshPeriod(10 * time.Minute)  // Regular refresh
dht.RoutingTableRefreshQueryTimeout(5 * time.Second)
```

**Audit Checks**:
- [ ] Is routing table refresh enabled?
- [ ] Are refresh intervals reasonable (not too long)?
- [ ] Is there diversity enforcement in k-buckets?
- [ ] Are unreachable peers evicted promptly?

**Eclipse Prevention**:
- Use `dht.RoutingTableFilter` to enforce diversity
- Implement custom bucket filters for critical applications
- Monitor routing table composition

### 3.2 DHT Mode Selection

**Modes**:
- **Client Mode**: Only queries, doesn't serve
- **Server Mode**: Participates fully in DHT
- **Auto Mode**: Switches based on NAT/reachability

**Security Implications**:
- Client-only nodes are less vulnerable but don't contribute
- Server nodes must handle DHT attacks robustly
- Auto mode can be exploited to force server mode

**Audit Checks**:
- Verify DHT mode matches security requirements
- Ensure server mode has DoS protections
- Check if auto mode transitions are secure

### 3.3 DHT Query Configuration

```go
// Query parameters affect security/performance
dht.Concurrency(10)           // Parallel query factor (α)
dht.QueryTimeout(60 * time.Second)
dht.MaxRecordAge(36 * time.Hour)
```

**Audit Checks**:
- [ ] Are query timeouts reasonable to prevent stalling?
- [ ] Is concurrency limited to prevent query storms?
- [ ] Are DHT records validated before use?
- [ ] Is there rate limiting on queries?

---

## 4. GossipSub Hardening

### 4.1 GossipSub v1.1 Peer Scoring

**Critical Feature**: Peer scoring is the primary defense against GossipSub attacks.

**Score Components**:
- **Topic Behavior**: Message delivery, invalid messages
- **Mesh Behavior**: GRAFT/PRUNE patterns, mesh time
- **IP Colocation**: Penalize multiple peers from same IP
- **Application-Specific**: Custom scoring based on app logic

**Configuration Example** (Go):
```go
psub, err := pubsub.NewGossipSub(ctx, host,
    pubsub.WithPeerScore(
        &pubsub.PeerScoreParams{
            Topics: map[string]*pubsub.TopicScoreParams{
                "important-topic": {
                    TimeInMeshWeight:  0.0027,
                    TimeInMeshQuantum: time.Second,
                    TimeInMeshCap:     3600,
                    FirstMessageDeliveriesWeight: 0.664,
                    FirstMessageDeliveriesDecay:  0.9916,
                    FirstMessageDeliveriesCap:    2000,
                    MeshMessageDeliveriesWeight:    -0.25,
                    MeshMessageDeliveriesDecay:     0.97,
                    MeshMessageDeliveriesThreshold: 20,
                    MeshMessageDeliveriesCap:       200,
                    MeshMessageDeliveriesWindow:    5 * time.Second,
                    MeshFailurePenaltyWeight:       -0.25,
                    MeshFailurePenaltyDecay:        0.997,
                    InvalidMessageDeliveriesWeight: -774.48,
                    InvalidMessageDeliveriesDecay:  0.9971,
                },
            },
            AppSpecificScore: func(p peer.ID) float64 {
                // Custom application scoring
                return 0
            },
            DecayInterval: 12 * time.Second,
            DecayToZero:   0.01,
        },
        &pubsub.PeerScoreThresholds{
            GossipThreshold:             -10,
            PublishThreshold:            -50,
            GraylistThreshold:           -80,
            AcceptPXThreshold:           10,
            OpportunisticGraftThreshold: 5,
        },
    ),
)
```

**Audit Checks**:
- [ ] Is peer scoring enabled (v1.1)?
- [ ] Are score parameters tuned for the application?
- [ ] Is InvalidMessageDeliveriesWeight strongly negative?
- [ ] Are thresholds set to prune/graylist bad peers?
- [ ] Is IP colocation penalized?

### 4.2 Message Validation

**Synchronous vs Asynchronous Validation**:
```go
// Synchronous (blocks propagation)
err := psub.RegisterTopicValidator("topic",
    func(ctx context.Context, pid peer.ID, msg *pubsub.Message) bool {
        // Quick validation only
        return isValidFormat(msg.Data)
    },
)

// Asynchronous (allows propagation, validates later)
// Use with caution - can propagate invalid messages
```

**Audit Checks**:
- [ ] Are all topics validated?
- [ ] Is signature verification mandatory?
- [ ] Are oversized messages rejected?
- [ ] Is there rate limiting per peer?
- [ ] Are replay attacks prevented (message ID + timestamp)?

### 4.3 Mesh Configuration

```go
// Mesh parameters
pubsub.WithGossipSubParams(pubsub.GossipSubParams{
    D:   6,    // Target mesh size
    Dlo: 5,    // Lower bound
    Dhi: 12,   // Upper bound
    Dlazy: 6,  // Gossip target
    Heartbeat: 1 * time.Second,
    // ... more params
})
```

**Audit Checks**:
- [ ] Is D (mesh degree) appropriate for network size?
- [ ] Are Dlo/Dhi bounds enforced?
- [ ] Is heartbeat interval reasonable?
- [ ] Are GRAFT/PRUNE limits configured?

---

## 5. NAT Traversal Security

### 5.1 AutoNAT

**Purpose**: Automatically detect NAT status and public address.

**Security Risks**:
- Can be used for network scanning
- Reflection attacks
- Resource exhaustion

**Mitigations**:
```go
// Configure AutoNAT with limits
autonat.EnableService(host,
    autonat.WithReachability(network.ReachabilityPublic),
    autonat.WithThrottling(10, 60*time.Second),  // Rate limit
)
```

**Audit Checks**:
- [ ] Is AutoNAT rate-limited?
- [ ] Are dial attempts limited per peer?
- [ ] Is AutoNAT only enabled when needed?

### 5.2 Circuit Relay v2

**Improvements over v1**:
- Resource reservations
- Explicit limits per client
- Time-bounded circuits
- Reduced abuse potential

**Configuration**:
```go
// Relay v2 with resource limits
relay.WithResources(relay.Resources{
    Limit: &relay.ResourceLimit{
        MaxCircuits:        128,
        MaxCircuitsPerPeer: 8,
        BufferSize:         4096,
    },
    ReservationTTL: time.Hour,
    MaxReservations: 256,
})
```

**Audit Checks**:
- [ ] Is Circuit Relay v2 used (not v1)?
- [ ] Are per-peer circuit limits enforced?
- [ ] Are reservation limits configured?
- [ ] Is bandwidth throttling enabled?
- [ ] Are idle circuits timed out?

### 5.3 Hole Punching

**DCUtR (Direct Connection Upgrade through Relay)**:
- Attempts direct connection after relay
- Can trigger external connections
- Potential DoS vector

**Audit Checks**:
- [ ] Is hole punching rate-limited?
- [ ] Are failed attempts tracked and limited?
- [ ] Is there monitoring for abuse?

---

## 6. Connection Management

### 6.1 Connection Limits

```go
// Configure connection manager
cm, err := connmgr.NewConnManager(
    100,  // Low watermark
    400,  // High watermark
    connmgr.WithGracePeriod(time.Minute),
)

host, err := libp2p.New(
    libp2p.ConnectionManager(cm),
    libp2p.ResourceManager(resourceManager),  // New in libp2p v0.18+
)
```

**Audit Checks**:
- [ ] Are connection limits configured?
- [ ] Is high watermark reasonable for resources?
- [ ] Are low-value connections pruned?
- [ ] Is grace period appropriate?

### 6.2 Resource Manager (libp2p v0.18+)

**Feature**: Fine-grained resource control for connections, streams, memory.

```go
// Configure resource limits
limiter := rcmgr.NewFixedLimiter(rcmgr.InfiniteLimits)
limiter.SystemLimits.ConnsInbound = 1000
limiter.SystemLimits.ConnsOutbound = 500
limiter.SystemLimits.Conns = 1500
limiter.SystemLimits.StreamsInbound = 5000
limiter.SystemLimits.StreamsOutbound = 2500
limiter.SystemLimits.Memory = 256 << 20  // 256 MB

rm, err := rcmgr.NewResourceManager(limiter)
```

**Audit Checks**:
- [ ] Is resource manager enabled?
- [ ] Are system-wide limits configured?
- [ ] Are per-peer limits set?
- [ ] Are per-protocol limits appropriate?
- [ ] Is memory bounded?

---

## 7. Protocol-Specific Security

### 7.1 Multistream-Select

**Purpose**: Protocol negotiation before stream establishment.

**Vulnerabilities**:
- Protocol downgrade attacks
- Enumeration of supported protocols
- Handshake DoS (slowloris)

**Mitigations**:
- Timeout slow negotiations
- Don't expose sensitive protocol list
- Disable deprecated/insecure protocols

### 7.2 Bitswap (IPFS)

**Security Considerations**:
- Requesting content can reveal interest
- Providing content reveals inventory
- Block exchange can be DoS vector

**Mitigations**:
- Rate limit block requests
- Implement peer scoring
- Use WANT-HAVE vs WANT-BLOCK strategically
- Privacy mode for sensitive content

---

## 8. Configuration Pitfalls

### 8.1 Development vs Production

**Common Mistakes**:
```go
// ❌ BAD: Development settings in production
libp2p.NoSecurity                           // Disabled encryption
libp2p.DisableRelay()                       // May be needed for NAT
dht.Mode(dht.ModeClient)                    // Not contributing to DHT
pubsub.WithFloodPublish(true)               // Flood instead of gossip
```

**Checklist**:
- [ ] Transport security is enforced
- [ ] Relay is configured appropriately
- [ ] DHT mode matches requirements
- [ ] GossipSub (not FloodSub) is used
- [ ] Peer scoring is enabled

### 8.2 Bootstrap Node Security

**Risks**:
- Single point of failure
- Eclipse attack enabler
- Privacy compromise

**Best Practices**:
```go
// Multiple diverse bootstrap peers
bootstrapPeers := []string{
    "/dnsaddr/bootstrap.libp2p.io/p2p/QmNnooDu7bfjPFoTZYxMNLWUQJyrVwtbZg5gBMjTezGAJN",
    "/dnsaddr/bootstrap.libp2p.io/p2p/QmQCU2EcMqAqQPR2i9bChDtGNJchTbq5TbXJJ16u19uLTa",
    // ... more diverse sources
}
```

**Audit Checks**:
- [ ] Multiple bootstrap peers from different operators
- [ ] Peer IDs are hardcoded (not just IPs)
- [ ] Bootstrap list is not hardcoded in binary (configurable)
- [ ] Fallback discovery mechanisms exist

---

## 9. Monitoring & Observability

### 9.1 Metrics to Track

**Connection Metrics**:
- Active connections (inbound/outbound)
- Connection churn rate
- Failed connection attempts
- Connections per peer ID / IP

**DHT Metrics**:
- Routing table size and composition
- Query success/failure rates
- Query latency
- Provider record counts

**GossipSub Metrics**:
- Messages sent/received per topic
- Peer scores distribution
- Mesh health (degree, churn)
- Invalid message rates

**Resource Metrics**:
- Memory usage (streams, connections, buffers)
- CPU usage (crypto, message processing)
- Bandwidth (per peer, per protocol)

### 9.2 Alerting

**Red Flags**:
- 🚨 Sudden connection spike
- 🚨 Routing table homogeneity (eclipse)
- 🚨 High invalid message rate
- 🚨 Memory/CPU exhaustion
- 🚨 Unusual peer score distribution

---

## 10. libp2p Implementation Variants

### Language-Specific Considerations

**go-libp2p** (Reference Implementation):
- Most mature and feature-complete
- Best performance
- Resource manager support (v0.18+)

**js-libp2p**:
- Browser limitations (no TCP, limited QUIC)
- Relies on WebSocket/WebRTC
- Different trust model (runs in user context)

**rust-libp2p**:
- Memory-safe by design
- Excellent performance
- Growing ecosystem

**py-libp2p**, **nim-libp2p**, etc.:
- Varying maturity
- May lack latest security features
- Audit implementation completeness

**Audit Considerations**:
- Check if GossipSub v1.1 is supported
- Verify Noise/TLS support
- Confirm Resource Manager equivalents
- Test interoperability

---

## 11. Security Testing Tools

### Simulation & Testing
```bash
# Testground - Large-scale P2P testing
testground run single --plan=gossipsub --testcase=attack-sybil

# Local testing
go test -fuzz=FuzzGossipSubMessage
```

### Network Analysis
```bash
# DHT monitoring
ipfs-dht-analyzer --peer /ip4/...

# Connection analysis
ss -anp | grep <libp2p-port>
```

### Fuzzing
- Fuzz protocol parsers (multistream, DHT messages)
- Fuzz GossipSub message validation
- Fuzz connection handshakes

---

## 12. Incident Response

**If Compromised**:
1. **Isolate**: Disconnect affected nodes
2. **Analyze**: Capture traffic, logs, state
3. **Identify**: Malicious peer IDs, attack pattern
4. **Mitigate**: Ban peers, update configs, patch
5. **Recover**: Restart with hardened configuration
6. **Post-Mortem**: Document and share findings

**Ban List Management**:
```go
// Maintain persistent ban list
host.Network().ClosePeer(badPeerID)
host.ConnManager().Unprotect(badPeerID, "")

// Optional: Share ban lists (carefully - can be abused)
```

---

## References

- [libp2p Specifications](https://github.com/libp2p/specs)
- [GossipSub v1.1 Spec](https://github.com/libp2p/specs/blob/master/pubsub/gossipsub/gossipsub-v1.1.md)
- [libp2p Security Considerations](https://github.com/libp2p/specs/blob/master/connections/security.md)
- [Noise Protocol Framework](https://noiseprotocol.org/)
- [go-libp2p Documentation](https://pkg.go.dev/github.com/libp2p/go-libp2p)
- [Ethereum P2P Networking Spec](https://github.com/ethereum/consensus-specs/blob/dev/specs/phase0/p2p-interface.md)

---

**Last Updated**: 2025-01-26
