# Proxy Patterns: UUPS, Transparent, and Beacon

## Overview

Smart contract upgradeability on Ethereum requires proxy patterns because deployed contracts are immutable. The proxy pattern uses DELEGATECALL to execute logic from an implementation contract while maintaining state in the proxy.

**Key Concept**: Proxy holds the state, implementation holds the logic. Upgrades swap the implementation address while preserving state.

## Pattern Comparison Table

| Feature | Transparent Proxy | UUPS | Beacon Proxy |
|---------|------------------|------|--------------|
| **Upgrade logic location** | Proxy contract | Implementation | Beacon contract |
| **Gas cost** | Higher (routing check) | Lower | Medium |
| **Deployment cost** | Higher | Lower | Lowest (per proxy) |
| **Admin separation** | Required | Not required | Optional |
| **Upgrade risk** | Lower (can't break upgrade) | Higher (can remove upgrade) | Medium |
| **Multi-proxy upgrade** | One by one | One by one | All at once |
| **Best for** | High security needs | Gas efficiency | Many similar contracts |

## 1. UUPS (Universal Upgradeable Proxy Standard - ERC-1822)

### Architecture

```solidity
// Proxy Contract (minimal, deployed once)
contract UUPSProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = 
        bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
    
    fallback() external payable {
        address impl = _getImplementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    function _getImplementation() internal view returns (address) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        address impl;
        assembly { impl := sload(slot) }
        return impl;
    }
}

// Implementation Contract
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract MyContractV1 is UUPSUpgradeable {
    address public owner;
    uint256 public value;
    
    function initialize(address _owner) public initializer {
        owner = _owner;
    }
    
    // CRITICAL: This function MUST be protected
    function _authorizeUpgrade(address newImplementation) 
        internal 
        override 
        onlyOwner 
    {}
    
    function setValue(uint256 _value) external {
        value = _value;
    }
}
```

### Security Considerations

#### ✅ Advantages
- **Gas efficient**: No routing logic in proxy
- **Simpler proxy**: Less bytecode in proxy contract
- **Flexible authorization**: Custom upgrade logic per implementation

#### ⚠️ Vulnerabilities

**1. Missing `_authorizeUpgrade()` Protection**
```solidity
// VULNERABLE: No access control
function _authorizeUpgrade(address) internal override {}

// An attacker can call upgradeTo() and replace the implementation!
```

**Fix:**
```solidity
function _authorizeUpgrade(address) internal override onlyOwner {}
```

**2. Uninitialized Implementation**

The Wormhole hack (Feb 2022, $320M) exploited this:
```solidity
// Implementation deployed but not initialized
// Attacker calls initialize() on implementation directly
// Attacker becomes owner of implementation
// Attacker calls _authorizeUpgrade() and changes implementation
// Attacker self-destructs implementation
// All proxies now point to destroyed address!
```

**Fix:**
```solidity
constructor() {
    _disableInitializers(); // OpenZeppelin helper
}
```

**3. Upgrade Logic Removal**

If a new version doesn't inherit `UUPSUpgradeable`:
```solidity
// V2 doesn't inherit UUPSUpgradeable - NO UPGRADE FUNCTION!
contract MyContractV2 {
    // Contract is now permanently frozen
}
```

**Prevention**: Always inherit from UUPSUpgradeable or equivalent.

**4. Storage Layout Corruption**

Implementation can self-destruct via DELEGATECALL:
```solidity
contract Malicious {
    function destroy() external {
        selfdestruct(payable(msg.sender));
    }
}

// Attacker upgrades to malicious contract
// Calls destroy() via proxy (delegatecall)
// Implementation is destroyed
// Proxy is bricked
```

### OpenZeppelin UUPS Vulnerability (2021)

**Affected versions**: 4.1.0 - 4.3.2  
**Issue**: Implementation contracts could be left uninitialized  
**Impact**: Attacker could initialize, take ownership, and self-destruct  
**Fix**: Added `_disableInitializers()` in constructor

## 2. Transparent Proxy Pattern

### Architecture

```solidity
// Proxy Contract
contract TransparentUpgradeableProxy {
    bytes32 private constant ADMIN_SLOT = 
        bytes32(uint256(keccak256('eip1967.proxy.admin')) - 1);
    bytes32 private constant IMPLEMENTATION_SLOT = 
        bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
    
    modifier ifAdmin() {
        if (msg.sender == _getAdmin()) {
            _;
        } else {
            _fallback();
        }
    }
    
    function upgradeTo(address newImplementation) external ifAdmin {
        _setImplementation(newImplementation);
    }
    
    function changeAdmin(address newAdmin) external ifAdmin {
        _setAdmin(newAdmin);
    }
    
    fallback() external payable {
        require(msg.sender != _getAdmin(), "Admin cannot call");
        _delegate(_getImplementation());
    }
}

// ProxyAdmin (separate contract)
contract ProxyAdmin {
    address public owner;
    
    function upgrade(TransparentUpgradeableProxy proxy, address impl) 
        external 
        onlyOwner 
    {
        proxy.upgradeTo(impl);
    }
}

// Implementation
contract MyContract {
    uint256 public value;
    
    function initialize() public {
        // initialization logic
    }
    
    function setValue(uint256 _value) external {
        value = _value;
    }
}
```

### Security Considerations

#### ✅ Advantages
- **Admin separation**: Admin can't accidentally call implementation functions
- **Upgrade safety**: Upgrade logic cannot be removed from implementation
- **Battle-tested**: Most audited and used pattern

#### ⚠️ Vulnerabilities

**1. Function Selector Collision**

If proxy and implementation have same function signature:
```solidity
// Proxy has: upgradeTo(address)
// Implementation has: upgradeTo(address) 

// Users calling upgradeTo() might hit proxy logic unexpectedly
```

**Prevention**: Transparent proxy pattern specifically prevents admin from calling implementation functions.

**2. ProxyAdmin Not Secured**

```solidity
// VULNERABLE: ProxyAdmin controlled by single EOA
ProxyAdmin admin = new ProxyAdmin();
admin.transferOwnership(singleEOA);

// Better: ProxyAdmin controlled by multi-sig
admin.transferOwnership(multiSigAddress);
```

**3. No Timelock on Upgrades**

Admin can instantly upgrade to malicious implementation:
```solidity
// RISKY: Immediate upgrade
proxyAdmin.upgrade(proxy, maliciousImpl);

// BETTER: Upgrades go through timelock
timelock.schedule(
    address(proxyAdmin),
    0,
    abi.encodeWithSelector(ProxyAdmin.upgrade.selector, proxy, newImpl),
    bytes32(0),
    bytes32(0),
    2 days // delay
);
```

**4. Gas Overhead**

Every call includes admin check:
```solidity
if (msg.sender == admin) {
    // Handle admin functions
} else {
    // Delegate to implementation
}
```

**Cost**: ~2,700 extra gas per transaction

## 3. Beacon Proxy Pattern

### Architecture

```solidity
// UpgradeableBeacon (single beacon for many proxies)
contract UpgradeableBeacon {
    address private _implementation;
    address public owner;
    
    event Upgraded(address indexed implementation);
    
    constructor(address implementation_) {
        _setImplementation(implementation_);
        owner = msg.sender;
    }
    
    function implementation() public view returns (address) {
        return _implementation;
    }
    
    function upgradeTo(address newImplementation) public {
        require(msg.sender == owner, "Not owner");
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Not a contract");
        _implementation = newImplementation;
    }
}

// BeaconProxy (many instances, all point to same beacon)
contract BeaconProxy {
    address private immutable _beacon;
    
    constructor(address beacon, bytes memory data) {
        _beacon = beacon;
        if (data.length > 0) {
            (bool success,) = IBeacon(beacon).implementation()
                .delegatecall(data);
            require(success);
        }
    }
    
    function _getImplementation() internal view returns (address) {
        return IBeacon(_beacon).implementation();
    }
    
    fallback() external payable {
        _delegate(_getImplementation());
    }
}

// Implementation (normal contract)
contract MyContract {
    uint256 public value;
    
    function initialize(uint256 _value) external {
        value = _value;
    }
}
```

### Use Case Example

```solidity
// Deploy one implementation
MyContract impl = new MyContract();

// Deploy one beacon
UpgradeableBeacon beacon = new UpgradeableBeacon(address(impl));

// Deploy many proxies pointing to same beacon
BeaconProxy proxy1 = new BeaconProxy(
    address(beacon), 
    abi.encodeCall(MyContract.initialize, (100))
);
BeaconProxy proxy2 = new BeaconProxy(
    address(beacon), 
    abi.encodeCall(MyContract.initialize, (200))
);
// ... deploy 100 more proxies ...

// Later: upgrade ALL proxies at once by updating beacon
beacon.upgradeTo(address(newImplementation));
// All 102 proxies now use new implementation!
```

### Security Considerations

#### ✅ Advantages
- **Mass upgrades**: Update many proxies with single transaction
- **Gas efficient**: Very cheap to deploy additional proxies
- **Clear separation**: Beacon handles upgrade, proxies just reference it

#### ⚠️ Vulnerabilities

**1. Beacon Not Secured**

```solidity
// VULNERABLE: Single EOA controls beacon
beacon.transferOwnership(singleEOA);

// BETTER: Multi-sig or DAO controls beacon
beacon.transferOwnership(multiSigAddress);
```

**2. Catastrophic Upgrade**

One bad upgrade affects ALL proxies:
```solidity
// If this upgrade is buggy, ALL proxies are broken
beacon.upgradeTo(buggyImplementation);

// Solution: Thorough testing and gradual rollout
// Deploy new beacon for subset of proxies first
```

**3. Beacon Initialization**

```solidity
// VULNERABLE: Beacon deployed with zero address
UpgradeableBeacon beacon = new UpgradeableBeacon(address(0));

// All proxies will fail
// Fix: Validate in constructor
require(implementation_ != address(0));
require(implementation_.code.length > 0);
```

**4. Immutable Beacon Address**

```solidity
// Beacon address is immutable in proxy
address private immutable _beacon;

// If beacon is compromised, proxies can't switch to new beacon
// Solution: Use upgradeable beacon reference or create new proxies
```

## Storage Layout Rules (All Patterns)

### The Golden Rules

1. **Never reorder variables**
```solidity
// V1
contract MyContractV1 {
    uint256 public a;  // slot 0
    uint256 public b;  // slot 1
}

// V2 - WRONG ❌
contract MyContractV2 {
    uint256 public b;  // slot 0 (was slot 1!)
    uint256 public a;  // slot 1 (was slot 0!)
}

// V2 - CORRECT ✅
contract MyContractV2 {
    uint256 public a;  // slot 0
    uint256 public b;  // slot 1
    uint256 public c;  // slot 2 (new)
}
```

2. **Never change variable types**
```solidity
// V1
uint256 public value;

// V2 - WRONG ❌
address public value; // Different type!

// V2 - CORRECT ✅
uint256 public value; // Same type
```

3. **Use storage gaps**
```solidity
contract BaseV1 {
    uint256 public value;
    uint256[49] private __gap; // Reserve 49 slots
}

// V2: Can use gap slots
contract BaseV2 {
    uint256 public value;
    uint256 public newValue; // Uses first gap slot
    uint256[48] private __gap; // Reduced by 1
}
```

4. **Maintain inheritance order**
```solidity
// V1
contract MyContract is A, B, C {}

// V2 - WRONG ❌
contract MyContract is A, C, B {} // Different order!

// V2 - CORRECT ✅
contract MyContract is A, B, C, D {} // Same order, added D
```

## ERC-7201: Namespaced Storage

Modern approach to avoid collisions:

```solidity
contract MyContract {
    // @custom:storage-location erc7201:example.MyContract
    struct MyStorage {
        uint256 value;
        mapping(address => uint256) balances;
    }
    
    // keccak256(abi.encode(uint256(keccak256("example.MyContract")) - 1)) 
    // & ~bytes32(uint256(0xff))
    bytes32 private constant MyStorageLocation = 
        0x1234...abcd;
    
    function _getMyStorage() private pure returns (MyStorage storage $) {
        assembly {
            $.slot := MyStorageLocation
        }
    }
    
    function setValue(uint256 _value) external {
        MyStorage storage $ = _getMyStorage();
        $.value = _value;
    }
}
```

**Benefits:**
- No storage collision risk
- Can safely add new storage structs
- Clear namespace separation

## Function Selector Collision Detection

```bash
# Using Slither
slither-check-upgradeability OldContract.sol NewContract.sol Proxy

# Using Foundry
forge inspect MyContract methods

# Manual check
cast sig "functionName(uint256,address)"
# Returns: 0x12345678

# Check both contracts and proxy for collisions
```

## Testing Upgrades

```solidity
// Foundry test
function testUpgrade() public {
    // Deploy V1
    MyContractV1 implV1 = new MyContractV1();
    ERC1967Proxy proxy = new ERC1967Proxy(
        address(implV1),
        abi.encodeCall(MyContractV1.initialize, (100))
    );
    MyContractV1 v1 = MyContractV1(address(proxy));
    
    // Record state
    uint256 valueBefore = v1.value();
    
    // Deploy and upgrade to V2
    MyContractV2 implV2 = new MyContractV2();
    v1.upgradeTo(address(implV2));
    MyContractV2 v2 = MyContractV2(address(proxy));
    
    // Verify state preserved
    assertEq(v2.value(), valueBefore);
    
    // Test new functionality
    v2.newFunction();
}
```

## Recommended Pattern Selection

| Scenario | Recommended Pattern |
|----------|-------------------|
| Maximum security, cost not an issue | Transparent Proxy |
| Gas optimization priority | UUPS |
| Many similar contracts (e.g., NFT collections) | Beacon |
| High-value DeFi protocol | Transparent + Timelock |
| DAO-controlled system | UUPS + Governance |
| Wallet infrastructure | Beacon (mass upgrade capability) |

## Resources

- [OpenZeppelin Proxy Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [EIP-1822: UUPS](https://eips.ethereum.org/EIPS/eip-1822)
- [ERC-7201: Namespaced Storage](https://eips.ethereum.org/EIPS/eip-7201)
- [RareSkills: UUPS Deep Dive](https://rareskills.io/post/uups-proxy)
- [RareSkills: Beacon Proxy](https://rareskills.io/post/beacon-proxy)
