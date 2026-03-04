---
name: smart-contract-fuzzing
description: Fuzz test smart contracts using Echidna, Medusa, and Foundry. Use when writing fuzz tests, property-based tests, invariant tests, or hunting for edge cases in Solidity/Vyper contracts. Covers stateful fuzzing, coverage-guided fuzzing, and corpus management.
---

# Smart Contract Fuzzing

Comprehensive fuzzing for EVM smart contracts using industry-standard tools.

## Tool Selection

| Tool | Best For | Speed | Parallelism |
|------|----------|-------|-------------|
| **Foundry** | Quick invariant tests, CI integration | Fast | Single |
| **Echidna** | Deep property testing, corpus collection | Medium | Single |
| **Medusa** | Large-scale campaigns, production audits | Fast | Multi-core |

**Rule of thumb**: Start with Foundry for quick iteration, graduate to Echidna/Medusa for thorough campaigns.

## Foundry Fuzzing

### Basic Fuzz Test
```solidity
// test/Token.t.sol
function testFuzz_transfer(address to, uint256 amount) public {
    vm.assume(to != address(0));
    vm.assume(amount <= token.balanceOf(address(this)));
    
    uint256 balBefore = token.balanceOf(to);
    token.transfer(to, amount);
    assertEq(token.balanceOf(to), balBefore + amount);
}
```

### Stateful Invariant Testing
```solidity
// test/invariants/Handler.sol
contract Handler is Test {
    Token token;
    uint256 public ghost_totalDeposits;
    
    function deposit(uint256 amount) public {
        amount = bound(amount, 0, 1e24);
        token.deposit(amount);
        ghost_totalDeposits += amount;
    }
}

// test/invariants/Invariant.t.sol
contract InvariantTest is Test {
    Handler handler;
    
    function setUp() public {
        handler = new Handler();
        targetContract(address(handler));
    }
    
    function invariant_solvency() public {
        assertGe(token.totalAssets(), handler.ghost_totalDeposits());
    }
}
```

### Configuration (foundry.toml)
```toml
[fuzz]
runs = 10000
max_test_rejects = 100000
seed = '0x1'
dictionary_weight = 40

[invariant]
runs = 256
depth = 128
fail_on_revert = false
shrink_run_limit = 5000
```

## Echidna

### Installation
```bash
# Via Docker (recommended)
docker pull trailofbits/echidna

# Via prebuilt binary
curl -LO https://github.com/crytic/echidna/releases/latest/download/echidna-x86_64-linux.tar.gz
tar -xzf echidna-x86_64-linux.tar.gz

# Via Nix
nix-env -i echidna
```

### Property Test Pattern
```solidity
// contracts/CryticTester.sol
contract CryticTester is MyContract {
    // Property: balance can never be negative (implicit by uint)
    // Property: total supply equals sum of balances
    function echidna_supply_invariant() public view returns (bool) {
        return totalSupply == balanceOf(address(this)) + balanceOf(msg.sender);
    }
    
    // Property with explicit failure
    function echidna_no_free_tokens() public returns (bool) {
        uint256 before = balanceOf(msg.sender);
        // If this returns false, Echidna found free tokens
        return balanceOf(msg.sender) <= before;
    }
}
```

### Assertion Mode
```solidity
function withdraw(uint256 amount) public {
    uint256 balBefore = balances[msg.sender];
    balances[msg.sender] -= amount;
    
    // Echidna catches assertion failures
    assert(balances[msg.sender] <= balBefore);
    
    payable(msg.sender).transfer(amount);
}
```

### Configuration (echidna.yaml)
```yaml
testMode: "assertion"  # or "property"
testLimit: 100000
seqLen: 100
shrinkLimit: 5000
coverage: true
corpusDir: "corpus"

# Contract deployment
deployContracts: [["0x...", "ContractName"]]
deployBytecodes: [["0x...", "0x..."]]

# Filtering
filterFunctions: ["excluded_*"]
filterBlacklist: true

# Advanced
workers: 1  # Echidna is single-threaded
```

