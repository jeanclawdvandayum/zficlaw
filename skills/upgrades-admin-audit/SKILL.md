---
name: upgrades-admin-audit
description: "Comprehensive security audit checklist for upgradeable smart contracts, proxy patterns, admin controls, and governance systems."
metadata:
  tags: "security, audit, upgradeable, proxy, governance, admin, UUPS, transparent-proxy"
---

# Upgradeable Contracts & Admin Security Audit

## When to Use This Skill

Use this auditing framework when reviewing:
- **Upgradeable contracts** using any proxy pattern (UUPS, Transparent, Beacon)
- **Admin-controlled systems** with privileged roles or governance mechanisms
- **Governance tokens and voting systems** vulnerable to manipulation
- **Timelock contracts** controlling protocol parameter changes
- **Emergency pause/unpause mechanisms** in critical contracts
- **Bridge contracts** and cross-chain protocols with upgrade capabilities
- **Multi-signature wallets** controlling protocol ownership

## Quick Audit Checklist

### 🔍 Proxy Pattern Security

#### UUPS (Universal Upgradeable Proxy Standard)
- [ ] **Authorization check**: `_authorizeUpgrade()` function is implemented and protected
- [ ] **Implementation initialization**: Implementation contract is initialized or constructor disabled
- [ ] **Upgrade function exists**: Logic contract has upgrade capability (not accidentally removed)
- [ ] **Storage layout safety**: New versions maintain compatible storage layout
- [ ] **Function selector collision**: No overlap between proxy and implementation functions
- [ ] **Self-destruct protection**: Implementation cannot be destroyed via DELEGATECALL

#### Transparent Proxy
- [ ] **Admin separation**: Admin cannot call implementation functions directly
- [ ] **Admin address security**: ProxyAdmin contract properly secured and multi-sig controlled
- [ ] **Function clashing**: No function selector collisions between admin and implementation
- [ ] **Upgrade timelock**: Admin upgrades have reasonable delay for community review
- [ ] **Implementation validation**: New implementation is tested and audited before upgrade

#### Beacon Proxy
- [ ] **Beacon upgrade authorization**: Only authorized accounts can upgrade beacon
- [ ] **Multiple proxy coordination**: Mass upgrade implications are understood
- [ ] **Beacon initialization**: Beacon properly initialized and cannot be hijacked
- [ ] **Individual proxy state**: Each proxy's state is independent and safe
- [ ] **Upgrade testing**: New implementation tested with all existing proxy states

### 🏗️ Storage Layout Verification

- [ ] **Storage slot gaps**: `__gap` variables properly maintain upgrade space
- [ ] **No variable reordering**: New state variables only appended, never inserted
- [ ] **Type consistency**: Variable types unchanged across upgrades
- [ ] **Inheritance order**: Contract inheritance hierarchy unchanged
- [ ] **Slot collision detection**: Run storage layout comparison tools (OpenZeppelin Upgrades plugin)
- [ ] **ERC-7201 namespaced storage**: Consider using namespaced storage for isolation

### 🔐 Initialization Security

- [ ] **Initializer protection**: `initializer` modifier used on initialization functions
- [ ] **Constructor disabled**: Implementation contract constructor is disabled or empty
- [ ] **Initialization race**: No window where attacker can initialize before legitimate owner
- [ ] **Implementation initialized**: Implementation contract itself is initialized (defense in depth)
- [ ] **Reentrancy protection**: Initialization cannot be re-entered or repeated
- [ ] **Parameter validation**: All initialization parameters are validated

### 👑 Admin Control Security

- [ ] **Multi-sig wallet**: Admin operations require multiple signatures (3-of-5 minimum)
- [ ] **Key distribution**: Signers are geographically and organizationally distributed
- [ ] **Hardware wallets**: Admin keys stored in hardware wallets or secure HSMs
- [ ] **Role separation**: Different roles for different privilege levels (RBAC)
- [ ] **Privilege minimization**: Contracts have only necessary privileges
- [ ] **Admin transfer**: Ownership transfers have two-step pattern (propose + accept)
- [ ] **Emergency procedures**: Clear incident response plan for compromised keys

### ⏱️ Timelock Security

- [ ] **Minimum delay**: Timelock delay is reasonable (24-48 hours minimum for critical operations)
- [ ] **Community monitoring**: Sufficient time for community to review queued transactions
- [ ] **Cancellation mechanism**: Trusted party can cancel malicious queued proposals
- [ ] **Grace period**: Expired transactions have limited execution window
- [ ] **Parameter bounds**: Timelock-controlled parameters have safe min/max limits
- [ ] **Emergency override**: Emergency actions bypass timelock with strict conditions
- [ ] **Queue transparency**: All queued transactions are easily discoverable on-chain

