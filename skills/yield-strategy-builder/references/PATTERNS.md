# Strategy Pattern Catalog

Complete code templates for each integration pattern, derived from audited Alchemix V3 strategies.

## Table of Contents

1. [Pattern A: ERC-4626 Vault](#pattern-a-erc-4626-vault)
2. [Pattern B: Lending Pool (Aave V3)](#pattern-b-lending-pool-aave-v3)
3. [Pattern C: Lending Pool (Compound V2 / Moonwell)](#pattern-c-compound-v2-moonwell)
4. [Pattern D: ERC-4626 + Staking (Tokemak)](#pattern-d-erc-4626--staking-tokemak)
5. [Pattern E: Native ETH Bridge (Stargate)](#pattern-e-native-eth-bridge-stargate)
6. [Pattern F: LST Mint + Redeem Queue (Frax sfrxETH)](#pattern-f-lst-mint--redeem-queue-frax)
7. [Pattern G: LST Deposit Adapter (EtherFi weETH)](#pattern-g-lst-deposit-adapter-etherfi)
8. [Constructor Reference](#constructor-reference)

---

## Pattern A: ERC-4626 Vault

**Protocols:** Euler, Fluid, Morpho MetaVaults, Peapods, Beefy (ERC-4626 wrappers)

**Key trait:** Standard `deposit(assets, receiver)` / `withdraw(assets, receiver, owner)` / `convertToAssets(shares)`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin/interfaces/IERC4626.sol";
import {TokenUtils} from "../../libraries/TokenUtils.sol";
import {MYTStrategy} from "../../MYTStrategy.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

contract {Protocol}{Asset}Strategy is MYTStrategy {
    IERC20 public immutable underlying;   // e.g., USDC or WETH
    IERC4626 public immutable vault;      // protocol's ERC-4626 vault

    constructor(
        address _myt,
        StrategyParams memory _params,
        address _underlying,
        address _vault,
        address _permit2Address
    ) MYTStrategy(_myt, _params, _permit2Address, _underlying) {
        underlying = IERC20(_underlying);
        vault = IERC4626(_vault);
    }

    function _allocate(uint256 amount) internal override returns (uint256) {
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than amount");
        TokenUtils.safeApprove(address(underlying), address(vault), amount);
        vault.deposit(amount, address(this));
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 balanceBefore = TokenUtils.safeBalanceOf(address(underlying), address(this));
        vault.withdraw(amount, address(this), address(this));
        uint256 balanceAfter = TokenUtils.safeBalanceOf(address(underlying), address(this));
        uint256 redeemed = balanceAfter - balanceBefore;
        if (redeemed < amount) {
            emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, redeemed);
        }
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than the amount needed");
        TokenUtils.safeApprove(address(underlying), msg.sender, amount);
        return amount;
    }

    function realAssets() external view override returns (uint256) {
        return vault.convertToAssets(vault.balanceOf(address(this)));
    }

    function _previewAdjustedWithdraw(uint256 amount) internal view override returns (uint256) {
        uint256 shares = vault.previewWithdraw(amount);
        uint256 assets = vault.convertToAssets(shares);
        return assets - (assets * slippageBPS / 10_000);
    }

    // Optional: yield tracking via price-per-share snapshots
    function _computeBaseRatePerSecond() internal override returns (uint256 ratePerSec, uint256 newIndex) {
        uint256 dt = lastSnapshotTime == 0 ? 0 : block.timestamp - lastSnapshotTime;
        uint256 currentPPS = vault.convertToAssets(1e18);
        newIndex = currentPPS;
        if (lastIndex == 0 || dt == 0 || currentPPS <= lastIndex) return (0, newIndex);
        uint256 growth = (currentPPS - lastIndex) * FIXED_POINT_SCALAR / lastIndex;
        ratePerSec = growth / dt;
        return (ratePerSec, newIndex);
    }
}
```

**Variations:**
- **WETH strategies:** Replace `IERC20` with `WETH` interface if native ETH unwrap is needed
- **Receipt token:** For ERC-4626, the receipt token passed to `MYTStrategy` constructor is typically the underlying asset address

---

## Pattern B: Lending Pool (Aave V3)

**Key trait:** `pool.supply(asset, amount, onBehalfOf, referralCode)` / `pool.withdraw(asset, amount, to)`. aToken balance reflects principal + interest (rebasing).

```solidity
interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IAaveAToken {
    function balanceOf(address) external view returns (uint256);
}

contract AaveV3{Chain}{Asset}Strategy is MYTStrategy {
    IERC20 public immutable underlying;
    IAavePool public immutable pool;
    IAaveAToken public immutable aToken;

    constructor(address _myt, StrategyParams memory _params, address _underlying, address _aToken, address _pool, address _permit2Address)
        MYTStrategy(_myt, _params, _permit2Address, _underlying)
    {
        underlying = IERC20(_underlying);
        pool = IAavePool(_pool);
        aToken = IAaveAToken(_aToken);
    }

    function _allocate(uint256 amount) internal override returns (uint256) {
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than amount");
        TokenUtils.safeApprove(address(underlying), address(pool), amount);
        pool.supply(address(underlying), amount, address(this), 0);
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 balanceBefore = TokenUtils.safeBalanceOf(address(underlying), address(this));
        pool.withdraw(address(underlying), amount, address(this));
        uint256 balanceAfter = TokenUtils.safeBalanceOf(address(underlying), address(this));
        uint256 redeemed = balanceAfter - balanceBefore;
        if (redeemed < amount) {
            emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, redeemed);
        }
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than the amount needed");
        TokenUtils.safeApprove(address(underlying), msg.sender, amount);
        return amount;
    }

    function realAssets() external view override returns (uint256) {
        // aToken balance reflects principal + interest in underlying units
        return aToken.balanceOf(address(this));
    }

    function _previewAdjustedWithdraw(uint256 amount) internal view override returns (uint256) {
        // aToken is 1:1 with underlying for withdrawal
        return amount - (amount * slippageBPS / 10_000);
    }
}
```

---

## Pattern C: Compound V2 / Moonwell

**Key trait:** `mToken.mint(amount)` / `mToken.redeemUnderlying(amount)`. Exchange-rate based accounting. `balanceOfUnderlying` is NOT a view function.

```solidity
interface IMToken {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
}

contract Moonwell{Asset}Strategy is MYTStrategy {
    IMToken public immutable mToken;
    IERC20 public immutable underlying;

    constructor(address _myt, StrategyParams memory _params, address _mToken, address _underlying, address _permit2Address)
        MYTStrategy(_myt, _params, _permit2Address, _underlying)
    {
        mToken = IMToken(_mToken);
        underlying = IERC20(_underlying);
    }

    function _allocate(uint256 amount) internal override returns (uint256) {
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than amount");
        TokenUtils.safeApprove(address(underlying), address(mToken), amount);
        mToken.mint(amount);
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 balanceBefore = TokenUtils.safeBalanceOf(address(underlying), address(this));
        mToken.redeemUnderlying(amount);
        uint256 balanceAfter = TokenUtils.safeBalanceOf(address(underlying), address(this));
        uint256 redeemed = balanceAfter - balanceBefore;
        if (redeemed < amount) {
            emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, redeemed);
        }
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than the amount needed");
        TokenUtils.safeApprove(address(underlying), msg.sender, amount);
        return amount;
    }

    // IMPORTANT: Use exchangeRateStored() (view) not balanceOfUnderlying() (mutates state)
    function realAssets() external view override returns (uint256) {
        uint256 mTokenBalance = mToken.balanceOf(address(this));
        if (mTokenBalance == 0) return 0;
        uint256 exchangeRate = mToken.exchangeRateStored();
        return (mTokenBalance * exchangeRate) / 1e18;
    }

    function _previewAdjustedWithdraw(uint256 amount) internal view override returns (uint256) {
        uint256 rate = mToken.exchangeRateStored();
        // ceil division for mTokens needed
        uint256 mTokensNeeded = (amount * 1e18 + rate - 1) / rate;
        uint256 usdcOut = (mTokensNeeded * rate) / 1e18;
        return usdcOut - (usdcOut * slippageBPS / 10_000);
    }
}
```

---

## Pattern D: ERC-4626 + Staking (Tokemak)

**Key trait:** Deposit into ERC-4626 vault via router, then stake shares in a separate rewarder contract. Withdraw = unstake + redeem.

```solidity
interface IERC4626Like is IERC4626 {
    function balanceOfActual(address account) external view returns (uint256);
}

interface IAutopilotRouter {
    function depositMax(IERC4626 vault, address to, uint256 minSharesOut) external payable returns (uint256 sharesOut);
}

interface IMainRewarder {
    function stake(address account, uint256 amount) external;
    function withdraw(address account, uint256 amount, bool claim) external;
    function getReward(address account, address recipient, bool claimExtras) external;
    function earned(address account) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function rewardToken() external view returns (address);
}

contract Toke{Vault}Strategy is MYTStrategy {
    IERC4626Like public immutable autoVault;
    IAutopilotRouter public immutable router;
    IMainRewarder public immutable rewarder;
    IERC20 public immutable underlying;  // WETH or USDC

    constructor(
        address _myt, StrategyParams memory _params,
        address _autoVault, address _router, address _rewarder,
        address _underlying, address _permit2Address
    ) MYTStrategy(_myt, _params, _permit2Address, _autoVault) {
        autoVault = IERC4626Like(_autoVault);
        router = IAutopilotRouter(_router);
        rewarder = IMainRewarder(_rewarder);
        underlying = IERC20(_underlying);
    }

    function _allocate(uint256 amount) internal override returns (uint256) {
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than amount");
        TokenUtils.safeApprove(address(underlying), address(router), amount);
        uint256 shares = router.depositMax(autoVault, address(this), 0);
        TokenUtils.safeApprove(address(autoVault), address(rewarder), shares);
        rewarder.stake(address(this), shares);
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 sharesNeeded = autoVault.convertToShares(amount);
        uint256 actualShares = rewarder.balanceOf(address(this));
        if (actualShares - sharesNeeded <= 1e18) sharesNeeded = actualShares;
        rewarder.withdraw(address(this), sharesNeeded, true);
        uint256 balanceBefore = TokenUtils.safeBalanceOf(address(underlying), address(this));
        autoVault.redeem(sharesNeeded, address(this), address(this));
        uint256 balanceAfter = TokenUtils.safeBalanceOf(address(underlying), address(this));
        uint256 redeemed = balanceAfter - balanceBefore;
        if (redeemed < amount) {
            emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, redeemed);
        }
        require(TokenUtils.safeBalanceOf(address(underlying), address(this)) >= amount, "Strategy balance is less than the amount needed");
        TokenUtils.safeApprove(address(underlying), msg.sender, amount);
        return amount;
    }

    function _claimRewards() internal override returns (uint256) {
        uint256 earned = rewarder.earned(address(this));
        rewarder.getReward(address(this), address(MYT), false);
        return earned;
    }

    function realAssets() external view override returns (uint256) {
        return autoVault.convertToAssets(rewarder.balanceOf(address(this)));
    }

    function _previewAdjustedWithdraw(uint256 amount) internal view override returns (uint256) {
        uint256 shares = autoVault.convertToShares(amount);
        uint256 assets = autoVault.convertToAssets(shares);
        return assets - (assets * slippageBPS / 10_000);
    }

    function _computeBaseRatePerSecond() internal override returns (uint256 ratePerSec, uint256 newIndex) {
        uint256 dt = lastSnapshotTime == 0 ? 0 : block.timestamp - lastSnapshotTime;
        uint256 currentPPS = autoVault.convertToAssets(1e18);
        newIndex = currentPPS;
        if (lastIndex == 0 || dt == 0 || currentPPS <= lastIndex) return (0, newIndex);
        uint256 growth = (currentPPS - lastIndex) * FIXED_POINT_SCALAR / lastIndex;
        ratePerSec = growth / dt;
        return (ratePerSec, newIndex);
    }
}
```

---

## Pattern E: Native ETH Bridge (Stargate)

**Key trait:** Protocol requires native ETH, not WETH. Must unwrap WETH before deposit, wrap ETH after withdrawal. May have dust rounding (e.g., Stargate rounds to 1e12).

```solidity
interface IStargatePool {
    function deposit(address receiver, uint256 amountLD) external payable returns (uint256);
    function redeem(uint256 lpAmount, address receiver) external returns (uint256);
    function redeemable(address owner) external view returns (uint256);
    function lpToken() external view returns (address);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract StargateEthPoolStrategy is MYTStrategy {
    IWETH public immutable weth;
    IStargatePool public immutable pool;
    IERC20 public immutable lp;

    constructor(address _myt, StrategyParams memory _params, address _weth, address _pool, address _permit2Address)
        MYTStrategy(_myt, _params, _permit2Address, _weth)
    {
        weth = IWETH(_weth);
        pool = IStargatePool(_pool);
        lp = IERC20(IStargatePool(_pool).lpToken());
    }

    function _allocate(uint256 amount) internal override returns (uint256) {
        require(TokenUtils.safeBalanceOf(address(weth), address(this)) >= amount, "not enough WETH");
        weth.withdraw(amount);
        // Handle rounding if protocol requires it
        uint256 depositAmount = (amount / 1e12) * 1e12;
        uint256 dust = amount - depositAmount;
        if (dust > 0) emit StrategyAllocationLoss("Rounding loss.", amount, depositAmount);
        pool.deposit{value: depositAmount}(address(this), depositAmount);
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 lpBalance = lp.balanceOf(address(this));
        uint256 lpNeeded = amount > lpBalance ? lpBalance : amount;
        TokenUtils.safeApprove(address(lp), address(pool), lpNeeded);
        uint256 ethBefore = address(this).balance;
        pool.redeem(lpNeeded, address(this));
        uint256 ethRedeemed = address(this).balance - ethBefore;
        if (ethRedeemed < amount) {
            emit StrategyDeallocationLoss("Strategy deallocation loss.", amount, ethRedeemed);
        }
        weth.deposit{value: ethRedeemed}();
        require(TokenUtils.safeBalanceOf(address(weth), address(this)) >= amount, "Strategy balance is less than the amount needed");
        TokenUtils.safeApprove(address(weth), msg.sender, amount);
        return amount;
    }

    function realAssets() external view override returns (uint256) {
        return pool.redeemable(address(this));
    }

    function _previewAdjustedWithdraw(uint256 amount) internal view override returns (uint256) {
        uint256 withSlippage = amount - (amount * slippageBPS / 10_000);
        return (withSlippage / 1e12) * 1e12;  // round down for dust
    }

    receive() external payable {}
}
```

---

## Pattern F: LST Mint + Redeem Queue (Frax)

**Key trait:** Mint via `submitAndDeposit{value: ...}()`, redeem via NFT withdrawal queue. Requires `IERC721Receiver`. Two-step withdrawal.

```solidity
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface FraxMinter {
    function submitAndDeposit(address recipient) external payable returns (uint256);
}

interface FraxRedemptionQueue {
    function enterRedemptionQueueViaSfrxEth(address _recipient, uint120 _sfrxEthAmount) external returns (uint256 _nftId);
    function burnRedemptionTicketNft(uint256 nftId, address recipient) external;
}

contract SfrxETHStrategy is MYTStrategy, IERC721Receiver {
    FraxMinter public immutable minter;
    FraxRedemptionQueue public immutable redemptionQueue;
    address public immutable sfrxEth;
    address public immutable WETH;

    // _deallocate returns NFT ID (enters queue)
    function _deallocate(uint256 amount) internal override returns (uint256) {
        require(amount <= type(uint120).max, "Amount exceeds uint120 max");
        uint256 nftId = redemptionQueue.enterRedemptionQueueViaSfrxEth(address(this), uint120(amount));
        return nftId;
    }

    // Separate claim via claimWithdrawalQueue
    function _claimWithdrawalQueue(uint256 positionId) internal override returns (uint256 ethOut) {
        uint256 balanceBefore = address(this).balance;
        redemptionQueue.burnRedemptionTicketNft(positionId, address(this));
        ethOut = address(this).balance - balanceBefore;
        IWETH(WETH).deposit{value: ethOut}();
        IWETH(WETH).approve(address(MYT), ethOut);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable { require(msg.sender == WETH, "Only WETH unwrap"); }
}
```

---

## Pattern G: LST Deposit Adapter (EtherFi)

**Key trait:** Deposit via protocol-specific adapter (`depositWETHForWeETH`), redeem via `RedemptionManager`. Receipt token is weETH.

```solidity
interface DepositAdapter {
    function depositWETHForWeETH(uint256 amount, address referral) external returns (uint256);
}

interface RedemptionManager {
    function redeemWeEth(uint256 amount, address receiver) external returns (uint256);
    function canRedeem(uint256 amount) external returns (bool);
}

contract EETHStrategy is MYTStrategy {
    DepositAdapter public immutable depositAdapter;
    RedemptionManager public immutable redemptionManager;
    IWETH public immutable weth;

    // receiptToken = weETH address (passed to MYTStrategy constructor)

    function _allocate(uint256 amount) internal override returns (uint256) {
        weth.approve(address(depositAdapter), amount);
        uint256 weethReceived = depositAdapter.depositWETHForWeETH(amount, address(0));
        weth.approve(address(depositAdapter), 0);
        return amount;
    }

    function _deallocate(uint256 amount) internal override returns (uint256) {
        uint256 weethBalance = TokenUtils.safeBalanceOf(receiptToken, address(this));
        require(amount <= weethBalance, "Insufficient weETH balance");
        require(redemptionManager.canRedeem(amount), "Cannot redeem");
        TokenUtils.safeApprove(receiptToken, address(redemptionManager), amount);
        uint256 redeemed = redemptionManager.redeemWeEth(amount, address(this));
        // Wrap ETH back to WETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            weth.deposit{value: ethBalance}();
        }
        TokenUtils.safeApprove(receiptToken, address(redemptionManager), 0);
        return redeemed;
    }

    receive() external payable {}
}
```

---

## Constructor Reference

The `MYTStrategy` base constructor signature:

```solidity
MYTStrategy(address _myt, StrategyParams memory _params, address _permit2Address, address _receiptToken)
```

| Parameter | What to pass |
|-----------|-------------|
| `_myt` | The Morpho V2 Vault address (passed in by deployer) |
| `_params` | `StrategyParams` struct with owner, name, protocol, riskClass, cap, globalCap, estimatedYield, additionalIncentives, slippageBPS |
| `_permit2Address` | Permit2 contract (same on all chains: `0x000000000022d473030f1dF7Fa9381e04776c7c5`) |
| `_receiptToken` | The yield-bearing token the strategy holds. For ERC-4626: underlying asset. For Tokemak: autopool address. For EtherFi: weETH. For Aave: underlying. |

**Permit2 address** is the same across all EVM chains: `0x000000000022d473030f1dF7Fa9381e04776c7c5`
