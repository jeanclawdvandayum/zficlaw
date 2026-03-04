# Morpho Vault V2 — Contract Function Reference

## User Functions (Anyone)

| Function | Params | Returns | Notes |
|----------|--------|---------|-------|
| `deposit(uint256 assets, address onBehalf)` | assets, recipient | shares minted | Standard ERC-4626 |
| `mint(uint256 shares, address onBehalf)` | exact shares | assets deposited | |
| `withdraw(uint256 assets, address receiver, address onBehalf)` | assets, receiver, owner | shares burned | Pulls from idle, then liquidity adapter |
| `redeem(uint256 shares, address receiver, address onBehalf)` | shares, receiver, owner | assets withdrawn | |
| `forceDeallocate(address adapter, bytes data, uint256 assets, address onBehalf)` | adapter, data, amount, penalty payer | penalty shares burned | Permissionless. Penalty up to 2% |
| `accrueInterest()` | — | — | Queries adapters, updates totalAssets |
| `accrueInterestView()` | — | (newTotalAssets, perfFeeShares, mgmtFeeShares) | View version |
| `convertToShares(uint256 assets)` | assets | shares | Accounts for fees |
| `convertToAssets(uint256 shares)` | shares | assets | Accounts for fees |
| `previewDeposit/previewMint/previewWithdraw/previewRedeem` | amount | converted amount | Standard ERC-4626 previews |
| `maxDeposit/maxMint/maxWithdraw/maxRedeem` | address | **always 0** | Non-standard! Due to gate complexity |
| `multicall(bytes[] data)` | encoded calls | — | Batch admin calls (no return data) |

## Owner Functions

| Function | Notes |
|----------|-------|
| `setOwner(address)` | Transfer ownership |
| `setCurator(address)` | Appoint risk manager |
| `setIsSentinel(address, bool)` | Grant/revoke Sentinel role |
| `setName(string)` | Vault ERC-20 name |
| `setSymbol(string)` | Vault ERC-20 symbol |

## Curator Functions

### Timelocked (require `submit()` first)
| Function | Notes |
|----------|-------|
| `addAdapter(address)` | Enable new yield source |
| `removeAdapter(address)` | Disable adapter |
| `increaseAbsoluteCap(bytes idData, uint256 cap)` | Raise hard limit |
| `increaseRelativeCap(bytes idData, uint256 cap)` | Raise % limit (1e18 = 100%) |
| `setIsAllocator(address, bool)` | Grant/revoke Allocator |
| `setPerformanceFee(uint256)` | Max 50% (0.5e18) |
| `setManagementFee(uint256)` | Max 5%/yr (0.05e18) |
| `setPerformanceFeeRecipient(address)` | |
| `setManagementFeeRecipient(address)` | |
| `setReceiveSharesGate(address)` | Compliance gate |
| `setSendSharesGate(address)` | |
| `setReceiveAssetsGate(address)` | |
| `setSendAssetsGate(address)` | |
| `setForceDeallocatePenalty(address adapter, uint256 penalty)` | Max 2% (0.02e18) |
| `setAdapterRegistry(address)` | Validates all current adapters approved |
| `increaseTimelock(bytes4 selector, uint256 duration)` | Timelocked by own duration |
| `decreaseTimelock(bytes4 selector, uint256 duration)` | Timelocked by target's timelock |
| `abdicate(bytes4 selector)` | **Irreversible** — permanently disables function |

### Instant (also callable by Sentinel)
| Function | Notes |
|----------|-------|
| `decreaseAbsoluteCap(bytes idData, uint256 cap)` | Risk reduction |
| `decreaseRelativeCap(bytes idData, uint256 cap)` | Risk reduction |
| `revoke(bytes data)` | Cancel pending proposal |

### Timelock Management
| Function | Notes |
|----------|-------|
| `submit(bytes data)` | Submit timelocked action. Records in `executableAt` mapping |

## Allocator Functions

| Function | Notes |
|----------|-------|
| `allocate(address adapter, bytes data, uint256 assets)` | Move idle → adapter. Checked against caps |
| `deallocate(address adapter, bytes data, uint256 assets)` | Move adapter → idle. Also callable by Sentinel |
| `setLiquidityAdapterAndData(address adapter, bytes data)` | Default deposit/withdrawal adapter |
| `setMaxRate(uint256)` | Cap totalAssets growth rate |

## Key Storage/View

| Name | Type | Notes |
|------|------|-------|
| `totalAssets()` | uint256 | Sum of idle + all adapter realAssets |
| `totalSupply()` | uint256 | Total vault shares |
| `allocation(bytes32 id)` | uint256 | Current allocation for an id |
| `absoluteCap(bytes32 id)` | uint128 | |
| `relativeCap(bytes32 id)` | uint128 | |
| `timelock(bytes4 selector)` | uint256 | Current timelock for function |
| `abdicated(bytes4 selector)` | bool | Whether function permanently disabled |
| `executableAt(bytes32 hash)` | uint256 | Timestamp when pending action can execute |

## Caps Struct
```solidity
struct Caps {
    uint256 allocation;   // Current allocated amount
    uint128 absoluteCap;  // Hard asset limit
    uint128 relativeCap;  // % of totalAssets (1e18 scale)
}
```

## id Computation
```solidity
// Generic
bytes32 id = keccak256(idData);

// MorphoVaultV1Adapter — single id
bytes memory idData = abi.encode("this", adapterAddress);

// MorphoMarketV1AdapterV2 — three ids
bytes memory adapterId = abi.encode("this", adapterAddress);
bytes memory collateralId = abi.encode("collateralToken", collateralAddress);
bytes memory marketId = abi.encode("this/marketParams", adapterAddress, marketParams);
```
