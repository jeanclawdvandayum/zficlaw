---
name: attack-vector-db
description: Machine-formatted database of 200+ smart contract attack vectors with built-in false-positive conditions. Each vector has a description, FP check, and category tag. Use during the vulnerability hunting phase of an audit — triage vectors against the codebase, skip irrelevant ones, deep-dive surviving ones. Covers ERC standards, DeFi patterns, access control, oracle manipulation, cross-chain/LayerZero, governance, proxy/upgrade, calldata, account abstraction, and EVM-level attacks.
---

# Attack Vector Database

200+ vectors organized by category. Each vector follows this format:

```
**N. Title**
- **D:** Description of the vulnerability pattern
- **FP:** Conditions that make this a false positive (if ANY apply, skip)
```

**Triage workflow:**
1. For each vector, classify: SKIP (not applicable), BORDERLINE (concept could manifest differently), SURVIVE (pattern clearly present)
2. For BORDERLINE: only promote if you can name the specific function AND describe the exploit in one sentence
3. For SURVIVE: trace full attack path per `finding-validation` skill

---

## Category: Signature & Authentication [SIG]

**1. Signature Malleability**
- **D:** Raw `ecrecover` without `s <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0` validation. Both `(v,r,s)` and `(v',r,s')` recover same address. Bypasses signature-based dedup.
- **FP:** OZ `ECDSA.recover()` used. Message hash used as dedup key, not signature bytes.

**2. EIP-712 Domain Separator Stale After Chain Fork**
- **D:** `DOMAIN_SEPARATOR` cached in immutable/constructor but includes `block.chainid`. After chain fork, cached value is stale — signatures valid on one chain replay on the other.
- **FP:** `DOMAIN_SEPARATOR` recomputed per-call when `block.chainid != cachedChainId`. EIP-712 `_domainSeparatorV4()` from OZ used.

**3. Permit Front-Running Grief**
- **D:** Attacker sees `permit()` in mempool, front-runs with same signature. Original tx reverts on duplicate nonce. If `permit + transferFrom` are separate calls (not atomic), attacker blocks the transfer.
- **FP:** `permit` and `transferFrom` in same tx (try/catch around permit). Contract handles permit failure gracefully.

**4. ecrecover Returns address(0) on Invalid Signature**
- **D:** `ecrecover` returns `address(0)` for invalid signatures. If result compared to a mapping where `address(0)` has a valid entry, auth is bypassed.
- **FP:** `require(recovered != address(0))`. OZ ECDSA used. No `address(0)` in authorized mappings.

**5. Missing Nonce (Signature Replay)**
- **D:** Signed message has no per-user nonce, or nonce present but never stored/incremented after use. Same signature resubmittable.
- **FP:** Monotonic per-signer nonce in signed payload, checked and incremented atomically. Or `usedSignatures[hash]` mapping.

**6. Missing chainId (Cross-Chain Replay)**
- **D:** Signed payload omits `chainId`. Valid signature replayable on forks/other EVM chains. Or `chainId` hardcoded at deployment instead of `block.chainid`.
- **FP:** EIP-712 domain separator includes dynamic `chainId: block.chainid` and `verifyingContract`.

**7. Commit-Reveal Scheme Not Bound to msg.sender**
- **D:** Commitment hash does not include `msg.sender`: `commit = keccak256(abi.encodePacked(value, salt))`. Attacker copies victim's commitment and submits their own reveal.
- **FP:** Commitment includes sender: `keccak256(abi.encodePacked(msg.sender, value, salt))`. Reveal validates `msg.sender` matches stored committer.

**8. ERC-1271 isValidSignature Delegated to Untrusted Module**
- **D:** `isValidSignature(hash, sig)` delegated to externally-supplied contract without whitelist check. Malicious module always returns `0x1626ba7e`, passing all signature checks.
- **FP:** Delegation only to owner-controlled whitelist. Module registry has timelock/guardian approval.

---

## Category: Token Standards & Interactions [TOK]

**9. Fee-on-Transfer Token Accounting Mismatch**
- **D:** Contract records `amount` from `transferFrom(from, to, amount)` but actual received is `amount - fee`. Accounting inflated. Withdrawals of last user fail.
- **FP:** Balance checked before/after transfer: `received = balanceAfter - balanceBefore`. Protocol explicitly rejects FoT tokens. Whitelist only non-FoT tokens.

**10. Rebasing Token Balance Drift**
- **D:** Contract caches token balance in storage. Rebasing token (stETH, aToken) changes balance externally. Cached balance becomes stale.
- **FP:** Uses wrapped non-rebasing version (wstETH). Balance read from `balanceOf()` every time. Protocol only supports non-rebasing tokens.

**11. ERC777 Reentrancy via tokensReceived Hook**
- **D:** ERC777-compatible token triggers `tokensReceived` hook on recipient before transfer completes. State is inconsistent during hook execution.
- **FP:** `nonReentrant` on all transfer-containing functions. No ERC777 tokens in scope. CEI pattern strictly followed.

**12. Token with Blacklist/Pause Causing DoS**
- **D:** USDC/USDT can blacklist addresses or pause globally. If contract address is blacklisted, all operations revert permanently.
- **FP:** Alternative withdrawal path. Admin can migrate to new token. Protocol only uses non-blacklistable tokens.

**13. Approval Race Condition (ERC20 approve)**
- **D:** `approve(spender, newAmount)` when existing allowance > 0. Spender front-runs with `transferFrom` using old allowance, then uses new allowance too.
- **FP:** Uses `increaseAllowance/decreaseAllowance`. Sets to 0 first. Uses Permit2.

**14. Non-Standard ERC20 Return Values (USDT-style)**
- **D:** USDT `transfer`/`approve` don't return `bool`. Standard `IERC20` interface expects `bool`. Call reverts on ABI decode.
- **FP:** SafeERC20/SafeTransferLib used. Explicit handling of missing return data.

**15. Solmate SafeTransferLib Missing Contract Existence Check**
- **D:** Solmate's `SafeTransferLib` does not verify target address contains code — `transfer` to an EOA or not-yet-deployed `CREATE2` address returns success silently.
- **FP:** OZ `SafeERC20` used. Manual `require(token.code.length > 0)` check. Token addresses verified at initialization.

**16. Zero-Amount Transfer Revert**
- **D:** `token.transfer(to, amount)` where `amount` can be zero (rounded fee, unclaimed yield). Some tokens (LEND, early BNB) revert on zero-amount transfers, DoS-ing distribution loops.
- **FP:** `if (amount > 0)` guard before all transfers. Minimum claim amount enforced.

**17. Weird Decimals (0, 2, 6, 8, 24+)**
- **D:** Math assumes 18 decimals. Tokens with 0 (some NFT wrappers), 2 (GUSD), 6 (USDC), 8 (WBTC), or 24+ decimals cause overflow/underflow/precision loss.
- **FP:** `10 ** decimals()` normalization applied. Only supports tokens with verified decimals.

**18. Token with Multiple Entry Points (Double-Spend)**
- **D:** Some tokens (TUSD legacy) have two contract addresses pointing to same balance. Deposit via address A, withdraw via address B bypasses accounting.
- **FP:** Token address canonicalized on deposit. Whitelist of known-good tokens.

