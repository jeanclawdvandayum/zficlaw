# Morpho Vault V2 — GraphQL API Reference

Endpoint: `https://api.morpho.org/graphql`

## Discovery

### List All Vaults
```graphql
query {
  vaultV2s(first: 1000, where: { chainId_in: [1, 8453] }) {
    items {
      address
      symbol
      name
      whitelisted
      asset { id address decimals }
      chain { id network }
    }
  }
}
```

## Metrics

### Total Deposits & Assets
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    totalAssets
    totalAssetsUsd
    totalSupply
    liquidity
    liquidityUsd
    idleAssetsUsd
  }
}
```

### APY (Native + Rewards)
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    avgApy
    avgNetApy
    performanceFee
    managementFee
    maxRate
    asset { yield { apr } }
    rewards {
      asset { address chain { id } }
      supplyApr
      yearlySupplyTokens
    }
  }
}
```

### Share Price
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    totalAssets
    totalSupply
  }
}
```
Share price = totalAssets / totalSupply

## Allocations

### Current Adapter Allocations
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    totalAssetsUsd
    totalAssets
    totalSupply
    adapters {
      items {
        address
        assets
        assetsUsd
        type
      }
    }
  }
}
```

## Configuration

### Vault Parameters & Roles
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    name
    whitelisted
    metadata { description forumLink image }
    owner { address }
    curators { items { addresses { address } } }
    allocators { allocator { address } }
    sentinels { sentinel { address } }
    timelocks { duration selector functionName }
  }
}
```

### Risk Warnings
Warning types: `unrecognized_deposit_asset`, `unrecognized_vault_curator`, `not_whitelisted`
Levels: `YELLOW`, `RED`

```graphql
query {
  vaultV2s(first: 5) {
    items { name warnings { type level } }
  }
}
```

## Position Tracking

### Vault Depositors
```graphql
query {
  vaultV2ByAddress(address: "0x...", chainId: 1) {
    positions(first: 10, skip: 0) {
      items {
        user { address }
        assets
        assetsUsd
        shares
      }
    }
  }
}
```

### User Positions Across Vaults
```graphql
query GetUserVaultPositions($address: String!, $chainId: Int!) {
  userByAddress(address: $address, chainId: $chainId) {
    vaultV2Positions {
      shares
      vault { address symbol }
    }
  }
}
```

## Transactions

### Vault Transaction History
```graphql
query {
  vaultV2transactions(
    first: 10
    where: { vaultAddress_in: "0x..." }
  ) {
    items {
      type
      shares
      blockNumber
      timestamp
      txHash
    }
  }
}
```

## Notes
- V2 queries use `vaultV2s`, `vaultV2ByAddress`, `vaultV2transactions`
- V1 queries use `vaults`, `vaultByAddress`, `transactions`
- Historical APY/allocation timeseries currently V1 only
- Batched depositor queries currently V1 only
