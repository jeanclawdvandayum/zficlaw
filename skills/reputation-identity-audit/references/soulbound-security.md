# Soulbound Token (SBT) Security

A deep dive into implementation vulnerabilities, best practices, and security considerations for non-transferable credential tokens.

## What are Soulbound Tokens?

Soulbound Tokens (SBTs) are non-transferable NFTs that represent identity, credentials, achievements, or affiliations. Inspired by World of Warcraft's "soulbound" items, these tokens are permanently bound to a wallet address.

**Key Properties:**
- Non-transferable (cannot be sold, traded, or moved)
- Revocable (issuer or user can burn under certain conditions)
- Composable (can be checked by other contracts)
- Potentially recoverable (through social recovery mechanisms)

**Use Cases:**
- Educational credentials and degrees
- Work history and professional certifications
- Community memberships and roles
- Attendance proofs (POAP-style)
- Credit scores and reputation
- KYC/AML compliance badges
- Gaming achievements

## Core Security Requirements

### 1. Transfer Prevention

**The Fundamental Challenge:** Ensuring tokens truly cannot be transferred, even through edge cases.

#### ERC-721 Override Requirements

```solidity
// ✅ SECURE: Explicitly revert all transfer functions
contract SoulboundToken is ERC721 {
    
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public pure override {
        revert("SBT: Non-transferable");
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public pure override {
        revert("SBT: Non-transferable");
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public pure override {
        revert("SBT: Non-transferable");
    }
    
    function approve(address to, uint256 tokenId) public pure override {
        revert("SBT: Non-approvable");
    }
    
    function setApprovalForAll(
        address operator,
        bool approved
    ) public pure override {
        revert("SBT: Non-approvable");
    }
    
    function getApproved(uint256 tokenId) public pure override returns (address) {
        return address(0); // Always return zero address
    }
}
```

#### Common Transfer Bypass Vulnerabilities

**❌ Vulnerability #1: Empty Override**
```solidity
// VULNERABLE: Function exists but does nothing
function transferFrom(address, address, uint256) public override {}
// An attacker might find a way to call the parent implementation
```

**❌ Vulnerability #2: Conditional Transfer**
```solidity
// VULNERABLE: Allows transfer under certain conditions
function transferFrom(address from, address to, uint256 tokenId) public override {
    require(msg.sender == owner(), "Only owner can transfer");
    super.transferFrom(from, to, tokenId);
}
// Compromised owner key = all SBTs can be transferred!
```

**❌ Vulnerability #3: Missing Overrides**
```solidity
// VULNERABLE: Only overrides some transfer functions
contract SBT is ERC721 {
    function transferFrom(...) public pure override {
        revert("Non-transferable");
    }
    // Missing: safeTransferFrom, approve, setApprovalForAll
    // Users can still call these inherited functions!
}
```

**✅ Best Practice: Use ERC-5192 Standard**

```solidity
// SECURE: Implement ERC-5192 "Minimal Soulbound NFTs"
interface IERC5192 {
    event Locked(uint256 tokenId);
    event Unlocked(uint256 tokenId);
    function locked(uint256 tokenId) external view returns (bool);
}

contract SoulboundToken is ERC721, IERC5192 {
    function locked(uint256 tokenId) external pure override returns (bool) {
        return true; // Always locked
    }
    
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        super._afterTokenTransfer(from, to, tokenId, batchSize);
        if (from == address(0)) {
            emit Locked(tokenId); // Emit on mint
        }
    }
}
```

### 2. Wallet Recovery & Key Management

**The Paradox:** SBTs must be bound to identity, but wallets can be lost/hacked.

#### Recovery Mechanism Options

