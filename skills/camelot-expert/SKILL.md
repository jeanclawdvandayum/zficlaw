---
name: camelot-expert
description: Expert knowledge of Camelot DEX on Arbitrum — concentrated liquidity (Algebra-based), NFT positions, NonfungiblePositionManager, dual-token rewards, spNFTs, and dynamic fee tiers. Use when auditing Camelot integrations or building LP adapters.
---

# Camelot DEX Expert

## Architecture Overview

Camelot is a DEX on Arbitrum with both standard AMM and concentrated liquidity pools. Core design (concentrated liquidity focus):

- **Algebra-based CL** — similar to Uniswap V3 but with dynamic fee tiers (fees adjust based on volatility)
- **NFT positions** — each LP position is an ERC-721 NFT minted by `NonfungiblePositionManager`
- **Dual-token rewards** — GRAIL + xGRAIL, distributed to LPs via staking contracts
- **spNFTs** — staked position NFTs that earn additional rewards
- **Nitro pools** — time-limited liquidity mining for specific ranges

Integration pattern: Mint LP position via `NonfungiblePositionManager.mint()` → receive NFT → collect fees via `collect()` → increase/decrease liquidity → burn NFT on full exit. For Alchemix integration, adapter would hold NFT and track liquidity value.

## Key Integration Functions

| Function | Purpose | Returns |
|----------|---------|---------|
| `mint(MintParams)` | Create new LP position, mint NFT to recipient | tokenId, liquidity, amount0, amount1 |
| `increaseLiquidity(IncreaseLiquidityParams)` | Add liquidity to existing position | liquidity, amount0, amount1 |
| `decreaseLiquidity(DecreaseLiquidityParams)` | Remove liquidity from position (tokens stay in contract) | amount0, amount1 |
| `collect(CollectParams)` | Collect fees + withdrawn tokens to recipient | amount0, amount1 |
| `burn(tokenId)` | Burn NFT (only if liquidity == 0 and fees collected) | - |
| `positions(tokenId)` | Get position details (liquidity, tokens, fee growth, range) | Position struct |
| `pool.slot0()` | Current price (sqrtPriceX96), tick, fee, unlocked | sqrtPriceX96, tick, ... |

## realAssets() Computation

For a Camelot adapter holding NFT position(s):

```solidity
function realAssets() external view returns (uint256) {
    (
        ,, address token0, address token1,,,
        uint128 liquidity, , , ,
    ) = nonfungiblePositionManager.positions(tokenId);
    
    // Get current price from pool
    IAlgebraPool pool = getPool(token0, token1);
    (uint160 sqrtPriceX96, , , , , , ) = pool.globalState();
    
    // Calculate token amounts for liquidity
    (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
        sqrtPriceX96,
        tickLower, tickUpper,
        liquidity
    );
    
    // Convert to base asset value (requires price oracle)
    return convertToBaseAsset(token0, amount0) + convertToBaseAsset(token1, amount1);
}
```

**Complexity:** Unlike single-token vaults, CL positions hold two tokens. Must calculate current token amounts from liquidity + price, then convert to base asset value. Requires price oracle for accurate valuation.

**Uncollected fees:** Add `collect.call()` simulation to include accrued fees in valuation.

## Security Audit Considerations

- **Price range risk** — If price moves outside [tickLower, tickUpper], position holds only one token. Adapter must handle unbalanced positions
- **Impermanent loss** — CL positions subject to IL. Adapter should not assume principal preservation
- **Fee collection** — Fees accrue but don't auto-compound. Must call `collect()` to realize. Uncollected fees increase position value but aren't withdrawable until collected
- **NFT ownership** — Position represented as NFT. If NFT transferred or stolen, position lost. Ensure adapter doesn't approve NFT to untrusted contracts
- **slippage on decrease** — `decreaseLiquidity()` doesn't send tokens — must call `collect()` after. Between these calls, another user could sandwich, extracting value
- **Dynamic fees** — Fee tier changes based on volatility. High volatility = higher fees but also higher IL risk
- **Algebra reentrancy** — Algebra uses `unlock` pattern (like Uniswap V4). Ensure adapter doesn't assume non-reentrant execution
- **spNFT staking risks** — If adapter stakes NFT to spNFT for extra rewards, must track both base position and staking rewards. Unstaking has cooldown period
- **Price oracle manipulation** — `slot0().sqrtPriceX96` is spot price, manipulable with flash loans. Use TWAP for valuation
- **Tick spacing** — Each fee tier has different tick spacing. Position's tickLower/tickUpper must align with spacing

## Known Risks / Past Incidents

- **Algebra V3 reentrancy** — Feb 2024, Algebra (Camelot's AMM) found reentrancy vector in hooks. Patched before exploit
- **Uniswap V3 oracle manipulation** — Multiple protocols using Uniswap V3 (similar to Camelot) exploited via TWAP manipulation or slot0 spot price attacks

## Links

- Docs: https://docs.camelot.exchange/
- GitHub: https://github.com/CamelotLabs (contracts not fully public)
- App: https://app.camelot.exchange/
- Algebra docs: https://docs.algebra.finance/ (underlying AMM)
