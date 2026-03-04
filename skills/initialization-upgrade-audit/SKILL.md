# Initialization & Upgrade Audit

Detect vulnerabilities in proxy patterns, initialization, and upgrade mechanisms — uninitialized proxies, storage collisions, and upgrade safety.

**Database:** 605 findings (42 critical/high) from ~/clawd/audit-db

## Audit Checklist
1. Verify `initializer` modifier is used on all initialization functions
2. Check that `_disableInitializers()` is called in implementation constructors
3. Look for uninitialized proxy deployments that can be front-run
4. Verify storage layout compatibility between implementation versions
5. Check for storage gaps in base contracts (`uint256[50] private __gap`)
6. Verify no storage slot collisions between proxy and implementation
7. Check UUPS `_authorizeUpgrade` has proper access control
8. Verify `delegatecall` targets cannot be set to arbitrary addresses
9. Check constructor vs initializer confusion in upgradeable contracts
10. Look for immutable variables in upgradeable contracts (not stored in storage)
11. Verify upgrade path cannot brick the contract (e.g., removing upgrade function)

## Common Vulnerable Patterns
- `initialize()` without `initializer` modifier → re-initialization possible
- No `_disableInitializers()` in constructor → implementation can be initialized directly
- Missing `__gap` in inherited upgradeable contract → storage collision on upgrade
- `selfdestruct` in implementation → proxy bricked (pre-Dencun)
- EIP-1967 admin slot readable → implementation address leaked

## Real-World Examples (from audit database)
- **[CRIT]** Missing range check in constructors
  - Source: Zellic: 2024-07-barretenberg-bigfield
- **[CRIT]** Missing consistency check for prime limb in constructor
  - Source: Zellic: 2024-07-barretenberg-bigfield
- **[HIGH]** Anyone can create tokens before initialization
  - Source: Zellic: 2024-05-awaken-swap
- **[HIGH]** The AssertContractInitialized function should check Initialized
  - Source: Zellic: 2024-05-awaken-swap
- **[HIGH]** Clone construction leaves constants uninitialized
  - Source: Zellic: 2024-04-lido-fixed-income
- **[HIGH]** The feesUpdatedAt state variable is used before initialization
  - Source: Zellic: 2025-06-concrete
- **[CRIT]** Uninitialized stake account can be stolen
  - Source: Zellic: 2025-01-pye
- **[HIGH]** Speciﬁcation-Code mismatch for AssetProxyOwner timelock period
  - Source: trail-of-bits-0x-protocol
- **[HIGH]** Non-reinitialization of daily pledges will block the tally
  - Source: ToB: 0000-basis
- **[HIGH]** ShareToken whitelist cannot be initialized
  - Source: ToB: 0000-basis
- **[CRIT]** Proxy-Based self-liquidation creates bad debt for lenders
  - Source: Cyfrin: 2025-09-licredity-v20
- **[HIGH]** maxStrategistFee is incorrectly set in AstariaRouter's constructor
  - Source: Spearbit: 0000-astaria-july
