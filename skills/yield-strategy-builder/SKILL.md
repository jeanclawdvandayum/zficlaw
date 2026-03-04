---
name: yield-strategy-builder
description: Build Alchemix V3 MYTStrategy yield strategies for supported protocols. Takes a target protocol (Euler, Aave V3, Morpho, Beefy, Fluid, Moonwell, Peapods, Tokemak, Stargate, Lido, EtherFi, Frax, Camelot, Velodrome, or any ERC-4626/lending/LP protocol), the chain, and the underlying asset, then generates a complete strategy contract + test file that follows the audited MYTStrategy pattern. Use when asked to build, scaffold, or generate a new yield strategy for Alchemix V3. Also use when asked to create an adapter or integrate a new protocol into the MYT vault system.
---

# Yield Strategy Builder

Build production-quality Alchemix V3 `MYTStrategy` contracts for any supported yield protocol.

## Prerequisites

Before generating, load the relevant protocol expert skill for the target protocol (e.g. `euler-expert`, `aavev3-expert`, `morphov2-expert`, etc.) to get protocol-specific integration knowledge.

## Step 1: Gather Inputs

Collect from the user (or infer from context):

| Input | Required | Example |
|-------|----------|---------|
| Protocol | ✅ | Euler, Aave V3, Moonwell, Beefy, etc. |
| Chain | ✅ | mainnet, arbitrum, optimism |
| Underlying asset | ✅ | USDC, WETH |
| Protocol vault/pool address | ✅ | `0xe0a80d35bB6618CBA260120b279d357978c42BCE` |
| Underlying asset address | ✅ | `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48` |
| Receipt token address | if different from vault | aTokens, mTokens, LP tokens |
| Additional addresses | if needed | Router, Rewarder, Oracle, RedemptionQueue |
| Risk class | default LOW | LOW, MEDIUM, HIGH |
| Has additional incentives | default false | true if protocol has reward tokens |
| Slippage BPS | default 1 | higher for LP/complex strategies |
| Fork block number | for tests | recent block on target chain |
| RPC env var | for tests | `MAINNET_RPC_URL`, `ARBITRUM_RPC_URL`, etc. |

## Step 2: Classify Protocol Type

Strategies fall into these integration patterns. Read `references/PATTERNS.md` for the full pattern catalog with code templates.

| Pattern | Protocols | Key Trait |
|---------|-----------|-----------|
| **ERC-4626 Vault** | Euler, Fluid, Morpho, Peapods, Beefy (some) | `deposit/withdraw/convertToAssets` |
| **Lending Pool** | Aave V3, Moonwell | `supply/withdraw` or `mint/redeemUnderlying` with rebasing or exchange-rate tokens |
| **ERC-4626 + Staking** | Tokemak | Deposit into vault, stake shares in rewarder |
| **Native ETH Bridge** | Stargate | WETH→ETH→pool, pool→ETH→WETH |
| **LST Mint+Redeem** | Frax (sfrxETH), EtherFi (weETH), Lido (wstETH) | Mint via minter, redeem via queue (may need ERC721Receiver) |
| **Concentrated Liquidity LP** | Camelot, Velodrome | Swap+LP, NFT positions or pool tokens |

## Step 3: Generate Strategy Contract

### File Location

```
src/strategies/{chain}/{ProtocolAssetStrategy}.sol
```

Chain mapping: `mainnet` → `mainnet/`, `arbitrum` → `arbitrum/`, `optimism` → `optimism/`. Top-level `src/strategies/` for cross-chain strategies.

### Contract Structure (all strategies)

Every strategy MUST:

1. **Extend `MYTStrategy`** from `../../MYTStrategy.sol`
2. **Import `TokenUtils`** from `../../libraries/TokenUtils.sol`
3. **Store protocol-specific contracts as `immutable`** (vault, pool, router, etc.)
4. **Pass the receipt token to `MYTStrategy` constructor** — this is the token the strategy holds (the yield-bearing token). For ERC-4626: the vault address. For Aave: the underlying. For Tokemak: the autopool address.
5. **Implement these overrides:**

| Override | Purpose | Rules |
|----------|---------|-------|
| `_allocate(uint256 amount)` | Move funds into protocol | MUST return `amount`. Check balance before. Approve before deposit. |
| `_deallocate(uint256 amount)` | Pull funds from protocol | MUST return `amount`. Track balance delta. Emit `StrategyDeallocationLoss` if shortfall. MUST `safeApprove` underlying to `msg.sender` (the vault). MUST have ≥ `amount` of underlying at end. |
| `realAssets()` | Total underlying value | View function. Use `convertToAssets(balanceOf)` for ERC-4626, `aToken.balanceOf` for Aave, `mTokenBalance * exchangeRate / 1e18` for Compound-forks. |
| `_previewAdjustedWithdraw(uint256 amount)` | Estimate actual withdrawable accounting for slippage | Apply `slippageBPS`. For ERC-4626: `previewWithdraw → convertToAssets → subtract slippage`. For 1:1: `amount - (amount * slippageBPS / 10_000)`. |

**Optional overrides** (implement when applicable):

| Override | When |
|----------|------|
| `_computeBaseRatePerSecond()` | Strategy tracks its own yield via price snapshots |
| `_computeRewardsRatePerSecond()` | Protocol has additional reward tokens |
| `_claimRewards()` | Protocol has claimable rewards |
| `_claimWithdrawalQueue(uint256 positionId)` | Protocol uses async withdrawal (NFT queue) |

### Critical Patterns

**Balance check before allocate:**
```solidity
require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than amount");
```