**19. Depeg of Pegged/Wrapped Asset Breaking Assumptions**
- **D:** Protocol assumes 1:1 peg (stETH:ETH, WBTC:BTC, USDC:USD) in pricing or collateral valuation. During depeg, collateral is overvalued, enabling undercollateralized borrows.
- **FP:** Independent price feed per asset (not assumed 1:1). Configurable depeg threshold. Protocol documentation explicitly accepts depeg risk.

---

## Category: ERC721 & ERC1155 [NFT]

**20. ERC721/ERC1155 Callback Reentrancy**
- **D:** `safeTransferFrom`/`safeMint` triggers `onERC721Received`/`onERC1155Received` callback. If called before state update, callback can re-enter.
- **FP:** All state committed before safe transfer. `nonReentrant` applied.

**21. ERC721 Unsafe Transfer to Non-Receiver**
- **D:** `_transfer()`/`_mint()` used instead of `_safeTransfer()`/`_safeMint()`, sending NFTs to contracts without `IERC721Receiver`. Tokens permanently locked.
- **FP:** All paths use `safeTransferFrom`/`_safeMint`. Function is `nonReentrant`.

**22. ERC721 onERC721Received Arbitrary Caller Spoofing**
- **D:** `onERC721Received` uses parameters (`from`, `tokenId`) to update state without verifying `msg.sender` is the expected NFT contract.
- **FP:** `require(msg.sender == address(nft))` before state update.

**23. ERC721 Approval Not Cleared in Custom Transfer Override**
- **D:** Custom `transferFrom` override skips `super._transfer()`, missing the `delete _tokenApprovals[tokenId]` step. Previous approval persists under new owner.
- **FP:** Override calls `super.transferFrom` or explicitly deletes approval.

**24. ERC721Enumerable Index Corruption on Burn/Transfer**
- **D:** Override of `_beforeTokenTransfer` without calling `super`. Index structures become stale — `tokenOfOwnerByIndex` returns wrong IDs.
- **FP:** Override always calls `super` as first statement.

**25. ERC721A Lazy Ownership — ownerOf Uninitialized in Batch Range**
- **D:** ERC721A batch mint: only first token has ownership written. `ownerOf(id)` for mid-batch IDs may return `address(0)` before any transfer.
- **FP:** Explicit transfer initializes packed slot before ownership check. Standard OZ `ERC721` used.

**26. ERC721Consecutive Balance Corruption with Single-Token Batch**
- **D:** OZ `ERC721Consecutive` (< 4.8.2) + `_mintConsecutive(to, 1)` — size-1 batch fails to increment balance.
- **FP:** OZ >= 4.8.2 (patched). Batch size always >= 2. Standard `ERC721._mint` used.

**27. ERC1155 safeBatchTransferFrom Unchecked Array Lengths**
- **D:** Custom `_safeBatchTransferFrom` iterates `ids`/`amounts` without `require(ids.length == amounts.length)`.
- **FP:** OZ ERC1155 base used. Custom override asserts equal lengths.

**28. Missing onERC1155BatchReceived Causes Token Lock**
- **D:** Contract implements `onERC1155Received` but not `onERC1155BatchReceived`. `safeBatchTransferFrom` reverts, blocking batch settlement.
- **FP:** Both callbacks implemented. Inherits OZ `ERC1155Holder`.

**29. ERC1155 onERC1155Received Return Value Not Validated**
- **D:** Custom ERC1155 calls `onERC1155Received` but doesn't check returned `bytes4` equals `0xf23a6e61`.
- **FP:** OZ ERC1155 base validates selector.

**30. ERC1155 totalSupply Inflation via Reentrancy Before Supply Update**
- **D:** `totalSupply[id]` incremented AFTER `_mint` callback. During `onERC1155Received`, `totalSupply` is stale-low.
- **FP:** OZ >= 4.3.2 (patched). `nonReentrant` on all mint functions.

**31. ERC1155 Custom Burn Without Caller Authorization**
- **D:** Public `burn(address from, uint256 id, uint256 amount)` callable by anyone without verifying `msg.sender == from` or operator approval.
- **FP:** `require(from == msg.sender || isApprovedForAll(from, msg.sender))` before `_burn`. OZ `ERC1155Burnable` used.

**32. ERC1155 Fungible/Non-Fungible Token ID Collision**
- **D:** ERC1155 represents both fungible and unique items with no enforcement. Missing `require(totalSupply(id) == 0)` before NFT mint.
- **FP:** `require(totalSupply(id) + amount <= maxSupply(id))` with `maxSupply=1` for NFTs.

**33. ERC1155 Batch Transfer Partial-State Callback Window**
- **D:** Custom batch mint updates `_balances` and calls `onERC1155Received` per ID in loop. Callback reads stale balances for uncredited IDs.
- **FP:** All balance updates committed before any callback (OZ pattern).

**34. ERC1155 setApprovalForAll Grants All-Token-All-ID Access**
- **D:** Protocol requires `setApprovalForAll(protocol, true)`. No per-ID or per-amount granularity — operator can transfer any ID at full balance.
- **FP:** Protocol uses direct `safeTransferFrom` with user as `msg.sender`. Operator is immutable contract.

**35. ERC1155 ID-Based Role Access Control With Publicly Mintable Role Tokens**
- **D:** Access control via `require(balanceOf(msg.sender, ROLE_ID) > 0)` where `mint` for those IDs is not separately gated.
- **FP:** Minting role-token IDs gated behind separate access control. Role tokens non-transferable.

**36. ERC1155 uri() Missing {id} Substitution**
- **D:** `uri(uint256 id)` returns fully resolved URL instead of template with literal `{id}` placeholder per EIP-1155.
- **FP:** Returns string containing literal `{id}`. Or per-ID on-chain URI with documented deviation.

**37. ERC721/ERC1155 Type Confusion in Dual-Standard Marketplace**
- **D:** Shared `buy` function uses type flag for ERC721/ERC1155. `quantity` accepted for ERC721 without requiring == 1. `price * quantity` with `quantity = 0` yields zero payment.
- **FP:** ERC721 branch `require(quantity == 1)`. Separate code paths.

**38. EIP-2981 Royalty Signaled But Never Enforced**
- **D:** `royaltyInfo()` implemented but settlement logic never calls it or routes payment. EIP-2981 is advisory only.
- **FP:** Settlement contract reads `royaltyInfo()` and transfers royalty on-chain.

---

## Category: ERC4626 Vaults [VAULT]

**39. ERC4626 Inflation Attack (First Depositor)**
- **D:** `shares = assets * totalSupply / totalAssets`. When `totalSupply == 0`, deposit 1 wei + donate inflates share price, victim's deposit rounds to 0 shares.
- **FP:** OZ ERC4626 with `_decimalsOffset()`. Dead shares minted to `address(0)` at init. Minimum deposit.