### 🗳️ Governance Security

- [ ] **Flash loan resistance**: Voting uses snapshot-based or time-weighted balances
- [ ] **Quorum requirements**: Minimum participation threshold prevents low-turnout attacks
- [ ] **Vote delegation safety**: Delegation cannot be weaponized for attacks
- [ ] **Proposal validation**: Proposals are validated before execution
- [ ] **Execution delay**: Passed proposals have timelock before execution
- [ ] **Vote buying protection**: Mechanisms prevent or detect vote buying
- [ ] **Governance token distribution**: No single entity controls >50% of tokens
- [ ] **Proposal threshold**: Minimum token balance required to submit proposals

### ⚠️ Emergency Controls

- [ ] **Pause authorization**: Only specific addresses can pause (ideally multi-sig)
- [ ] **Pause scope**: Pausing is granular (specific functions, not entire contract)
- [ ] **Auto-unpause**: Consider time-based automatic unpause to prevent permanent freezing
- [ ] **Pause notification**: Events emitted for transparency
- [ ] **Unpause process**: Clear governance process for unpausing
- [ ] **Pause abuse prevention**: Limits on how often pause can be triggered
- [ ] **Emergency withdrawals**: Users can withdraw funds even when paused (if appropriate)

### 🔄 Upgrade Process

- [ ] **Upgrade testing**: New implementation thoroughly tested on testnet
- [ ] **Security audit**: Independent audit of new implementation
- [ ] **Community notification**: Advance notice given before upgrade
- [ ] **Rollback plan**: Documented procedure for reverting if issues arise
- [ ] **Storage validation**: Storage layout compatibility verified with tools
- [ ] **Integration testing**: Tested with actual proxy and existing state
- [ ] **Documentation**: Upgrade reasoning and changes clearly documented

## Storage Layout Verification Steps

### Using OpenZeppelin Upgrades Plugin

```bash
# Install the plugin
npm install --save-dev @openzeppelin/hardhat-upgrades

# Validate upgrade compatibility
npx hardhat run scripts/validate-upgrade.js

# Generate storage layout report
npx hardhat storage-layout --contract MyContract
```

### Manual Verification

```solidity
// Old version
contract MyContractV1 {
    uint256 public value1;        // slot 0
    address public owner;         // slot 1
    mapping(address => uint256) public balances; // slot 2
    uint256[47] private __gap;    // slots 3-49 (reserved for future)
}

// New version - CORRECT ✓
contract MyContractV2 {
    uint256 public value1;        // slot 0 (unchanged)
    address public owner;         // slot 1 (unchanged)
    mapping(address => uint256) public balances; // slot 2 (unchanged)
    uint256[47] private __gap;    // slots 3-49 (maintained)
    uint256 public value2;        // slot 50 (new variable)
}

// New version - WRONG ✗
contract MyContractV2Wrong {
    uint256 public value2;        // slot 0 (BREAKS EVERYTHING!)
    uint256 public value1;        // slot 1 (was 0)
    address public owner;         // slot 2 (was 1)
    mapping(address => uint256) public balances; // slot 3 (was 2)
}
```

## Common Attack Patterns

### 1. Uninitialized Implementation Takeover
**Vulnerability**: Implementation contract left uninitialized  
**Attack**: Attacker calls `initialize()` on implementation, gains control  
**Impact**: Implementation can be self-destructed, bricking all proxies  
**Prevention**: Initialize implementation in constructor or immediately after deployment

### 2. Storage Collision
**Vulnerability**: Storage layout changes between upgrades  
**Attack**: New variables overwrite critical data (e.g., owner address)  
**Impact**: Complete loss of control, fund theft  
**Prevention**: Always append new variables, use storage layout tools

### 3. Function Selector Collision
**Vulnerability**: Proxy and implementation have same function signature  
**Attack**: Call intended for implementation is intercepted by proxy  
**Impact**: Bypass access controls, unexpected behavior  
**Prevention**: Check for collisions using automated tools

### 4. Flash Loan Governance Attack
**Vulnerability**: Governance uses current balance for voting power  
**Attack**: Flash loan massive tokens, vote, return tokens in single transaction  
**Impact**: Pass malicious proposals, drain treasury  
**Prevention**: Snapshot-based voting, vote delegation delays

### 5. Timelock Bypass
**Vulnerability**: Incomplete timelock coverage or short delays  
**Attack**: Execute critical changes before community can react  
**Impact**: Parameter manipulation, unauthorized upgrades  
**Prevention**: Comprehensive timelock coverage, adequate delays (24-48h)

