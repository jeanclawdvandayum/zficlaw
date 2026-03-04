---
name: calldata-attack-patterns
description: Detect calldata manipulation attacks in smart contracts — ABI encoding exploits, dirty high bits, short calldata, selector collisions, multicall reentrancy, proxy calldata forwarding, and malicious encoding in cross-chain messages. Use when auditing external/public functions, proxy contracts, multicall patterns, bridges, or any contract that decodes raw calldata.
---

# Calldata Attack Patterns

Calldata is the raw input to every external transaction. Most Solidity developers trust the ABI encoder/decoder implicitly. Attackers don't.

---

## Why Calldata Attacks Matter

The EVM doesn't validate calldata. The Solidity ABI decoder does *some* checking, but:
- It ignores extra trailing data
- It trusts offset pointers for dynamic types
- It doesn't validate that `bytes` lengths match actual data
- It allows duplicate or overlapping data regions
- Low-level calls (`call`, `delegatecall`, `staticcall`) bypass ABI validation entirely

Calldata attacks exploit the gap between what developers assume the input looks like and what the EVM actually processes.

---

## Attack Taxonomy

### 1. Short Calldata / Missing Parameters

**Pattern:** Sending fewer bytes than the function signature expects.

```solidity
// Vulnerable: assumes all parameters present
function transfer(address to, uint256 amount) external {
    // If calldata is only 4 + 32 bytes (missing amount),
    // Solidity reverts in newer versions, but older versions
    // or assembly-based decoding may read zeros
    balances[msg.sender] -= amount;
    balances[to] += amount;
}
```

**What to look for:**
- Functions using `msg.data` or inline assembly to decode parameters
- `abi.decode` on raw calldata slices without length checks
- Contracts that use `calldataload` in assembly without bounds checking
- Fallback functions that parse `msg.data` manually

**Audit check:**
```
□ Does the contract use calldataload/calldatacopy in assembly?
□ Are there length checks on msg.data before decoding?
□ Do fallback/receive functions parse calldata manually?
□ Are there minimum calldata length requirements enforced?
```

### 2. Dirty High Bits (Address Padding)

**Pattern:** Passing addresses with non-zero high bits. Solidity masks to 160 bits, but some operations don't.

```solidity
// The EVM uses 256-bit words. An address is 160 bits.
// Solidity auto-cleans, but assembly might not:
function withdraw(address payable to) external {
    assembly {
        // calldataload reads full 32 bytes — top 12 bytes could be dirty
        let recipient := calldataload(4)
        // If not masked: recipient has dirty high bits
        // This can break mapping lookups, event logging, etc.
        pop(call(gas(), recipient, selfbalance(), 0, 0, 0, 0))
    }
}
```

**What to look for:**
- Assembly blocks that use `calldataload` for address parameters without `and(addr, 0xffffffffffffffffffffffffffffffffffffffff)` masking
- Hash computations over raw calldata (dirty bits change the hash)
- Cross-contract calls where dirty addresses bypass allowlist checks
- `abi.encodePacked` with addresses that weren't cleaned

**Audit check:**
```
□ Assembly calldataload for addresses — is masking applied?
□ Are addresses validated before use in mappings/storage?
□ Does keccak256 operate on cleaned or raw calldata?
□ Can dirty bits cause different storage slots to be accessed?
```

### 3. ABI Encoding Exploits (Dynamic Types)

**Pattern:** Crafting malicious ABI-encoded data with manipulated offsets, lengths, or overlapping regions.

```solidity
// ABI encoding for dynamic types uses offset pointers.
// Standard encoding:
//   [selector][offset_to_bytes][...][length][data]
// Malicious encoding can:
//   - Point offset to a different location (reuse data)
//   - Set length > actual data (read zeros/garbage)
//   - Create overlapping dynamic fields
//   - Use non-canonical encoding (different bytes, same decoded value)

function processMessage(bytes calldata message) external {
    // If message is forwarded to another contract,
    // the re-encoding may differ from original
    // This is especially dangerous in cross-chain contexts
}
```

**What to look for:**
- Functions that forward `msg.data` to other contracts
- `abi.decode` followed by `abi.encode` (re-encoding may normalize)
- Cross-chain message handlers that decode and re-encode
- Hash-based deduplication of messages (non-canonical encoding = different hash, same semantics)

**Specific patterns:**
- **Offset manipulation:** Dynamic type offset points past actual calldata → decoded as zeros
- **Length manipulation:** `bytes` length field claims more data than exists
- **Overlapping fields:** Two dynamic parameters share the same data region
- **Non-canonical encoding:** Same logical value encoded differently (different hash)