**40. ERC4626 Share Price Manipulation via Donation**
- **D:** Attacker donates tokens directly to vault (not through deposit). Share price inflated. Subsequent operations use incorrect price.
- **FP:** Virtual shares. Internal accounting (not `balanceOf`). Donation detection.

**41. ERC4626 Missing Allowance Check in withdraw()/redeem()**
- **D:** `withdraw(assets, receiver, owner)` where `msg.sender != owner` but no allowance check/decrement before burning shares.
- **FP:** `_spendAllowance(owner, caller, shares)` called unconditionally when `caller != owner`. OZ ERC4626 without custom overrides.

**42. ERC4626 Preview Rounding Direction Violation**
- **D:** `previewDeposit` returns more shares than `deposit` mints. Custom `_convertToShares` with wrong `Math.mulDiv` rounding direction.
- **FP:** OZ ERC4626 base without overriding conversion functions.

**43. ERC4626 Deposit/Withdraw Share-Count Asymmetry**
- **D:** `_convertToShares` uses `Rounding.Floor` for both deposit and withdraw paths. `withdraw(a)` burns fewer shares than `deposit(a)` minted.
- **FP:** `deposit` uses `Floor`, `withdraw` uses `Ceil` (vault-favorable both directions).

**44. ERC4626 Mint/Redeem Asset-Cost Asymmetry**
- **D:** `redeem(s)` returns more assets than `mint(s)` costs. Root cause: `_convertToAssets` rounds up in `redeem`.
- **FP:** `redeem` uses `Math.Rounding.Floor`, `mint` uses `Math.Rounding.Ceil`.

**45. ERC4626 Round-Trip Profit Extraction**
- **D:** `redeem(deposit(a)) > a` — rounding errors in both directions favor the user.
- **FP:** Rounding per EIP-4626: deposit/mint round down, withdraw/redeem round up.

**46. ERC4626 Caller-Dependent Conversion Functions**
- **D:** `convertToShares()`/`convertToAssets()` branches on `msg.sender`-specific state. EIP-4626 requires caller-independence.
- **FP:** Implementation reads only global vault state.

**47. Yield Skimming via Frequent Deposit/Withdraw**
- **D:** Yield accrued in vault. Attacker deposits just before yield distribution, collects proportional share, withdraws immediately.
- **FP:** Time-weighted yield calculation. Entry/exit fees. Minimum lock period.

**48. Vault Share Price Monotonicity Violation**
- **D:** Share price can decrease without a loss event. Users who deposit before the decrease and withdraw after lose value.
- **FP:** Share price proven monotonically non-decreasing. Invariant test.

**49. Withdrawal Queue Starvation**
- **D:** Withdrawals processed FIFO. Large withdrawal at head blocks all subsequent ones if insufficient liquidity.
- **FP:** Partial fulfillment. Skip mechanism. Priority queue.

---

## Category: Access Control [ACL]

**50. Unprotected Initializer**
- **D:** `initialize()` function callable by anyone after deployment. Attacker front-runs legitimate initialization.
- **FP:** OpenZeppelin `initializer` modifier. Deployed + initialized atomically.

**51. Missing Access Control on State-Changing Function**
- **D:** Function modifies critical state but has no `onlyOwner`/`onlyRole`/`msg.sender` check.
- **FP:** Function is intentionally public. Access control in called internal function. Modifier inherited.

**52. Default Admin Role is address(0)**
- **D:** OZ AccessControl `DEFAULT_ADMIN_ROLE` member is 0x0 if not granted in constructor. New roles can never be granted.
- **FP:** Admin role explicitly granted in constructor/initializer. Custom admin role used.

**53. Privilege Escalation via Role Hierarchy**
- **D:** Role A can grant Role B, Role B has higher privileges than A. Or self-granting through circular role admin relationships.
- **FP:** Role admin hierarchy is acyclic. Higher-privilege roles always admin lower ones.

**54. tx.origin Authentication**
- **D:** `require(tx.origin == owner)` instead of `msg.sender`. Phishing attack via malicious intermediate contract.
- **FP:** `msg.sender` used for all auth. `tx.origin` only used for anti-contract checks.

**55. Deployer Privilege Retention Post-Deployment**
- **D:** Deployer EOA retains owner/admin/minter/pauser after deployment script completes. Pattern: `Ownable` sets `owner = msg.sender` with no `transferOwnership()`.
- **FP:** Script includes `transferOwnership(multisig)`. Deployer renounces roles.

**56. extcodesize Zero in Constructor**
- **D:** `require(msg.sender.code.length == 0)` as EOA check. Contract constructors have `extcodesize == 0`, bypassing the check.
- **FP:** Check is non-security-critical. Function protected by other mechanisms.

---

## Category: Reentrancy [REEN]

**57. Single-Function Reentrancy**
- **D:** External call before state update — check-external-effect instead of CEI.
- **FP:** State updated before call. `nonReentrant` modifier. Callee is hardcoded immutable.

**58. Cross-Function Reentrancy**
- **D:** Reentrancy guard on function A, but attacker re-enters through function B which shares state with A.
- **FP:** Global `nonReentrant` on all state-changing functions. CEI pattern on all paths.

