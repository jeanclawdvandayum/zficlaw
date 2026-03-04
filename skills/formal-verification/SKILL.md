---
name: formal-verification
description: Formally verify smart contracts using Certora, Halmos, and Solidity SMTChecker. Use when proving mathematical properties about contracts, verifying protocol invariants, or performing symbolic execution. Covers CVL specs, symbolic testing, and SMT-based verification.
---

# Formal Verification for Smart Contracts

Prove mathematical correctness of EVM contracts using symbolic analysis.

## Tool Selection

| Tool | Type | Difficulty | Best For |
|------|------|------------|----------|
| **Halmos** | Symbolic Testing | Easy | Foundry users, quick proofs |
| **SMTChecker** | Built-in Solidity | Easy | Simple assertions, CI |
| **Certora** | Industrial Prover | Hard | Production protocols, full specs |

**Recommendation**: Start with Halmos (familiar Foundry syntax), use Certora for high-stakes protocols.

## Halmos (Symbolic Testing)

### Installation
```bash
# Recommended (uv)
uv tool install --python 3.12 halmos

# Docker
docker pull ghcr.io/a16z/halmos:latest

# Pip
pip install halmos
```

### Basic Symbolic Test
```solidity
// test/Token.t.sol
function check_transfer_preserves_supply(address to, uint256 amount) public {
    // Symbolic inputs - Halmos explores ALL possible values
    uint256 supplyBefore = token.totalSupply();
    
    token.transfer(to, amount);
    
    // This must hold for ALL inputs, not just random samples
    assert(token.totalSupply() == supplyBefore);
}
```

### Key Differences from Fuzzing

```solidity
// FUZZING: Tests random samples
function testFuzz_transfer(uint256 amount) public {
    // Tests ~10,000 random amounts
}

// SYMBOLIC: Proves for ALL values
function check_transfer(uint256 amount) public {
    // Proves for 2^256 possible amounts
}
```

### Running Halmos
```bash
# Basic run
halmos

# With specific test
halmos --function check_transfer

# With loop unrolling
halmos --loop 10

# With timeout
halmos --solver-timeout-assertion 60000
```

### Configuration
```bash
# In foundry.toml or via CLI
halmos --solver-timeout-branching 10000 \
       --solver-timeout-assertion 60000 \
       --loop 5 \
       --width 1024 \
       --depth 100
```

### Symbolic Test Patterns

#### 1. Round-Trip Property
```solidity
function check_deposit_withdraw_roundtrip(uint256 amount) public {
    vm.assume(amount > 0 && amount <= 1e24);
    
    uint256 sharesBefore = vault.balanceOf(address(this));
    uint256 shares = vault.deposit(amount);
    uint256 withdrawn = vault.redeem(shares);
    
    // Should get back at least what we put in (minus dust)
    assert(withdrawn >= amount - 1);
}
```

#### 2. No Profit Without Deposit
```solidity
function check_no_free_money(uint256 withdrawAmount) public {
    uint256 balBefore = token.balanceOf(address(this));
    
    // Fresh user with no deposits
    vm.prank(address(0xdead));
    
    try vault.withdraw(withdrawAmount) {
        // If withdraw succeeds, balance shouldn't increase
        assert(token.balanceOf(address(0xdead)) == 0);
    } catch {}
}
```

#### 3. State Transition Validity
```solidity
function check_state_machine(uint8 action) public {
    State before = contract.state();
    
    if (action == 0) contract.deposit(1e18);
    else if (action == 1) contract.withdraw(1e18);
    else contract.finalize();
    
    State after = contract.state();
    
    // Valid transitions only
    assert(isValidTransition(before, after));
}
```

## Solidity SMTChecker

### Enable in Compiler
```json
// foundry.toml
[profile.default]
via_ir = true

[profile.default.model_checker]
engine = "chc"
targets = ["assert", "underflow", "overflow"]
timeout = 10000
```

### Inline Assertions
```solidity
contract Token {
    function transfer(address to, uint256 amount) public {
        require(balances[msg.sender] >= amount, "Insufficient");
        
        uint256 senderBefore = balances[msg.sender];
        uint256 recipientBefore = balances[to];
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        
        // SMTChecker verifies these at compile time
        assert(balances[msg.sender] == senderBefore - amount);
        assert(balances[to] == recipientBefore + amount);
    }
}
```

### Running SMTChecker
```bash
# Via Foundry
forge build --via-ir

# Via solc directly
solc --model-checker-engine chc \
     --model-checker-targets assert,underflow \
     --model-checker-timeout 10000 \
     Contract.sol
```

## Certora (Industrial Strength)

### Installation
```bash
# Install Certora CLI
pip install certora-cli

# Get API key from certora.com and export
export CERTORAKEY="your-api-key"
```

### Project Structure
```
project/
├── contracts/
│   └── Token.sol
├── certora/
│   ├── specs/
│   │   └── Token.spec
│   └── conf/
│       └── Token.conf
```

