---
name: ethskills-tools
description: Current Ethereum development tools, frameworks, libraries, RPCs, and block explorers. What actually works today for building on Ethereum. Includes tool discovery for AI agents — MCPs, abi.ninja, Foundry, Scaffold-ETH 2, and more. Use when setting up a dev environment, choosing tools, or when an agent needs to discover what's available.
metadata:
  source: "https://ethskills.com/tools/SKILL.md"
---

# Ethereum Development Tools

## What You Probably Got Wrong

**Blockscout MCP server exists:** https://mcp.blockscout.com/mcp — gives AI agents structured blockchain data via Model Context Protocol.

**abi.ninja is essential:** https://abi.ninja — paste any verified contract address, get a UI to call any function. Zero setup.

**x402 has production SDKs:** `@x402/fetch` (TS), `x402` (Python), `github.com/coinbase/x402/go`

**Foundry is the default for new projects in 2026.** Not Hardhat. 10-100x faster tests, Solidity-native testing, built-in fuzzing.

## Choosing Your Stack (2026)

| Need | Tool |
|------|------|
| Rapid prototyping / full dApps | **Scaffold-ETH 2** |
| Contract-focused dev | **Foundry** (forge + cast + anvil) |
| Quick contract interaction | **abi.ninja** (browser) or **cast** (CLI) |
| React frontends | **wagmi + viem** (or SE2 which wraps these) |
| Agent blockchain reads | **Blockscout MCP** |
| Agent payments | **x402 SDKs** |

## Essential Foundry cast Commands

```bash
cast call 0xAddr "balanceOf(address)(uint256)" 0xWallet --rpc-url $RPC
cast send 0xAddr "transfer(address,uint256)" 0xTo 1000000 --private-key $KEY --rpc-url $RPC
cast gas-price --rpc-url $RPC
cast 4byte-decode 0xa9059cbb...
cast resolve-name vitalik.eth --rpc-url $RPC
anvil --fork-url $RPC  # Fork mainnet locally
```

## RPC Providers

**Free:** `https://eth.llamarpc.com` (LlamaNodes) | `https://rpc.ankr.com/eth` (Ankr)
**Paid:** Alchemy, Infura, QuickNode
**Community:** `rpc.buidlguidl.com`

## Block Explorers

| Network | Explorer |
|---------|----------|
| Mainnet | https://etherscan.io |
| Arbitrum | https://arbiscan.io |
| Base | https://basescan.org |
| Optimism | https://optimistic.etherscan.io |

## What Changed in 2025-2026

- Foundry became default over Hardhat
- Viem gaining on ethers.js (smaller, better TypeScript)
- MCP servers emerged for agent-blockchain interaction
- x402 SDKs went production-ready
- ERC-8004 tooling emerging
- **Deprecated:** Truffle, Goerli, Rinkeby (use Sepolia)
