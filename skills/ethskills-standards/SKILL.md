---
name: ethskills-standards
description: Ethereum token and protocol standards — ERC-20, ERC-721, ERC-1155, ERC-4337, ERC-8004, x402, and newer standards. When to use each, how they work, key interfaces. Use when building tokens, NFTs, choosing the right standard, or working with agent identity/payments.
metadata:
  source: "https://ethskills.com/standards/SKILL.md"
---

# Ethereum Standards

## What You Probably Got Wrong

**ERC-8004 exists.** Deployed January 29, 2026 — on-chain agent identity registry.

**EIP-7702 is live.** Shipped with Pectra (May 7, 2025). EOAs get smart contract superpowers without migration.

**EIP-3009 is critical for x402.** Gasless token transfers via signed authorizations. USDC implements it.

**x402 exists.** HTTP 402 payment protocol from Coinbase. Production-ready with SDKs.

## ERC-8004: On-Chain Agent Identity Registry

**Status:** Deployed mainnet **January 29, 2026** — production ready.

### Three Registry System

**1. Identity Registry (ERC-721 based)** — globally unique on-chain identities for AI agents
**2. Reputation Registry** — signed fixed-point feedback values, multi-dimensional
**3. Validation Registry** — independent verification of agent work

**Contract Addresses (same on 20+ chains):**
- **IdentityRegistry:** `0x8004A169FB4a3325136EB29fA0ceB6D2e539a432`
- **ReputationRegistry:** `0x8004BAa17C55a88189AE136b182e5fdA19dE9b63`

**Resources:** https://www.8004.org | https://eips.ethereum.org/EIPS/eip-8004

## x402: HTTP Payment Protocol

**Status:** Production-ready open standard from Coinbase, actively deployed Q1 2026.

### Flow
```
1. Client → GET /api/data
2. Server → 402 Payment Required
3. Client signs EIP-3009 payment
4. Client → GET /api/data (with PAYMENT-SIGNATURE header)
5. Server verifies + settles on-chain
6. Server → 200 OK + data
```

**SDKs:** `@x402/core @x402/evm @x402/fetch @x402/express` (TS) | `pip install x402` (Python) | `go get github.com/coinbase/x402/go`

**Resources:** https://www.x402.org | https://github.com/coinbase/x402

## Quick Standard Reference

| Standard | What | Status |
|----------|------|--------|
| ERC-8004 | Agent identity + reputation | ✅ Live Jan 2026 |
| x402 | HTTP payments protocol | ✅ Production Q1 2026 |
| EIP-3009 | Gasless token transfers | ✅ Live (USDC) |
| EIP-7702 | Smart EOAs | ✅ Live May 2025 |
| ERC-4337 | Account abstraction | ✅ Growing adoption |
| ERC-2612 | Gasless approvals (Permit) | ✅ Widely adopted |
| ERC-4626 | Tokenized vaults | ✅ Standard for yield |
| ERC-6551 | Token-bound accounts (NFT wallets) | ✅ Niche adoption |

**These are all LIVE and being used in production. Not "coming soon."**