**Audit check:**
```
□ Are decoded calldata values re-encoded before hashing?
□ Can non-canonical ABI encoding bypass deduplication?
□ Are dynamic type offsets validated against calldata length?
□ Do forwarded messages preserve exact calldata or re-encode?
```

### 4. Selector Collisions

**Pattern:** Crafting function signatures whose first 4 bytes of keccak256 match a different function.

```solidity
// Function selectors are only 4 bytes = 2^32 possible values
// Collision probability is non-trivial at scale
// Tools: https://www.4byte.directory, seth

// Example collision:
// transfer(address,uint256) => 0xa9059cbb
// An attacker can find: someFunction_8aq2(bytes4) => 0xa9059cbb
// If a proxy routes by selector, this can be exploited
```

**What to look for:**
- Transparent proxy patterns where admin functions could collide with implementation functions (EIP-1967 mitigates but doesn't eliminate)
- Diamond proxy (EIP-2535) facet routing — collision between facets
- Multi-faceted contracts with many public functions (larger collision surface)
- Contracts that check `msg.sig` in modifiers

**Audit check:**
```
□ Check all function selectors for collisions across proxy + impl
□ In diamond proxies: check selectors across ALL facets
□ Are there selector-based access control checks?
□ Could a collision cause admin-only code to execute via user path?
```

### 5. Multicall Reentrancy / Batch Calldata

**Pattern:** Using `multicall` or batch execution patterns where individual calls within the batch can manipulate state that later calls depend on.

```solidity
function multicall(bytes[] calldata data) external returns (bytes[] memory results) {
    results = new bytes[](data.length);
    for (uint256 i = 0; i < data.length; i++) {
        // Each delegatecall executes in THIS contract's context
        // Call N can change state that Call N+1 reads
        (bool success, bytes memory result) = address(this).delegatecall(data[i]);
        require(success);
        results[i] = result;
    }
}
```

**Attack scenarios:**
- **Self-reentrancy via multicall:** Call 1 borrows, Call 2 borrows again before Call 1's balance update
- **Price manipulation within batch:** Call 1 manipulates price, Call 2 liquidates at manipulated price
- **Approval/transfer combos:** Call 1 sets approval, Call 2 transfers, Call 3 removes approval — atomically
- **msg.value reuse:** Each delegatecall in multicall sees the same `msg.value` — spend it multiple times

**Critical: msg.value in multicall**
```solidity
// DANGEROUS: Each delegatecall sees the SAME msg.value
function multicall(bytes[] calldata data) external payable {
    for (uint i; i < data.length; i++) {
        // Every call here can use msg.value
        // Send 1 ETH, but every sub-call sees msg.value = 1 ETH
        address(this).delegatecall(data[i]);
    }
}
```

**Audit check:**
```
□ Does multicall use delegatecall? (same storage context)
□ Can msg.value be double-spent across batch calls?
□ Are there reentrancy guards that span the full multicall?
□ Can batch ordering manipulate prices/balances between calls?
□ Are there view functions in the batch that could return stale state?
```

### 6. Proxy Calldata Forwarding

**Pattern:** Proxy contracts forward raw calldata to implementation contracts. The forwarding can introduce vulnerabilities.

```solidity
// Standard proxy fallback:
fallback() external payable {
    address impl = _implementation();
    assembly {
        calldatacopy(0, 0, calldatasize())
        let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
        returndatacopy(0, 0, returndatasize())
        switch result
        case 0 { revert(0, returndatasize()) }
        default { return(0, returndatasize()) }
    }
}
```

**Attack vectors:**
- **Extra calldata after valid parameters:** Solidity ignores trailing data, but forwarded calldata includes it. If the implementation re-forwards to another contract, extra data may be interpreted.
- **Calldata length as implicit parameter:** Some contracts use `calldatasize()` for logic decisions.
- **Proxy-implementation selector shadowing:** Proxy has an admin function with same selector as an implementation function.
- **Uninitialized proxy storage:** Calldata to `initialize()` after deployment but before initialization.

**Audit check:**
```
□ Does the proxy forward ALL calldata or strip/modify it?
□ Can extra trailing calldata affect downstream contracts?
□ Are proxy admin functions protected from selector collision?
□ Is the implementation initialized atomically with deployment?
□ Can calldatasize() be used to bypass logic in the implementation?
```

### 7. Cross-Chain Message Calldata

**Pattern:** Bridge messages carry calldata that gets executed on the destination chain. The encoding, validation, and execution are all attack surfaces.

```solidity
function executeMessage(
    address target,
    bytes calldata message,
    uint256 sourceChain
) external onlyBridge {
    // What could go wrong:
    // 1. message contains a different function call than expected
    // 2. message was valid on source chain but malicious on dest
    // 3. message was replayed from a different bridge
    // 4. message encoding is non-canonical
    (bool success,) = target.call(message);
    require(success, "execution failed");
}
```

**Attack scenarios:**
- **Calldata re-interpretation:** Same bytes, different ABI on destination contract
- **Target manipulation:** If `target` is attacker-controlled, they receive arbitrary calls from the bridge
- **Encoding ambiguity:** Source chain encodes with Solidity, destination decodes with Vyper (or vice versa) — subtle differences
- **Return data bombs:** Target returns massive data, consuming gas in the bridge executor

**Audit check:**
```
□ Is the target address validated (allowlist)?
□ Is the function selector validated (only known functions)?
□ Is message encoding strictly validated on receipt?
□ Can the same message be executed twice (replay)?
□ Is there a gas limit on the target.call?
□ Is return data size bounded?
```

### 8. Calldata in Signatures (EIP-712 / Permit)

**Pattern:** Signed messages that include calldata or encoded function calls. If the signed data can be reinterpreted, the signature enables unintended actions.

```solidity
// EIP-2612 permit — the calldata itself isn't signed,
// but the parameters that become calldata ARE signed.
// Attack: frontrunner sees permit tx in mempool,
// extracts signature, uses it in a different context.

// More dangerous: meta-transaction relayers
function executeMetaTx(
    address from,
    bytes calldata data,
    bytes calldata signature
) external {
    // If 'data' is included in the signed hash,
    // attacker can't modify it.
    // If only a hash of 'data' is signed,
    // attacker might find a collision.
    // If 'data' is NOT in the signed hash... game over.
}
```

**Audit check:**
```
□ Is the full calldata included in the signed hash?
□ Can the signature be used in a different contract/chain?
□ Is there a nonce to prevent replay?
□ Is the deadline enforced?
□ Can a relayer extract and front-run the meta-transaction?
□ Is EIP-712 domain separator chain-specific?
```

---

## End-to-End Calldata Audit Checklist

### Phase 1: Calldata Entry Points
1. Map ALL external/public functions
2. Identify functions using `msg.data`, `msg.sig`, `calldataload`, `calldatacopy`, `calldatasize` in assembly
3. Identify proxy forwarding patterns (fallback → delegatecall)
4. Identify multicall/batch patterns
5. Identify cross-chain message handlers
6. Identify meta-transaction / gasless relay patterns

### Phase 2: Calldata Decoding
7. Check for manual calldata parsing (assembly, abi.decode on slices)
8. Verify address parameter cleaning (dirty high bits)
9. Verify dynamic type offset/length validation
10. Check for calldatasize-dependent logic
11. Verify function selector collision freedom (across proxy + impl + all facets)

### Phase 3: Calldata Propagation
12. Trace calldata through forwarding chains (proxy → impl → internal calls)
13. Check if calldata is re-encoded between contracts (normalization risks)
14. Check if extra trailing calldata is propagated or stripped
15. Verify calldata integrity in cross-chain messages
16. Check for calldata in signed messages (meta-tx, permits, EIP-712)

### Phase 4: Calldata Exploitation
17. Test multicall msg.value double-spending
18. Test batch ordering attacks (state manipulation between calls)
19. Test short calldata on manual decoders
20. Test non-canonical encoding for hash-based deduplication bypass
21. Test selector collision exploitation in proxy patterns
22. Test return data bombs on external calls

---

## Tools

- **4byte.directory** — Function selector database, collision checker
- **Foundry `cast 4byte`** — Selector lookup
- **Slither** — `calldataload` without masking detector
- **Echidna/Medusa** — Fuzz calldata with malformed inputs
- **Halmos** — Symbolic execution over calldata parameters
- **Custom Foundry tests** — Craft malicious calldata with `abi.encodeWithSelector` + raw bytes

## References

- Solidity ABI Encoding Specification: https://docs.soliditylang.org/en/latest/abi-spec.html
- EVM Execution: Yellow Paper §9 (Message Call)
- OpenZeppelin Multicall: Known msg.value issue documented
- Trail of Bits: "Not all bugs are created equal" — calldata manipulation in real audits