### Running Echidna
```bash
# Basic run
echidna contracts/CryticTester.sol --contract CryticTester

# With config
echidna . --contract CryticTester --config echidna.yaml

# With Foundry project
echidna . --contract CryticTester --compile-mode foundry
```

## Medusa (Recommended for Production)

### Installation
```bash
# Via prebuilt binary
curl -LO https://github.com/crytic/medusa/releases/latest/download/medusa-linux-x64.tar.gz
tar -xzf medusa-linux-x64.tar.gz

# Build from source
go install github.com/crytic/medusa@latest
```

### Configuration (medusa.json)
```json
{
  "fuzzing": {
    "workers": 8,
    "workerResetLimit": 50,
    "timeout": 0,
    "testLimit": 0,
    "callSequenceLength": 100,
    "corpusDirectory": "corpus",
    "coverageEnabled": true,
    "deploymentOrder": ["Token", "Vault"],
    "targetContracts": ["VaultTest"],
    "predeployedContracts": {},
    "testing": {
      "propertyTesting": { "enabled": true },
      "assertionTesting": { "enabled": true },
      "optimizationTesting": { "enabled": false }
    }
  },
  "compilation": {
    "platform": "foundry",
    "platformConfig": {}
  }
}
```

### Running Medusa
```bash
# Initialize config
medusa init

# Run fuzzing
medusa fuzz

# Run with specific workers
medusa fuzz --workers 16
```

## Writing Effective Invariants

### Categories

1. **Accounting Invariants**
   ```solidity
   function echidna_accounting() public view returns (bool) {
       return totalDeposits == address(this).balance;
   }
   ```

2. **Authorization Invariants**
   ```solidity
   function echidna_only_owner_can_pause() public view returns (bool) {
       return !paused || lastPauser == owner;
   }
   ```

3. **State Machine Invariants**
   ```solidity
   function echidna_valid_state() public view returns (bool) {
       if (state == State.Finalized) return !canDeposit;
       if (state == State.Open) return canDeposit;
       return true;
   }
   ```

4. **Economic Invariants**
   ```solidity
   function echidna_no_profit_without_risk() public view returns (bool) {
       return userProfit[msg.sender] == 0 || userDeposit[msg.sender] > 0;
   }
   ```

## Ghost Variables Pattern

Track off-chain state to verify on-chain state:

```solidity
contract GhostTracker {
    // Ghost state (not in actual contract)
    uint256 public ghost_totalDeposited;
    mapping(address => uint256) public ghost_deposits;
    
    function deposit(uint256 amount) public {
        // Track ghost state
        ghost_totalDeposited += amount;
        ghost_deposits[msg.sender] += amount;
        
        // Call actual function
        vault.deposit(amount);
    }
    
    function echidna_ghost_matches_real() public view returns (bool) {
        return ghost_totalDeposited == vault.totalDeposited();
    }
}
```

## Coverage Analysis

After fuzzing, analyze coverage:

```bash
# Echidna coverage
echidna . --contract Test --format text --coverage

# View coverage file
cat corpus/covered.*.txt
```

Coverage markers:
- `*` - Line executed with STOP
- `r` - Line executed with REVERT  
- `o` - Line executed with out-of-gas
- `e` - Line executed with error

## CI Integration

### GitHub Actions (Foundry)
```yaml
- name: Run Fuzz Tests
  run: |
    forge test --match-test "testFuzz" -vvv
    forge test --match-test "invariant" -vvv
```

### GitHub Actions (Echidna)
```yaml
- name: Run Echidna
  uses: crytic/echidna-action@v2
  with:
    files: .
    contract: CryticTester
    config: echidna.yaml
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Fuzzer stuck on single path | Add more entry points, reduce `seqLen` |
| Too many reverts | Use `vm.assume()` or property filters |
| Coverage not increasing | Check constructor setup, add more state |
| Slow execution | Reduce `testLimit`, use Medusa workers |

## References

- [Building Secure Contracts](https://secure-contracts.com/) - Trail of Bits guide
- [Echidna Exercises](https://github.com/crytic/building-secure-contracts/tree/master/program-analysis/echidna)
- [Foundry Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)
