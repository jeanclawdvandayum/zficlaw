# Cross-Chain & Bridge Audit

Detect cross-chain and bridge vulnerabilities — message replay, stuck funds, sequencer issues, and bridge admin exploits.

**Database:** 390 findings (45 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Verify message uniqueness — can the same message be replayed on the destination chain?
2. Check message ordering — does the protocol depend on message order that may not be guaranteed?
3. Verify bridge admin cannot unilaterally steal funds
4. Check for stuck funds — what happens when a bridge message fails on destination?
5. Verify refund mechanisms for failed cross-chain operations
6. Check L2 sequencer dependency — what happens during sequencer downtime?
7. Look for inconsistent state between L1 and L2 (race conditions)
8. Verify token decimal handling across chains (USDC: 6 on ETH, 18 on some L2s)
9. Check bridge deposit/withdrawal limits and rate limiting
10. Verify message finality assumptions match actual chain guarantees

## Common Vulnerable Patterns
- Missing nonce in cross-chain message → replay attack
- Bridge admin can set arbitrary withdrawal addresses → fund theft
- No refund path for failed L2→L1 messages → permanent fund lock
- Different token decimals across chains without normalization → amount inflation/deflation
- `msg.sender` used on destination chain instead of original sender → impersonation

## Real-World Examples (from audit database)
- **[HIGH]** Arbitrary withdrawal could be executed by bridge admin
  - Source: Zellic: 2024-08-astria-bridge
- **[HIGH]** Withdrawal event could be reused by bridge admin
  - Source: Zellic: 2024-08-astria-bridge
- **[HIGH]** Incorrect L2 sequencer uptime feed integration
  - Source: Zellic: 2025-06-concrete
- **[HIGH]** Token bridge will receive and lock ether
  - Source: ToB: 2023-09-offchain-labs-custom-fee-token
- **[HIGH]** Deprecated variable L1MessageServiceV1::__messageSender is still
  - Source: Cyfrin: 2024-05-linea-v20
- **[HIGH]** TokenBridge::bridgeToken allows 1-way ERC721 bridging causing
  - Source: Cyfrin: 2024-05-linea-v20
- **[HIGH]** L1 CCIP messages use incorrect tokensInTransitToL1 value leading
  - Source: Cyfrin: 2024-11-stakelink-metis-staking-v20
- **[CRIT]** Lack of transferId Verification Allows an Attacker to Front-Run Bridge Transfers
  - Source: Spearbit: 0000-connext
- **[HIGH]** Executor reverts on receiving native tokens from BridgeFacet
  - Source: Spearbit: 0000-connext
- **[HIGH]** Cross-chain messaging via Multichain protocol will fail
  - Source: Spearbit: 0000-connextnxtp
- **[HIGH]** CelerIMFacet incorrectly sets RelayerCelerIM as receiver
  - Source: Spearbit: 0000-lifi-retainer1
- **[HIGH]** Hardcode bridge addresses via immutable
  - Source: Spearbit: 0000-lifi