### Basic CVL Spec
```cvl
// certora/specs/Token.spec

methods {
    function totalSupply() external returns (uint256) envfree;
    function balanceOf(address) external returns (uint256) envfree;
    function transfer(address, uint256) external returns (bool);
}

// Ghost variable to track sum of all balances
ghost mathint sumBalances {
    init_state axiom sumBalances == 0;
}

// Hook to update ghost on balance changes
hook Sstore balances[KEY address a] uint256 newVal (uint256 oldVal) {
    sumBalances = sumBalances + newVal - oldVal;
}

// INVARIANT: Total supply equals sum of balances
invariant totalSupplyIsSumOfBalances()
    to_mathint(totalSupply()) == sumBalances;

// RULE: Transfer preserves total supply
rule transferPreservesSupply(address to, uint256 amount) {
    env e;
    
    mathint supplyBefore = totalSupply();
    
    transfer(e, to, amount);
    
    mathint supplyAfter = totalSupply();
    
    assert supplyAfter == supplyBefore;
}

// RULE: Transfer moves exact amount
rule transferMovesExactAmount(address to, uint256 amount) {
    env e;
    require e.msg.sender != to;  // Exclude self-transfer
    
    mathint senderBefore = balanceOf(e.msg.sender);
    mathint recipientBefore = balanceOf(to);
    
    transfer(e, to, amount);
    
    mathint senderAfter = balanceOf(e.msg.sender);
    mathint recipientAfter = balanceOf(to);
    
    assert senderAfter == senderBefore - amount;
    assert recipientAfter == recipientBefore + amount;
}
```

### Configuration (Token.conf)
```json
{
    "files": ["contracts/Token.sol"],
    "verify": "Token:certora/specs/Token.spec",
    "msg": "Token verification",
    "rule_sanity": "basic",
    "optimistic_loop": true,
    "loop_iter": 3,
    "solc": "solc8.20"
}
```

### Running Certora
```bash
# Run verification
certoraRun certora/conf/Token.conf

# With specific rule
certoraRun certora/conf/Token.conf --rule transferPreservesSupply

# With sanity checks
certoraRun certora/conf/Token.conf --rule_sanity basic
```

### CVL Patterns

#### 1. Parametric Rules (For All Functions)
```cvl
rule noBalanceIncreaseWithoutTransfer(method f) {
    env e;
    address user;
    require user != currentContract;
    
    mathint balBefore = balanceOf(user);
    
    calldataarg args;
    f(e, args);
    
    mathint balAfter = balanceOf(user);
    
    assert balAfter <= balBefore || 
           f.selector == sig:transfer(address,uint256).selector;
}
```

#### 2. Invariants with Preserved Blocks
```cvl
invariant solvency()
    totalAssets() >= totalDebt()
    {
        preserved deposit(uint256 amount) with (env e) {
            require amount <= MAX_DEPOSIT;
        }
    }
```

#### 3. Ghosts for Complex State
```cvl
ghost mapping(address => bool) hasDeposited;

hook Sstore deposits[KEY address a] uint256 newVal (uint256 oldVal) {
    if (newVal > 0) {
        hasDeposited[a] = true;
    }
}

rule onlyDepositorsCanWithdraw() {
    env e;
    uint256 amount;
    
    require !hasDeposited[e.msg.sender];
    
    withdraw@withrevert(e, amount);
    
    assert lastReverted;
}
```

## Verification Strategy

### 1. Define Properties
```
- Accounting: totalSupply == Σ balances
- Authorization: only owner can pause
- Reentrancy: no state changes after external calls
- Economic: no profit without risk
```

### 2. Choose Tool by Property Type

| Property Type | Best Tool |
|---------------|-----------|
| Simple assertions | SMTChecker |
| Reachability | Halmos |
| Complex invariants | Certora |
| Cross-contract | Certora |

### 3. Iterative Refinement
1. Start with basic properties
2. Add counterexample constraints
3. Handle edge cases
4. Add ghost state for complex tracking

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Timeout | Reduce loop bounds, simplify spec |
| Counterexample | Add `require` constraints, check setup |
| Vacuous rule | Use `rule_sanity basic` |
| Path explosion | Bound arrays, reduce branching |

## CI Integration

### GitHub Actions (Halmos)
```yaml
- name: Run Halmos
  run: |
    pip install halmos
    halmos --solver-timeout-assertion 60000
```

### GitHub Actions (Certora)
```yaml
- name: Run Certora
  env:
    CERTORAKEY: ${{ secrets.CERTORAKEY }}
  run: |
    pip install certora-cli
    certoraRun certora/conf/Token.conf
```

## References

- [Halmos Docs](https://github.com/a16z/halmos/blob/main/docs/getting-started.md)
- [Certora Tutorials](https://docs.certora.com/en/latest/docs/cvl/index.html)
- [SMTChecker Docs](https://docs.soliditylang.org/en/latest/smtchecker.html)
- [Formal Verification Primer](https://www.zellic.io/blog/formal-verification-weth)