### 6. Admin Key Compromise
**Vulnerability**: Single EOA controls upgrade or admin functions  
**Attack**: Phishing, private key theft, or social engineering  
**Impact**: Malicious upgrade, fund theft, complete protocol takeover  
**Prevention**: Multi-sig wallets, hardware security, key distribution

### 7. Initialization Race Condition
**Vulnerability**: Window between deployment and initialization  
**Attack**: Bot monitors mempool, front-runs initialization  
**Impact**: Attacker becomes owner of proxy  
**Prevention**: Initialize in same transaction or use factory pattern

### 8. Emergency Pause Abuse
**Vulnerability**: Centralized pause control without accountability  
**Attack**: Admin pauses contract to prevent withdrawals or manipulate state  
**Impact**: Funds locked indefinitely, censorship  
**Prevention**: Multi-sig pause, time-limited pauses, user withdrawal exemptions

## Testing Recommendations

### Upgrade Safety Tests
```solidity
// Test storage layout preservation
function testStorageLayoutPreserved() public {
    // Deploy V1
    MyContractV1 v1 = new MyContractV1();
    v1.initialize(owner, 100);
    
    // Record state
    uint256 oldValue = v1.value1();
    address oldOwner = v1.owner();
    
    // Upgrade to V2
    MyContractV2 v2 = MyContractV2(address(v1));
    upgradeProxy(address(v1), address(new MyContractV2()));
    
    // Verify state preserved
    assertEq(v2.value1(), oldValue);
    assertEq(v2.owner(), oldOwner);
}

// Test unauthorized upgrade prevention
function testUnauthorizedUpgradeFails() public {
    vm.prank(attacker);
    vm.expectRevert("Unauthorized");
    proxy.upgradeTo(maliciousImplementation);
}

// Test initialization protection
function testCannotReinitialize() public {
    proxy.initialize(owner);
    vm.expectRevert("Already initialized");
    proxy.initialize(attacker);
}
```

### Governance Attack Simulation
```solidity
// Test flash loan resistance
function testFlashLoanVotingPrevented() public {
    // Attempt flash loan attack
    uint256 loanAmount = 1_000_000e18;
    flashLoan(governanceToken, loanAmount);
    
    // Try to vote (should fail or use old snapshot)
    vm.expectRevert("Insufficient voting power");
    governance.vote(proposalId, true);
}
```

## Tools & Resources

### Analysis Tools
- **Slither**: Static analysis for upgradeable contracts
- **OpenZeppelin Upgrades Plugin**: Storage layout validation
- **Foundry**: Upgrade testing and fuzzing
- **Mythril**: Symbolic execution for proxies
- **Panoramix**: Decompiler for analyzing implementation contracts

### Key Commands
```bash
# Slither upgrade safety check
slither-check-upgradeability Contract.sol ContractV2 Proxy

# OpenZeppelin storage layout
npx hardhat storage-layout

# Foundry storage inspection
forge inspect MyContract storage-layout --pretty
```

## References

- [Proxy Patterns Deep Dive](./references/proxy-patterns.md) - UUPS, Transparent, and Beacon patterns
- [Governance Attack Vectors](./references/governance-attacks.md) - Flash loans, timelock bypass, vote manipulation
- [Real Exploit Case Studies](./references/real-exploits.md) - Wormhole, Nomad, Parity, and others

## Red Flags 🚩

Watch out for these critical warning signs:
- ❌ Single EOA controls upgrades or admin functions
- ❌ No timelock on critical parameter changes
- ❌ Implementation contract not initialized
- ❌ Missing `_authorizeUpgrade()` protection in UUPS
- ❌ Storage variables reordered between versions
- ❌ Governance voting uses current balances (flash loan vulnerable)
- ❌ No security audit for new implementation
- ❌ Pause function controlled by single address
- ❌ Very short or no delay on timelock (< 24 hours)
- ❌ No multi-sig on admin operations
- ❌ Missing storage gaps for future upgrades
- ❌ Constructor used in implementation contract
- ❌ No events emitted for critical admin actions

## Best Practices Summary

1. **Always use multi-sig wallets** for admin operations (minimum 3-of-5)
2. **Initialize implementations** immediately after deployment
3. **Use storage gaps** (`__gap`) in base contracts for future variables
4. **Implement timelocks** (24-48h) for all critical changes
5. **Snapshot-based voting** to prevent flash loan attacks
6. **Automated testing** for storage layout compatibility
7. **Independent audits** before any upgrade
8. **Transparent communication** with community about upgrades
9. **Emergency plans** for key compromise scenarios
10. **Principle of least privilege** for all roles

---

**Note**: This skill is based on real exploits and current best practices as of January 2025. Always consult with security professionals for production systems and stay updated on emerging attack vectors.
