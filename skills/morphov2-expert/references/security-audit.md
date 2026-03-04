# Morpho Vault V2 — Security Audit Checklist

## Role & Access Control
- [ ] Owner can only set Curator, Sentinels, name, symbol — verify no fund access
- [ ] Curator actions properly timelocked (check every `submit` path)
- [ ] Sentinel can ONLY reduce risk (deallocate, decrease caps, revoke) — never increase
- [ ] Allocator bounded by Curator-set caps — cannot exceed absolute or relative caps
- [ ] `abdicate(selector)` is irreversible — verify no bypass
- [ ] 2-step ownership transfer if implemented (check for Alchemix-style `acceptAdmin` bugs)

## Adapter Security
- [ ] `realAssets()` cannot be manipulated (flash loan, donation, reentrancy)
- [ ] Adapter registry lock (`abdicate`) prevents unauthorized adapter additions
- [ ] Adapter cannot steal funds — verify it only holds position on behalf of vault
- [ ] New adapter enablement requires timelock — no instant addition
- [ ] Adapter removal doesn't strand funds (must deallocate first)
- [ ] `allocate()` data parameter validated by adapter (prevent arbitrary calls)

## Cap System
- [ ] Absolute caps properly enforce maximum allocation per id
- [ ] Relative caps checked on `allocate()` only — verify acceptable that withdrawals can exceed
- [ ] `increaseAbsoluteCap`/`increaseRelativeCap` both timelocked
- [ ] `decreaseAbsoluteCap`/`decreaseRelativeCap` instant (Sentinel + Curator) — correct
- [ ] id computation: `keccak256(idData)` — verify idData encoding matches adapter's id generation
- [ ] Cap struct: `allocation` field tracks current allocation per id — verify accounting

## Liquidity & Withdrawals
- [ ] Withdrawal priority: idle → liquidity adapter. Verify fallback behavior
- [ ] `forceDeallocate` penalty correctly applied (max 2%, scaled 1e18)
- [ ] `forceDeallocate` cannot be used to manipulate relative caps at low cost
- [ ] Flash loan + forceDeallocate in-kind exit: verify penalty makes manipulation unprofitable
- [ ] Insufficient idle + no liquidity adapter = withdrawal fails gracefully (no fund loss)

## Interest & Fees
- [ ] `accrueInterest()` called before state-changing operations
- [ ] Performance fee <= 50% enforced (0.5e18)
- [ ] Management fee <= 5% enforced (0.05e18)
- [ ] `maxRate` cap correctly limits `totalAssets` growth
- [ ] Fee shares minted to correct recipients
- [ ] No fee manipulation via deposit/withdraw timing (sandwich)

## Timelock Integrity
- [ ] `increaseTimelock` timelocked by its own current duration
- [ ] `decreaseTimelock(selector, duration)` timelocked by target function's current timelock
- [ ] Submitted proposals stored in `executableAt` mapping — verify no early execution
- [ ] `revoke()` by Sentinel/Curator cancels pending proposals correctly
- [ ] Zero timelock at deployment allows initial setup — verify timelocks set before production

## ERC-4626 Compliance
- [ ] `convertToShares`/`convertToAssets` account for fees
- [ ] `maxDeposit`/`maxMint`/`maxWithdraw`/`maxRedeem` return 0 (non-standard but documented)
- [ ] Share inflation attack mitigated (dead deposit on deployment)
- [ ] Rounding direction correct (deposit rounds up shares, withdraw rounds up assets)

## Gates
- [ ] Gate contracts checked on all transfer/deposit/withdraw paths
- [ ] Unset gate = unrestricted (verify)
- [ ] Gate setting is timelocked
- [ ] `abdicate` on gate function = permanently permissionless

## Common Vulnerability Patterns
1. **Adapter reentrancy**: External protocol callback during allocate/deallocate
2. **stale `realAssets()`**: Adapter reporting cached values, enabling arbitrage
3. **id collision**: Two different risk factors mapping to same keccak256 id
4. **Timelock bypass**: Exploiting zero-timelock window during deployment
5. **forceDeallocate griefing**: Repeated small deallocations to extract penalty-free value
6. **Cross-adapter accounting**: Allocation tracking mismatch between vault and adapter
7. **Fee-on-transfer tokens**: Vault assumes 1:1 transfer amounts
8. **Donation attack on totalAssets**: Direct token transfer inflating share price