**Approve-then-deposit:**
```solidity
TokenUtils.safeApprove(address(underlying), address(vault), amount);
vault.deposit(amount, address(this));
```

**Deallocate loss tracking:**
```solidity
uint256 balanceBefore = TokenUtils.safeBalanceOf(address(underlying), address(this));
// ... withdraw from protocol ...
uint256 balanceAfter = TokenUtils.safeBalanceOf(address(underlying), address(this));
uint256 redeemed = balanceAfter - balanceBefore;
if (redeemed < amount) {
    emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, redeemed);
}
require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than the amount needed");
TokenUtils.safeApprove(address(underlying), msg.sender, amount);
```

**ERC-4626 previewAdjustedWithdraw:**
```solidity
uint256 shares = vault.previewWithdraw(amount);
uint256 assets = vault.convertToAssets(shares);
return assets - (assets * slippageBPS / 10_000);
```

**Native ETH handling** (when protocol needs ETH not WETH):
```solidity
// Allocate: unwrap WETH → deposit ETH
IWETH(WETH).withdraw(amount);
pool.deposit{value: amount}(address(this), amount);

// Deallocate: withdraw ETH → wrap WETH
pool.redeem(lpAmount, address(this));
IWETH(WETH).deposit{value: ethReceived}();

// MUST add: receive() external payable {}
```

**Withdrawal queue (NFT-based exits):**
```solidity
// deallocate returns NFT ID, not underlying
function _deallocate(uint256 amount) internal override returns (uint256) {
    uint256 nftId = redemptionQueue.enterQueue(amount);
    return nftId;
}
// Separate claim step
function _claimWithdrawalQueue(uint256 positionId) internal override returns (uint256) {
    redemptionQueue.claim(positionId, address(this));
    // wrap ETH if needed, approve vault
    return ethOut;
}
// Contract MUST implement IERC721Receiver
```

### Interface Definitions

Define minimal protocol interfaces **inline in the strategy file** (not imported). Only include functions actually called. This is the established pattern in the codebase.

## Step 4: Generate Test File

### File Location

```
src/test/strategies/{ProtocolAssetStrategy}.t.sol
```

### Test Structure

Every test MUST extend `BaseStrategyTest` and implement:

```solidity
contract Mock{Strategy} is {Strategy} {
    // Pass-through constructor — needed for test setup
}

contract {Strategy}Test is BaseStrategyTest {
    // Protocol-specific constants (on-chain addresses)
    
    function getStrategyConfig() internal pure override returns (IMYTStrategy.StrategyParams memory) {
        // Return params with correct decimals for the asset
    }
    
    function getTestConfig() internal pure override returns (TestConfig memory) {
        // vaultAsset, vaultInitialDeposit, absoluteCap, relativeCap, decimals
    }
    
    function createStrategy(address vault, IMYTStrategy.StrategyParams memory params) internal override returns (address) {
        // Instantiate the Mock strategy with protocol addresses
    }
    
    function getForkBlockNumber() internal pure override returns (uint256) {
        // Recent block for the target chain
    }
    
    function getRpcUrl() internal view override returns (string memory) {
        // e.g., vm.envString("MAINNET_RPC_URL")
    }
}
```

**BaseStrategyTest provides these tests automatically:**
- `test_strategy_allocate_reverts_due_to_zero_amount`
- `test_strategy_deallocate_reverts_due_to_zero_amount`
- `test_strategy_deallocate` (fuzz)
- `test_vault_allocate_to_strategy` (fuzz)
- `test_vault_deallocate_from_strategy` (fuzz)

**Add strategy-specific tests when:**
- Protocol has slippage (test that full deallocate reverts without adjustment)
- Protocol has rewards (test claim)
- Protocol has withdrawal queues (test queue + claim flow)
- Protocol handles native ETH (test wrap/unwrap)
- Protocol uses exchange rates (test rounding)

### Decimal Awareness

| Asset | Decimals | Cap example | Deposit example |
|-------|----------|-------------|-----------------|
| USDC | 6 | `10_000e6` | `1000e6` |
| WETH | 18 | `10_000e18` | `1000e18` |
| DAI | 18 | `10_000e18` | `1000e18` |

### RPC Env Vars

| Chain | Env var |
|-------|---------|
| Mainnet | `MAINNET_RPC_URL` |
| Arbitrum | `ARBITRUM_RPC_URL` |
| Optimism | `OPTIMISM_RPC_URL` |

## Step 5: Verify

After generating:

1. **Check all 5 required overrides** are implemented
2. **Verify `_deallocate`** approves underlying to `msg.sender`
3. **Verify `_deallocate`** has balance check at end
4. **Verify `realAssets()`** is `view` and returns correct underlying value
5. **Verify constructor** passes correct receipt token to `MYTStrategy(..., _receiptToken)`
6. **Verify test** uses correct decimals and chain-appropriate addresses
7. **Cross-reference with protocol expert skill** for protocol-specific gotchas

### Common Mistakes to Avoid

- Forgetting `TokenUtils.safeApprove(underlying, msg.sender, amount)` in `_deallocate`
- Using `balanceOf` instead of `convertToAssets(balanceOf)` for ERC-4626 `realAssets()`
- Wrong receipt token in constructor (should be the yield-bearing token, not the underlying)
- Missing `receive() external payable {}` for strategies that handle native ETH
- Missing `IERC721Receiver` for strategies with withdrawal queues
- Using `view` functions that actually mutate state (e.g., Moonwell's `balanceOfUnderlying` is NOT view)
- Wrong decimal scaling in test configs