**59. Cross-Contract Reentrancy**
- **D:** Contract A calls Contract B. B calls back into A (or Contract C that reads A's state). A's state is inconsistent during callback.
- **FP:** All state finalized before external calls. Reentrancy guard spans all contracts.

**60. Read-Only Reentrancy**
- **D:** No state modification during reentry, but attacker reads stale state (e.g., vault share price mid-withdrawal) in another protocol.
- **FP:** All state updates complete before any external call. Reentrancy guard on view functions.

**61. Reentrancy via Native ETH Transfer**
- **D:** `.call{value: amount}("")` triggers `receive()`/`fallback()`. State not yet updated.
- **FP:** CEI pattern. `nonReentrant`.

**62. Transient Storage Low-Gas Reentrancy (EIP-1153)**
- **D:** Contract uses `transfer()`/`send()` (2300-gas) as reentrancy guard + uses `TSTORE`/`TLOAD`. Post-Cancun, `TSTORE` succeeds under 2300 gas.
- **FP:** `nonReentrant` backed by regular storage. CEI followed unconditionally.

**63. Cross-Chain Reentrancy via Safe Transfer Callbacks**
- **D:** Cross-chain receive function calls `_safeMint` before updating counters. Callback re-enters to initiate another cross-chain send.
- **FP:** State updates committed before safe transfer. `nonReentrant` on receive path.

---

## Category: Oracle & Price Manipulation [ORC]

**64. Spot Price Manipulation via Flash Loan**
- **D:** Price derived from DEX reserves at transaction time. Flash loan skews reserves, manipulates price.
- **FP:** TWAP used. Oracle independent of DEX. Chainlink feed with deviation threshold.

**65. Stale Oracle Price (Chainlink)**
- **D:** `latestRoundData()` called but missing `updatedAt` staleness check. Protocol uses stale price.
- **FP:** `require(block.timestamp - updatedAt < MAX_STALENESS)`. Heartbeat check. Circuit breaker.

**66. Oracle Decimal Mismatch**
- **D:** Chainlink feeds return different decimals (8 for USD, 18 for ETH pairs). Math doesn't normalize.
- **FP:** `feed.decimals()` queried and normalized. Hardcoded correct decimal.

**67. Oracle Round Completeness**
- **D:** `latestRoundData()` may return data from incomplete round. `answeredInRound < roundId` indicates stale.
- **FP:** `require(answeredInRound >= roundId)`.

**68. Oracle Returning Zero/Negative Price**
- **D:** `latestRoundData()` returns 0 or negative price during malfunction. Division by zero or underflow.
- **FP:** `require(price > 0)`. Fallback oracle.

**69. TWAP Manipulation Over Short Window**
- **D:** TWAP window too short (<30 min). Multi-block manipulation can shift TWAP profitably.
- **FP:** TWAP window >= 30 min. TWAP validated against Chainlink bounds.

**70. Multi-Block TWAP Manipulation**
- **D:** Post-Merge validators controlling consecutive blocks can hold manipulated AMM state, shifting TWAP.
- **FP:** TWAP window >= 30 min. Chainlink/Pyth as primary. Max-deviation circuit breaker.

**71. Wrong Price Feed for Derivative/Wrapped Asset**
- **D:** Protocol uses ETH/USD feed to price stETH collateral. During depeg events, mispricing enables undercollateralized borrows.
- **FP:** Dedicated feed for the actual derivative asset. Deviation check against secondary oracle.

**72. Chainlink Feed Deprecation / Hardcoded Address**
- **D:** Chainlink aggregator address hardcoded/immutable with no update path. Deprecated feed returns stale/zero price.
- **FP:** Feed address updatable via governance. Secondary oracle deviation check.

**73. Missing Oracle Price Bounds (Flash Crash)**
- **D:** Oracle returns technically valid but extreme price. No min/max sanity bound. Protocol executes at wildly incorrect prices.
- **FP:** Circuit breaker: `require(price >= MIN && price <= MAX)`. Deviation check against secondary source.

**74. Oracle Price Update Front-Running**
- **D:** On-chain oracle update tx visible in mempool. Attacker front-runs favorable price update.
- **FP:** Pull-based oracle (user submits price atomically). Private mempool.

**75. L2 Sequencer Uptime Not Checked**
- **D:** Contract on L2 uses Chainlink feeds without querying Sequencer Uptime Feed. Stale data during downtime triggers wrong liquidations.
- **FP:** Sequencer uptime feed queried with grace period after restart.

---

## Category: Flash Loan & Economic [ECON]

**76. Flash Loan Governance Attack**
- **D:** Governance votes weighted by token balance. Flash loan tokens, vote, return in same tx.
- **FP:** `getPastVotes(block.number - 1)`. Snapshot-based voting. Minimum holding period.

**77. Sandwich Attack on User Swap**
- **D:** Attacker front-runs user's swap, moves price unfavorably, user executes at worse price, attacker back-runs.
- **FP:** Slippage protection (`amountOutMin`). Private mempool. Commit-reveal.

**78. Flash Loan Price Manipulation for Liquidation**
- **D:** Flash loan to manipulate oracle price → position becomes liquidatable → liquidate → profit.
- **FP:** Oracle resistant to single-block manipulation. Liquidation uses independent oracle.

**79. Same-Block Deposit-Withdraw Exploiting Snapshot Benefits**
- **D:** Protocol calculates yield/rewards/voting power at a single snapshot. No minimum lock period. Flash-loan attack.
- **FP:** `getPastVotes(block.number - 1)`. Minimum holding period. Multi-block accrual.

**80. Self-Liquidation Profit Extraction**
- **D:** Borrower liquidates their own position from second address, collecting liquidation bonus on their own collateral.
- **FP:** `require(msg.sender != borrower)`. Liquidation incentive small enough that self-liquidation is net-negative.

**81. Small Positions Unliquidatable (Bad Debt)**
- **D:** Positions below certain USD value cost more gas to liquidate than the reward. Dust positions accumulate bad debt.
- **FP:** Minimum position size enforced. Protocol-operated liquidation bot. Socialized bad debt mechanism.

**82. Staking Reward Front-Run by New Depositor**
- **D:** Reward checkpoint updated AFTER new stake recorded. New staker earns rewards for unstaked period.
- **FP:** `updateReward(account)` executes before any balance update.

---

## Category: Proxy & Upgrade [PROX]

**83. Uninitialized Implementation Contract**
- **D:** Implementation behind proxy has `initialize()` not called on the implementation itself. Attacker calls `initialize()`, becomes owner.
- **FP:** `_disableInitializers()` in constructor. Implementation initialized.

**84. Re-initialization Attack**
- **D:** V2 uses `initializer` instead of `reinitializer(2)`. Or upgrade resets initialized counter.
- **FP:** `reinitializer(version)` with correctly incrementing versions. Tests verify `initialize()` reverts.

**85. Non-Atomic Proxy Initialization (Front-Running)**
- **D:** Proxy deployed in one tx, `initialize()` in separate tx. Uninitialized proxy front-runnable.
- **FP:** Proxy constructor receives init calldata atomically. OZ `deployProxy()` used.

**86. Storage Layout Collision on Upgrade**
- **D:** New implementation changes storage variable ordering. Existing data misinterpreted.
- **FP:** Storage gap pattern. OZ upgradeable contracts with storage checker.

**87. Storage Layout Shift on Upgrade**
- **D:** V2 inserts new state variable in middle instead of appending. Subsequent variables shift slots.
- **FP:** New variables only appended. OZ storage layout validation in CI.

**88. Function Selector Clash (Transparent Proxy)**
- **D:** Proxy admin function and implementation function have same 4-byte selector. Wrong function called.
- **FP:** EIP-1967 transparent proxy. UUPS pattern. Selector collision checked.

**89. Delegatecall to Untrusted Implementation**
- **D:** `delegatecall` target is controllable by attacker. Malicious implementation modifies storage.
- **FP:** Implementation address in immutable or admin-only storage. EIP-1967 slot.

**90. UUPS Missing Upgrade Authorization**
- **D:** `_authorizeUpgrade()` left empty or returns without checking auth. Anyone can upgrade.
- **FP:** `onlyOwner` or governance check in `_authorizeUpgrade`.

**91. UUPS Upgrade Logic Removed in New Implementation**
- **D:** New UUPS implementation doesn't inherit `UUPSUpgradeable`. Proxy permanently loses upgrade capability.
- **FP:** Every version inherits `UUPSUpgradeable`. Tests verify `upgradeTo` works after each upgrade.

**92. Transparent Proxy Admin Routing Confusion**
- **D:** Admin address also used for regular protocol interactions. Calls from admin route to proxy admin functions instead of delegating.
- **FP:** Dedicated `ProxyAdmin` contract used exclusively.

**93. Beacon Proxy Single-Point-of-Failure Upgrade**
- **D:** Multiple proxies read implementation from single Beacon. Compromising Beacon owner upgrades all proxies at once.
- **FP:** Beacon owner is multisig + timelock. Per-proxy upgrade authority where isolation required.

**94. Upgrade Race Condition / Front-Running**
- **D:** `upgradeTo(V2)` and post-upgrade config are separate txs. Window for front-running.
- **FP:** `upgradeToAndCall()` bundles upgrade + init. Private mempool. Timelock.

**95. Proxy Admin Key Compromise**
- **D:** `ProxyAdmin.owner()` returns EOA, not multisig/governance; no timelock.
- **FP:** Multisig + timelock (24-72h). Admin role separate from operational.

**96. Immutable Variable Context Mismatch**
- **D:** Implementation uses `immutable` variables. Proxy `delegatecall` gets implementation's hardcoded values regardless of per-proxy needs.
- **FP:** Immutable values intentionally identical. Per-proxy config uses storage.

**97. Minimal Proxy (EIP-1167) Implementation Destruction**
- **D:** EIP-1167 clones `delegatecall` a fixed implementation. If implementation is destroyed, all clones become no-ops.
- **FP:** No `selfdestruct` in implementation. Post-Dencun: code not destroyed.

**98. Diamond Proxy Cross-Facet Storage Collision**
- **D:** EIP-2535 facets declare storage variables without EIP-7201 namespaced storage. Multiple facets start at slot 0.
- **FP:** All facets use single `DiamondStorage` struct at namespaced position.

**99. Diamond Facet Selector Collision**
- **D:** Two facets register same 4-byte selector. Malicious facet hijacks calls.
- **FP:** `diamondCut` validates no selector collisions. Multisig + timelock.

**100. Proxy Storage Slot Collision**
- **D:** Proxy stores `implementation`/`admin` at sequential slots (0, 1). Implementation also declares variables from slot 0.
- **FP:** EIP-1967 randomized slots. OZ Transparent/UUPS pattern.

---

## Category: Math & Precision [MATH]

**101. Rounding Direction Favoring Attacker**
- **D:** Division rounds down for shares-out (deposit) but should round down for assets-out (withdraw). Wrong rounding lets attacker extract 1 wei per operation.
- **FP:** `mulDivUp`/`mulDivDown` used correctly. Protocol-favorable rounding.

**102. Precision Loss in Fee Calculation**
- **D:** Fee = `amount * feeRate / PRECISION`. If `amount * feeRate < PRECISION`, fee rounds to 0.
- **FP:** Minimum fee enforced. Fee calculated before division.

**103. Unsafe Cast (uint256 to uint128/int256)**
- **D:** Downcasting without overflow check. Value > type max silently truncated.
- **FP:** SafeCast library used. Solidity >= 0.8.0 with explicit checks.

**104. Small-Type Arithmetic Overflow Before Upcast**
- **D:** Arithmetic on `uint8`/`uint16`/`uint32` before assigning to wider type. Overflow happens in narrow type before widening.
- **FP:** Operands explicitly upcast before operation: `uint256(a) * uint256(b)`.

**105. Division Before Multiplication**
- **D:** `(a / b) * c` — truncation before multiplication amplifies error.
- **FP:** `a` provably divisible by `b`. Operations ordered as `mulDiv`.

**106. Phantom Overflow in Intermediate Calculation**
- **D:** `a * b` overflows uint256 even though final result would fit after division.
- **FP:** `mulDiv` with 512-bit intermediate. Input ranges validated.

**107. Integer Overflow/Underflow in unchecked**
- **D:** Arithmetic in `unchecked {}` without prior bounds check.
- **FP:** Range provably bounded. `unchecked` only for `++i` loop increments.

**108. Off-By-One in Bounds or Range Checks**
- **D:** `i <= arr.length` in loop (accesses OOB index). `>=` vs `>` confusion in financial logic.
- **FP:** Loop uses `<`. Last-element access preceded by length check.

**109. Batch Distribution Dust Residual**
- **D:** Loop distributes funds proportionally. Cumulative rounding causes `sum(shares) < total`, leaving dust locked.
- **FP:** Last recipient gets `total - sumOfPrevious`. Dust swept to treasury.

---

## Category: Calldata & ABI [CALL]

**110. msg.value Reuse in Loop/Multicall**
- **D:** `msg.value` read inside a loop or `delegatecall`-based multicall. Each iteration sees full original value.
- **FP:** `msg.value` captured to local var, decremented per iteration. Function non-payable. Multicall uses `call` not `delegatecall`.

**111. Dirty High Bits in Assembly Address Parsing**
- **D:** `calldataload` for address parameter without masking to 160 bits. Dirty high bytes affect hash computations.
- **FP:** `shr(96, calldataload(...))` used. Standard Solidity decoding.

**112. Short Calldata Attack**
- **D:** Calldata shorter than expected. Manual `calldataload` reads zero-padded data. Parameters default to zero.
- **FP:** `require(msg.data.length >= MIN)`. Standard Solidity ABI decoder (reverts on short calldata).

**113. Calldataload/Calldatacopy Out-of-Bounds Read**
- **D:** `calldataload(offset)` where `offset` exceeds actual calldata length. Returns zero-padded bytes silently.
- **FP:** `calldatasize()` validated. Static offsets into known fixed-length signatures.

**114. Function Selector Collision in Proxy**
- **D:** Proxy admin function has same 4-byte selector as implementation function.
- **FP:** EIP-1967 transparent proxy. Selector collision checked.

**115. Non-Canonical ABI Encoding Bypass**
- **D:** Same logical value encoded differently. Hash-based dedup sees different hashes for semantically identical data.
- **FP:** Decoded values re-encoded canonically before hashing.

**116. Extra Trailing Calldata**
- **D:** Solidity ignores trailing calldata. If calldata is forwarded, extra bytes may be interpreted.
- **FP:** Only standard Solidity calls. Trailing data stripped before forwarding.

**117. Return Bomb (Returndata Copy DoS)**
- **D:** External call to untrusted target. Target returns massive data. `returndatacopy` consumes all gas.
- **FP:** Return data size bounded. Low-level call with explicit return buffer.

**118. Insufficient Return Data Length Validation**
- **D:** Assembly call writes return data into fixed-size buffer then reads without checking `returndatasize() >= 32`. EOA or non-compliant contract returns zero bytes; `mload` reads stale memory as truthy.
- **FP:** `if lt(returndatasize(), 32) { revert }` before reading. `extcodesize(target)` verified > 0.

**119. Hardcoded Calldataload Offset Bypass**
- **D:** Assembly reads field at hardcoded calldata offset assuming standard ABI layout. Attacker crafts non-canonical encoding.
- **FP:** Field decoded via `abi.decode()`. No hardcoded `calldataload` offsets.

**120. Calldata Input Malleability**
- **D:** Contract hashes raw calldata for uniqueness. Dynamic-type ABI encoding uses offset pointers — multiple distinct layouts decode to identical values.
- **FP:** Uniqueness check hashes decoded parameters. Nonce-based replay protection.

**121. abi.encodePacked Hash Collision with Dynamic Types**
- **D:** `keccak256(abi.encodePacked(a, b))` where two+ args are dynamic types. No length prefix means different inputs produce identical hashes.
- **FP:** `abi.encode()` used. Only one dynamic type arg. All args fixed-size.

---

## Category: Cross-Chain & LayerZero [XCHAIN]

**122. Message Replay Across Chains**
- **D:** Cross-chain message doesn't include destination chain ID. Same message valid on multiple chains.
- **FP:** Chain ID in message hash. Per-chain nonces.

**123. Message Replay Same Chain (Nonce Missing)**
- **D:** No nonce or dedup mechanism. Same message executed multiple times.
- **FP:** Per-sender nonce. Message hash stored after execution.

**124. Source Chain Finality Not Validated**
- **D:** Message relayed before source chain finality. Reorg removes originating transaction.
- **FP:** Bridge waits for finality. Optimistic challenge period.

**125. Insufficient Block Confirmations / Reorg Double-Spend**
- **D:** DVN relays message before source chain finality. Attacker deposits, gets minted, reorg reverses deposit.
- **FP:** Confirmation count matches chain-specific finality. Chain has fast finality.

**126. Arbitrary Target in Bridge Executor**
- **D:** Bridge message specifies target address. If attacker-controlled, they receive arbitrary calls with bridge's authority.
- **FP:** Target allowlisted. Function selector allowlisted. Target hardcoded.

**127. Cross-Chain Message Spoofing (Missing Endpoint/Peer Validation)**
- **D:** Receiver accepts messages without verifying `msg.sender == endpoint` and `_origin.sender == registeredPeer[srcChainId]`. Attacker calls receive function directly.
- **FP:** `onlyPeer` modifier checks both. Standard `OAppReceiver._acceptNonce` validates origin.

**128. lzCompose Sender Impersonation (LayerZero)**
- **D:** `lzCompose` implementation does not validate `msg.sender == endpoint` or `_from` parameter against expected OFT address.
- **FP:** `require(msg.sender == address(endpoint))` and `require(_from == expectedOFT)` validated. Standard `OAppReceiver` modifier.

**129. Ordered Message Channel Blocking (Nonce DoS)**
- **D:** OApp uses ordered nonce execution. If one message permanently reverts, ALL subsequent messages blocked.
- **FP:** Unordered nonce mode (V2 default). Try/catch with fallback. Admin can `skipPayload`.

**130. Delegate Privilege Escalation (LayerZero)**
- **D:** `setDelegate()` appoints address that can manage OApp configs. Insecure delegate can reconfigure security stack.
- **FP:** Delegate == owner. Delegate is governance timelock. `setDelegate` protected.

**131. Cross-Chain Supply Accounting Invariant Violation**
- **D:** Invariant `total_locked_source >= total_minted_destination` violated. Decimal conversion errors, `_credit` callable without `_debit`, race conditions.
- **FP:** Invariant verified via monitoring. `_credit` only from verified `lzReceive`. Rate limits.

**132. OFT Shared Decimals Truncation (uint64 Overflow)**
- **D:** OFT converts between local and shared decimals. `_toSD()` casts to `uint64`. Large amounts silently truncated.
- **FP:** Standard OFT with `sharedDecimals = 6`. Transfer amounts validated against `uint64.max`.

**133. Missing `_debit`/`_debitFrom` Authorization in OFT**
- **D:** Custom OFT override of `_debit` omits authorization check. Anyone can bridge from any holder's balance.
- **FP:** Standard LayerZero OFT used. Custom `_debit` includes authorization.

**134. Missing enforcedOptions (Insufficient Gas)**
- **D:** OApp does not call `setEnforcedOptions()` to mandate minimum gas. User-supplied options cause `lzReceive` to revert on destination.
- **FP:** `enforcedOptions` configured with tested gas limits. Simple `lzReceive` logic.

**135. State-Time Lag Exploitation (lzRead Stale State)**
- **D:** `lzRead` queries state on remote chain. Latency window between query and delivery. Protocol makes decisions based on stale read.
- **FP:** Read targets immutable/slowly-changing state. Read result treated as hint with re-validation.

**136. Unauthorized Peer Initialization (Fake Peer Attack)**
- **D:** `setPeer()` sets remote peer address. Compromised owner or unprotected `setPeer` allows fraudulent peer registration.
- **FP:** `setPeer` protected by multisig + timelock. Peer addresses verified.

**137. Default Message Library Hijack**
- **D:** OApp does not pin send/receive library version. Malicious default library update silently applies.
- **FP:** OApp explicitly sets library versions. Configuration immutable or governance-controlled.

**138. DVN Collusion or Insufficient Diversity**
- **D:** OApp configured with single DVN or DVNs controlled by same entity. Compromising one entity approves fraudulent messages.
- **FP:** Diverse DVN set with 2/3+ threshold. DVNs use independent verification methods.

**139. Missing Cross-Chain Rate Limits / Circuit Breakers**
- **D:** Bridge/OFT has no per-transaction or time-window caps. Single exploit drains entire pool.
- **FP:** Per-tx and per-window rate limits. `whenNotPaused` modifier. Guardian can freeze.

**140. Cross-Chain Address Ownership Variance**
- **D:** Same address has different owners on different chains (CREATE nonce differences). Cross-chain logic assumes same owner.
- **FP:** CREATE2 contracts with same factory + salt. Peer mapping binds (chainId, address) pairs.

**141. Cross-Chain Deployment Replay**
- **D:** Deployment tx replayed on another chain. Same CREATE address under different control. No EIP-155 protection.
- **FP:** EIP-155 signatures. CREATE2 via deterministic factory. Per-chain deployer EOAs.

---

## Category: Governance & Voting [GOV]

**142. Quorum Based on Total Supply (Includes Locked/Burned)**
- **D:** Quorum calculated as percentage of `totalSupply()`. Includes dead address, locked tokens. Quorum effectively impossible.
- **FP:** Quorum based on delegated/voting supply. Adjustable quorum.

**143. Vote After Delegation Transfer**
- **D:** User delegates, then transfers tokens. Delegation active with stale balance.
- **FP:** Checkpoint-based voting. Delegation updates on transfer.

**144. Proposal Griefing via Dust Threshold**
- **D:** Proposal creation requires balance >= threshold. Attacker transfers dust to push above, then away to drop below during voting.
- **FP:** Snapshot-based threshold check. Minimum proposal deposit.

**145. Governance Flash-Loan Upgrade Hijack**
- **D:** Proxy upgrades via governance using current-block vote weight. Flash-borrow, vote, execute in one tx.
- **FP:** `getPastVotes(block.number - 1)`. Timelock 24-72h. High quorum.

---

## Category: DoS & Griefing [DOS]

**146. Unbounded Loop Over User-Growable Array**
- **D:** Loop iterates over array that users can append to. Array grows until loop exceeds block gas limit.
- **FP:** Array size bounded. Pagination. Off-chain computation.

**147. External Call Failure Blocking Loop**
- **D:** Loop sends tokens/ETH to multiple recipients. One reverts, entire distribution blocked.
- **FP:** Pull pattern. Try/catch. Skip failing recipients.

**148. Dust Amount Griefing**
- **D:** Attacker deposits 1 wei. Creates entry in array/mapping. Bloats state or blocks withdrawals.
- **FP:** Minimum amount enforced. State cleanup mechanism.

**149. DoS via Push Payment to Rejecting Contract**
- **D:** ETH distribution via `recipient.call{value:}("")`. Any reverting recipient blocks entire loop.
- **FP:** Pull-over-push. Loop uses try/catch.

**150. Block Stuffing**
- **D:** Attacker fills blocks to prevent time-sensitive transactions.
- **FP:** Multi-block window. Keeper competition.

**151. Storage Write Griefing (Out of Gas)**
- **D:** Function writes to N storage slots where N is influenced by attacker input. Gas cost = 20,000 * N.
- **FP:** N bounded. Incremental writes.

**152. Griefing via Dust Deposits Resetting Timelocks**
- **D:** Timelock/cooldown resets on any deposit with no minimum. Attacker calls `deposit(1)` to reset victim's lock.
- **FP:** Minimum deposit enforced. Cooldown resets only for depositing user.

**153. Front-Running Zero Balance Check with Dust Transfer**
- **D:** `require(balance == 0)` gates state transition. Dust transfer makes balance non-zero, DoS-ing function.
- **FP:** Threshold check instead of `== 0`. Access-controlled function.

---

## Category: Time & Ordering [TIME]

**154. Block Timestamp Manipulation**
- **D:** `block.timestamp` for auction/game timing. Validators can shift ~15 seconds.
- **FP:** Used only for day/hour scale. No time-sensitive outcomes in 15s window.

**155. Block Number as Timestamp Approximation**
- **D:** Time computed as `(block.number - startBlock) * 13` assuming fixed block times. Wrong on variable-time chains.
- **FP:** `block.timestamp` used for all time-sensitive calculations.

**156. Deadline Check Off-By-One**
- **D:** `require(timestamp <= deadline)` vs `< deadline`. Allows execution at expiry.
- **FP:** One-second difference immaterial. User-specified deadline.

**157. Missing or Expired Deadline on Swaps**
- **D:** `deadline = block.timestamp` (always valid), `deadline = type(uint256).max`, or no deadline. Tx holdable in mempool.
- **FP:** Deadline is calldata parameter validated, not derived internally.

**158. Missing Slippage Protection (Sandwich Attack)**
- **D:** Swap/deposit/withdrawal with `minAmountOut = 0`, or computed on-chain from current pool state.
- **FP:** `minAmountOut` set off-chain by user and validated on-chain.

**159. Slippage Enforced at Intermediate Step Only**
- **D:** Multi-hop swap checks `minAmountOut` on first hop only. Second/third hops can be sandwiched.
- **FP:** `minAmountOut` validated against final received balance.

---

## Category: Assembly & EVM [ASM]

**160. Assembly Arithmetic Silent Overflow/Division-by-Zero**
- **D:** Arithmetic inside `assembly {}` does not revert on overflow/underflow (wraps) and division by zero returns 0.
- **FP:** Manual overflow checks in assembly. Denominator checked before `div`.

**161. Scratch Space Corruption Across Assembly Blocks**
- **D:** Data written to scratch space (`0x00`–`0x3f`) expected to persist, but intervening Solidity code overwrites it.
- **FP:** All scratch space reads in same contiguous assembly block. Scratch space rewritten before each use.

**162. Free Memory Pointer Corruption**
- **D:** Assembly writes to memory at fixed offsets without updating free memory pointer at `0x40`. Subsequent Solidity overwrites.
- **FP:** Assembly reads `mload(0x40)`, writes above, updates pointer. Only uses scratch space.

**163. mstore8 Partial Write Leaving Dirty Bytes**
- **D:** `mstore8` writes single byte. Subsequent `mload` reads full 32-byte word with stale data in other 31 bytes.
- **FP:** Full word zeroed before byte-level writes. Result masked.

**164. Returndatasize-as-Zero Assumption**
- **D:** Assembly uses `returndatasize()` as gas-cheap zero. If prior call returned data, value is nonzero.
- **FP:** `returndatasize()` used only at start of execution before any external calls.

**165. Dirty Higher-Order Bits on Sub-256-Bit Types**
- **D:** Assembly loads full 32-byte word but treats as smaller type without masking. Dirty bits cause incorrect comparisons.
- **FP:** Explicit bitmask applied. Value from prior Solidity expression already cleaned.

**166. Signed Integer Mishandling (signextend/sar/slt)**
- **D:** Assembly performs signed arithmetic but uses unsigned opcodes. `shr` instead of `sar` loses sign bit.
- **FP:** Code uses `sar`/`slt`/`sgt` for signed operations. `signextend` applied after loading sub-256-bit signed values.

**167. Write to Arbitrary Storage Location**
- **D:** `sstore(slot, value)` where `slot` derived from user input without bounds.
- **FP:** Assembly is read-only. Slot is compile-time constant.

**168. Assembly Delegatecall Missing Return/Revert Propagation**
- **D:** Proxy fallback performs `delegatecall` but omits copying return data or branching on result.
- **FP:** Complete proxy pattern with `returndatacopy` and `switch result`. OZ Proxy.sol used.

---

## Category: Deployment & Configuration [DEPLOY]

**169. Deployment Transaction Front-Running (Ownership Hijack)**
- **D:** Deployment tx sent to public mempool. Attacker extracts bytecode and deploys first.
- **FP:** Private relay used. Owner passed as constructor arg. CREATE2 salt tied to deployer.

**170. Non-Atomic Multi-Contract Deployment**
- **D:** Deployment script deploys interdependent contracts across separate txs. Midway failure leaves half-deployed state.
- **FP:** Single broadcast block. Factory deploys+wires all in one tx.

**171. CREATE/CREATE2 Deployment Failure Returns Zero**
- **D:** Assembly `create`/`create2` returns `address(0)` on failure but code doesn't check.
- **FP:** Immediate check: `if iszero(addr) { revert }`.

**172. CREATE2 Address Squatting (Counterfactual Front-Running)**
- **D:** CREATE2 salt not bound to `msg.sender`. Attacker precomputes address and deploys first.
- **FP:** Salt incorporates `msg.sender`. Factory restricts deployer.

**173. Counterfactual Wallet Initialization Parameters Not Bound to Address**
- **D:** Factory `createAccount` uses CREATE2 but salt doesn't incorporate all init params. Attacker deploys wallet they control to same address.
- **FP:** Salt derived from all init params. Factory reverts if account exists.

**174. Nonce Gap from Reverted Transactions (CREATE Address Mismatch)**
- **D:** Deployment script uses CREATE with pre-computed addresses. Reverted tx advances nonce, subsequent deployments at wrong addresses.
- **FP:** CREATE2 used. Script reads nonce from chain.

**175. Metamorphic Contract via CREATE2 + SELFDESTRUCT**
- **D:** CREATE2 deployment where deployer can `selfdestruct` and redeploy different bytecode at same address.
- **FP:** Post-Dencun: `selfdestruct` no longer destroys code unless same tx. `EXTCODEHASH` verified at execution.

**176. Immutable/Constructor Argument Misconfiguration**
- **D:** Constructor sets `immutable` values that can't change post-deploy. Multiple same-type `address` params where order swapped.
- **FP:** Deployment script reads back and asserts values. Constructor validates parameters.

**177. Missing Chain ID Validation in Deployment Configuration**
- **D:** Deploy script reads `$RPC_URL` without `eth_chainId` assertion.
- **FP:** `require(block.chainid == expectedChainId)` at script start.

**178. Hardcoded Network-Specific Addresses**
- **D:** Literal `address(0x...)` constants for external dependencies in constructors. Wrong contracts on different chains.
- **FP:** Per-chain config file. Script asserts `block.chainid`. Addresses from environment.

**179. Bytecode Verification Mismatch**
- **D:** Verified source doesn't match deployed bytecode. Different compiler settings, obfuscated constructor args, `--via-ir` vs legacy.
- **FP:** Deterministic build with pinned compiler. Sourcify full match. Constructor args published.

---

## Category: Account Abstraction (ERC-4337) [AA]

**180. validateUserOp Missing EntryPoint Caller Restriction**
- **D:** `validateUserOp` is `public`/`external` without `require(msg.sender == entryPoint)`.
- **FP:** `require(msg.sender == address(_entryPoint))` or `onlyEntryPoint` modifier.

**181. validateUserOp Signature Not Bound to nonce or chainId**
- **D:** `validateUserOp` reconstructs digest manually omitting `userOp.nonce` or `block.chainid`. Enables replay.
- **FP:** Digest from `entryPoint.getUserOpHash(userOp)`. Custom digest includes both.

**182. Banned Opcode in Validation Phase (Simulation-Execution Divergence)**
- **D:** `validateUserOp` references `block.timestamp`, `block.number`, `block.coinbase`, etc. Per ERC-7562, banned in validation.
- **FP:** Banned opcodes only in execution phase. Entity is staked under ERC-7562.

**183. Paymaster Gas Penalty Undercalculation**
- **D:** Paymaster prefund formula omits 10% EntryPoint penalty on unused execution gas.
- **FP:** Prefund explicitly adds unused-gas penalty.

**184. Paymaster ERC-20 Payment Deferred to postOp Without Pre-Validation**
- **D:** `validatePaymasterUserOp` doesn't transfer/lock tokens — payment deferred to `postOp`. User revokes allowance between validation and execution.
- **FP:** Tokens transferred/locked during `validatePaymasterUserOp`.

---

## Category: Miscellaneous [MISC]

**185. Selfdestruct Target Balance Inflation**
- **D:** `selfdestruct(target)` forces ETH into target even without `receive()`. If contract uses `address(this).balance` for accounting, inflated.
- **FP:** Internal accounting (not `address(this).balance`).

**186. Force-Feeding ETH via selfdestruct/Coinbase/CREATE2 Pre-Funding**
- **D:** Contract uses `address(this).balance` for accounting or gates logic on exact balance. Forced ETH breaks invariants.
- **FP:** Internal accounting only. Contract designed to accept arbitrary ETH.

**187. Unchecked Low-Level Call Return**
- **D:** `.call()` returns `(bool success, bytes memory data)`. If `success` not checked, failed call silently ignored.
- **FP:** `require(success)`. Return value checked. SafeTransferLib.

**188. ETH Stuck in Contract (No Withdrawal)**
- **D:** Contract receives ETH but has no function to withdraw it.
- **FP:** Explicit `sweep`/`rescue` function. ETH forwarded immediately.

**189. Insufficient Gas Forwarding / 63/64 Rule**
- **D:** External call without minimum gas budget. 63/64 rule leaves subcall with insufficient gas.
- **FP:** `require(gasleft() >= minGas)` before subcall. Return value + returndata both checked.

**190. Nested Mapping Inside Struct Not Cleared on `delete`**
- **D:** `delete myMapping[key]` on struct containing `mapping` or dynamic array. `delete` zeroes primitives but not nested mappings.
- **FP:** Nested mapping manually cleared. Key never reused after deletion.

**191. Array `delete` Leaves Zero-Value Gap**
- **D:** `delete array[index]` resets element to zero but does not shrink array. Iteration treats zeroed slot as valid entry.
- **FP:** Swap-and-pop pattern. Iteration skips zero entries. EnumerableSet used.

**192. Merkle Tree Second Preimage Attack**
- **D:** `MerkleProof.verify(proof, root, leaf)` where leaf derived from user input without double-hashing. 64-byte input passes as intermediate node.
- **FP:** Leaves double-hashed or type-prefixed. Input length enforced != 64 bytes.

**193. Merkle Proof Reuse — Leaf Not Bound to Caller**
- **D:** Leaf doesn't include `msg.sender`. Proof can be front-run from different address.
- **FP:** Leaf encodes `msg.sender`. Proof recorded as consumed.

**194. Weak On-Chain Randomness**
- **D:** Randomness from `block.prevrandao`, `blockhash`, `block.timestamp`, etc. Validator-influenceable.
- **FP:** Chainlink VRF v2+. Commit-reveal with future-block reveal.

**195. Duplicate Items in User-Supplied Array**
- **D:** Function accepts array without checking for duplicates. User passes same ID multiple times, claiming rewards repeatedly.
- **FP:** Duplicate check via mapping. Sorted-unique input enforced. State zeroed on first claim.

**196. Stale Cached ERC20 Balance from Direct Transfers**
- **D:** Contract tracks holdings in state variable updated only through protocol functions. Direct `token.transfer` inflates real balance beyond cached.
- **FP:** Accounting reads `balanceOf(this)` live. Cached value reconciled.

**197. Invariant/Cap Enforced on One Code Path But Not Another**
- **D:** Constraint (pool cap, max supply) enforced during normal operation but not during settlement, rewards, or emergency paths.
- **FP:** Invariant check in shared modifier. Post-condition assertion.

**198. Accrued Interest Omitted from Health Factor/LTV**
- **D:** Health factor computed from principal debt without accrued interest. Understates actual debt, delays liquidations.
- **FP:** `getDebt()` includes accrued interest. Interest accrual called before health check.

**199. NFT Staking Records msg.sender Instead of ownerOf**
- **D:** `depositor[tokenId] = msg.sender` without checking `nft.ownerOf(tokenId)`. Approved operator credited as depositor.
- **FP:** Reads `nft.ownerOf(tokenId)` before transfer. `require(ownerOf == msg.sender)`.

**200. Arbitrary External Call with User-Supplied Target and Calldata**
- **D:** `target.call{value: v}(data)` where target or data is caller-supplied. Attacker crafts calldata to invoke unintended functions on held assets.
- **FP:** Target restricted to allowlist. Calldata function selector restricted. No token approvals on calling contract.

---

## Usage Notes

This database covers the most common attack vectors. It is NOT exhaustive. Business logic vulnerabilities, protocol-specific issues, and novel attacks require creative thinking beyond pattern matching.

**Update this file** as new vectors are discovered in competitive audits or real-world exploits.

**Complement with:**
- `finding-validation` — FP gate and confidence scoring for confirmed vectors
- `calldata-attack-patterns` — deep dive on calldata-specific attacks
- Protocol-specific expert skills — for integration-level vulnerabilities
- `exploit-forensics` — for pattern recognition from real incidents