**Option A: Social Recovery (Vitalik's Model)**
```solidity
contract SocialRecoverySBT {
    mapping(address => address[]) public guardians;
    mapping(address => mapping(address => uint256)) public recoveryVotes;
    uint256 public constant RECOVERY_THRESHOLD = 3;
    
    function initiateRecovery(
        address oldWallet,
        address newWallet,
        address guardian
    ) external {
        require(isGuardian(oldWallet, guardian), "Not a guardian");
        recoveryVotes[oldWallet][newWallet]++;
        
        if (recoveryVotes[oldWallet][newWallet] >= RECOVERY_THRESHOLD) {
            transferAllSBTs(oldWallet, newWallet);
        }
    }
}
```

**Risks:**
- Guardian collusion to steal identity
- Social pressure on guardians
- Guardians losing their own keys

**Option B: Time-Locked Admin Recovery**
```solidity
contract TimelockRecoverySBT {
    mapping(address => RecoveryRequest) public recoveryRequests;
    uint256 public constant TIMELOCK = 7 days;
    
    struct RecoveryRequest {
        address newWallet;
        uint256 timestamp;
    }
    
    function requestRecovery(address newWallet) external {
        recoveryRequests[msg.sender] = RecoveryRequest(newWallet, block.timestamp);
    }
    
    function executeRecovery() external {
        RecoveryRequest memory req = recoveryRequests[msg.sender];
        require(block.timestamp >= req.timestamp + TIMELOCK, "Timelock active");
        transferAllSBTs(msg.sender, req.newWallet);
    }
}
```

**Risks:**
- Hacker can front-run recovery
- User must monitor for unauthorized recovery requests

**Option C: No Recovery (Permanent Binding)**
- Lost wallet = lost credentials forever
- Users must secure keys like their life depends on it
- Requires excellent UX education on wallet security

#### Key Management Best Practices

**User Education:**
- ⚠️ **Critical:** Warn users during minting that SBTs require secure wallets
- Recommend hardware wallets (Ledger, Trezor)
- Encourage secure seed phrase storage (metal backup)
- Consider multi-sig wallets for high-value identities

**Contract-Level Warnings:**
```solidity
function mint(address to, uint256 tokenId) external {
    // Emit warning event that can be shown in UI
    emit SecurityWarning(
        to,
        "This SBT is non-transferable and requires secure wallet management"
    );
    _mint(to, tokenId);
    emit Locked(tokenId);
}
```

### 3. Revocation & Burning

**Who should be able to revoke/burn SBTs?**

#### Revocation Models

**Model A: Issuer Revocation Only**
```solidity
// Only the issuer can revoke (e.g., university revoking fraudulent degree)
function revoke(uint256 tokenId) external onlyIssuer {
    require(_exists(tokenId), "Token doesn't exist");
    _burn(tokenId);
    emit Revoked(tokenId, "Revoked by issuer");
}
```

**Use Cases:** Academic degrees, professional licenses, certifications

**Risks:** Centralized power, censorship, malicious revocation

**Model B: User Self-Revocation**
```solidity
// Token holder can burn their own SBT
function selfRevoke(uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender, "Not token owner");
    _burn(tokenId);
    emit SelfRevoked(tokenId);
}
```

**Use Cases:** Privacy protection, voluntary credential removal

**Risks:** Accidental burns, pressure to revoke

**Model C: Dual Revocation (Both Parties)**
```solidity
function revoke(uint256 tokenId, string memory reason) external {
    address owner = ownerOf(tokenId);
    bool isIssuer = hasRole(ISSUER_ROLE, msg.sender);
    bool isOwner = (msg.sender == owner);
    
    require(isIssuer || isOwner, "Not authorized");
    _burn(tokenId);
    
    if (isIssuer) {
        emit IssuerRevoked(tokenId, reason);
    } else {
        emit SelfRevoked(tokenId);
    }
}
```

**Model D: Dispute-Based Revocation**
```solidity
contract DisputeRevocation {
    mapping(uint256 => Dispute) public disputes;
    
    struct Dispute {
        bool active;
        uint256 votesFor;
        uint256 votesAgainst;
        string reason;
    }
    
    function initiateDispute(uint256 tokenId, string memory reason) external {
        disputes[tokenId] = Dispute(true, 0, 0, reason);
    }
    
    function voteOnDispute(uint256 tokenId, bool supportRevocation) external {
        // DAO or community voting mechanism
        // Revoke if threshold reached
    }
}
```

### 4. Metadata Security

**Mutable vs Immutable Metadata:**

**❌ Vulnerable: Admin-Controlled Metadata**
```solidity
// VULNERABLE: Admin can change credential content after issuance
mapping(uint256 => string) public tokenURIs;

function setTokenURI(uint256 tokenId, string memory newURI) external onlyOwner {
    tokenURIs[tokenId] = newURI;
}
```

**Problem:** A compromised admin could alter diploma text, change certification details, or defame users.

**✅ Secure: Immutable On-Chain Metadata**
```solidity
struct Credential {
    string institution;
    string degreeType;
    uint256 graduationYear;
    bytes32 metadataHash; // IPFS hash or content hash
}

mapping(uint256 => Credential) public credentials;

function mint(address to, uint256 tokenId, Credential memory cred) external {
    credentials[tokenId] = cred; // Set once at mint, never changes
    _mint(to, tokenId);
}
```

**✅ Secure: Content-Addressed Storage**
```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    bytes32 ipfsHash = credentials[tokenId].metadataHash;
    return string(abi.encodePacked("ipfs://", ipfsHash));
}
```

### 5. Composability & Permission Checking

**SBTs are meant to be checked by other contracts:**

```solidity
// Example: Gated access based on SBT ownership
contract DAO {
    IERC721 public membershipSBT;
    
    modifier onlyMembers() {
        require(membershipSBT.balanceOf(msg.sender) > 0, "No membership SBT");
        _;
    }
    
    function vote(uint256 proposalId, bool support) external onlyMembers {
        // Only SBT holders can vote
    }
}
```

**Security Considerations:**
- What if SBT is revoked after gaining access?
- Should contracts cache SBT ownership or check real-time?
- Gas costs of repeated ownership checks

**Best Practice: Expiration Timestamps**
```solidity
mapping(uint256 => uint256) public expirationTimestamps;

function isValid(uint256 tokenId) public view returns (bool) {
    if (!_exists(tokenId)) return false;
    uint256 expiry = expirationTimestamps[tokenId];
    if (expiry == 0) return true; // No expiration
    return block.timestamp < expiry;
}
```

## Advanced Attack Vectors

### Account Abstraction Bypass

**Risk:** ERC-4337 account abstraction might enable indirect transfers

```solidity
// Potential vulnerability: Smart contract wallets
// If SBT holder uses a smart wallet, can the wallet be "transferred"?

// Alice mints SBT to her AA wallet
// Alice transfers control of AA wallet to Bob
// Bob now "owns" the SBT indirectly
```

**Mitigation:**
- Detect smart contract recipients at mint time?
- Require EOAs only? (Breaks composability)
- Accept this as limitation (transfer entire identity, not just SBT)

### Marketplace Bypass

**Attack:** Sell the entire wallet/account instead of the SBT

**Examples:**
- Sell seed phrase for $X
- Transfer private key off-chain
- Social contract: "I'll transfer control if you pay me"

**Mitigation:**
- Continuous behavioral verification (not just ownership check)
- Activity-based reputation (inactive SBTs lose value)
- Economic penalties for detected account sales
- Reality: Can't fully prevent off-chain coordination

### Collateral-Based Lending

**Attack:** Use SBT-holding wallet as collateral in DeFi lending

```solidity
// Attacker's strategy:
// 1. Get valuable SBT (e.g., high credit score)
// 2. Lock wallet in lending protocol as collateral
// 3. Borrow against the SBT's implied value
// 4. Default on loan, lender gets wallet (and SBT)
```

**Mitigation:**
- Educate DeFi protocols not to accept SBT value as collateral
- SBTs should not have financial value (only utility)
- Implement checks to prevent lending protocol integration

### Phishing & Social Engineering

**Attack:** Trick users into "upgrading" their SBT to a fake contract

**Example:**
```
Phishing email: "Your diploma SBT needs to be upgraded to the new standard.
Click here to migrate: [malicious contract]"
```

**Mitigation:**
- Strong branding and official communication channels
- Warnings in smart contract comments/NatSpec
- Community education
- SBT registries with verified issuers

## Implementation Checklist

**Pre-Deployment:**
- [ ] All transfer functions explicitly revert with clear error messages
- [ ] No approval functions allow any address
- [ ] ERC-5192 Locked events emitted correctly
- [ ] Metadata is immutable or hash-locked
- [ ] Recovery mechanism designed and tested
- [ ] Revocation process defined (who can revoke, under what conditions)
- [ ] User warnings implemented for security education

**Testing:**
- [ ] Unit tests for all transfer functions (expect revert)
- [ ] Integration tests with marketplaces (should reject SBTs)
- [ ] Fuzz testing for edge cases
- [ ] Test recovery mechanism with various scenarios
- [ ] Test revocation by different actors

**Audit:**
- [ ] Professional audit by reputable firm
- [ ] Specific focus on transfer restrictions
- [ ] Verify metadata immutability
- [ ] Check recovery mechanism security
- [ ] Review access control for revocation

**Post-Deployment:**
- [ ] Monitor for unexpected transfers (should never happen)
- [ ] Track revocation patterns (abuse detection)
- [ ] User education materials deployed
- [ ] Incident response plan for key compromises

## ERC Standards Reference

### ERC-5192: Minimal Soulbound NFTs

**Interface:**
```solidity
interface IERC5192 {
    /// @notice Emitted when the locking status is changed to locked.
    /// @dev If a token is minted and the status is locked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Locked(uint256 tokenId);

    /// @notice Emitted when the locking status is changed to unlocked.
    /// @dev If a token is minted and the status is unlocked, this event should be emitted.
    /// @param tokenId The identifier for a token.
    event Unlocked(uint256 tokenId);

    /// @notice Returns the locking status of an Soulbound Token
    /// @dev SBTs assigned to zero address are considered invalid, and queries
    /// about them do throw.
    /// @param tokenId The identifier for an SBT.
    function locked(uint256 tokenId) external view returns (bool);
}
```

### ERC-4973: Account-Bound Tokens

Alternative standard with different approach (not compatible with ERC-721):

```solidity
interface IERC4973 {
    event Attest(address indexed to, uint256 indexed tokenId);
    event Revoke(address indexed to, uint256 indexed tokenId);
    
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    
    // Two-step process: recipient must accept
    function give(
        address to,
        string calldata uri,
        bytes calldata signature
    ) external returns (uint256);
    
    function take(
        address from,
        string calldata uri,
        bytes calldata signature
    ) external returns (uint256);
}
```

## Real-World Implementations

**Binance Account Bound (BAB) Token:**
- KYC-verified users get SBT
- Cannot transfer
- Used for governance and benefits
- Revocable by Binance if KYC fails

**Optimism AttestationStation:**
- On-chain attestations as SBTs
- Anyone can issue attestations
- Recipient cannot remove (but can issue counter-attestation)
- Composable reputation layer

**POAP (Proof of Attendance Protocol):**
- Originally transferable (NFT)
- Moving toward soulbound for credibility
- Event organizer can revoke fraudulent claims

## Resources

- **EIP-5192:** https://eips.ethereum.org/EIPS/eip-5192
- **EIP-4973:** https://eips.ethereum.org/EIPS/eip-4973
- **Vitalik's DeSoc Paper:** https://papers.ssrn.com/sol3/papers.cfm?abstract_id=4105763
- **OpenZeppelin Contracts:** Reference implementations

---

**Last Updated:** 2026-02-05  
**Maintainer:** Security Research Team
