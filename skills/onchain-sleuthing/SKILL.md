# On-Chain Sleuthing — Blockchain Investigation & OSINT

Methodology-driven skill for investigating on-chain activity: tracing stolen funds, identifying wallet owners, mapping transaction flows, attributing pseudonymous actors, and building evidence chains. Based on ZachXBT's published toolkit and the OffcierCia investigations handbook.

**Use when:** investigating suspicious transactions, tracing hacked/stolen funds, attributing wallets to entities, analyzing bridge hops, performing crypto OSINT, building investigation reports, or helping with any blockchain forensics task.

---

## Investigation Methodology — The Layered Approach

Blockchain investigations follow a funnel: start broad (on-chain), narrow through bridges and mixers, then pivot to off-chain identity. Each layer feeds the next.

### Phase 1: On-Chain Graphing
**Goal:** Map the money flow. Where did funds come from? Where did they go?

**Process:**
1. Start with the known address (victim report, exploit tx, flagged wallet)
2. Graph all inbound/outbound transactions — look for patterns:
   - Large transfers to fresh wallets (fund splitting)
   - Interactions with DEXs (token swaps to obscure trail)
   - Deposits to CEXs (potential cash-out points)
   - Contract interactions (DeFi protocols, NFT marketplaces)
3. Label known entities (exchanges, protocols, bridges, mixers)
4. Identify the "hop pattern" — how many intermediary wallets before destination?
5. Flag timing patterns — rapid sequential transfers suggest automated laundering

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **Arkham** | Multi-chain explorer with entity labels, alerts, visual graphs | intel.arkm.com | Best for entity attribution; has extensive label database |
| **MetaSleuth** | Retail-friendly transaction graphing (by BlockSec) | metasleuth.io | Good visual graphs, free tier available |
| **TRM Labs** | Enterprise-grade address/tx graphing, relationship mapping | trmlabs.com | Used by law enforcement; paid |
| **Cielo** | Wallet tracking across EVM, BTC, Solana, Tron | cielo.finance | Best multi-chain wallet monitor |
| **Phalcon** | Transaction visualization and simulation | phalcon.xyz | Great for understanding complex DeFi txs |
| **Breadcrumbs** | Visual blockchain investigation tool | breadcrumbs.app | Free tier, good for beginners |
| **Bubblemaps** | Cluster visualization for token holder analysis | bubblemaps.io | Shows wallet clusters and concentration |

**Key Questions:**
- What was the first funding source? (CEX withdrawal = potential KYC link)
- Are there common wallets linking separate incidents?
- What's the time delay between hops? (Seconds = bot, hours/days = human)
- Are funds being consolidated or distributed?

### Phase 2: Bridge & Cross-Chain Analysis
**Goal:** Track funds across chains. Attackers bridge to break the trail.

**Process:**
1. Check if target address interacted with any bridge contracts
2. For each bridge tx: find the destination chain + receiving address
3. Continue Phase 1 graphing on the destination chain
4. Common laundering path: Ethereum → Bridge → L2/alt-chain → DEX swap → Bridge back → CEX

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **Range** | Cross-chain transfer protocol (CCTP) explorer | range.org | Circle CCTP bridges specifically |
| **Pulsy** | Aggregator for multiple bridge explorers | pulsy.app | Checks multiple bridges at once |
| **Socketscan** | EVM-focused bridge explorer | socketscan.io | Socket/Bungee bridge tracking |
| **Blockchair** | Multi-chain explorer (strong Bitcoin) | blockchair.com | Best for BTC chain analysis |

**Common Bridge Patterns:**
- Ethereum ↔ Arbitrum/Optimism (canonical bridges)
- Any chain → Tornado Cash/Railgun (mixing)
- EVM → Solana via Wormhole
- EVM → Bitcoin via RenBridge (deprecated but historical)
- USDC via Circle CCTP (trackable via Range)

**Mixer Detection:**
- Tornado Cash: Look for 0.1/1/10/100 ETH deposits to known TC contracts
- Railgun: Watch for shielded transfers via Railgun relay
- De-mixing research: See OffcierCia's work on TC/Railgun de-mixing patterns
- Timing analysis: deposits and withdrawals with matching amounts + suspicious timing gaps

### Phase 3: Blockchain Data Analytics
**Goal:** Find patterns across large datasets that manual graphing misses.

**Process:**
1. Write Dune queries to aggregate wallet behavior
2. Look for: token distribution patterns, timing clusters, gas price patterns, contract deployment patterns
3. Cross-reference with known exploit signatures

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **Dune Analytics** | SQL queries over blockchain data | dune.com | Custom queries; community dashboards |
| **Flipside Crypto** | Blockchain data analytics platform | flipsidecrypto.xyz | Alternative to Dune |
| **Nansen** | Wallet labeling + analytics | nansen.ai | Paid; excellent entity labels |
| **Parsec** | DeFi analytics + wallet tracking | parsec.finance | Real-time monitoring |
| **The Graph** | Subgraph protocol for indexed blockchain data | thegraph.com | For protocol-specific queries |

**Useful Dune Patterns:**
```sql
-- Find all transfers from suspect wallet
SELECT * FROM erc20_ethereum.evt_Transfer
WHERE "from" = 0xSUSPECT_ADDRESS
ORDER BY evt_block_time DESC

-- Find funding source
SELECT * FROM ethereum.traces
WHERE to = 0xTARGET AND value > 0
ORDER BY block_time ASC LIMIT 5

-- Token holder concentration
SELECT to AS holder, SUM(value) as total
FROM erc20_ethereum.evt_Transfer
WHERE contract_address = 0xTOKEN
GROUP BY 1 ORDER BY 2 DESC LIMIT 20
```

### Phase 4: Enhanced Block Explorer Analysis
**Goal:** Extract maximum information from standard block explorers.

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **Etherscan** | Ethereum block explorer | etherscan.io | Check labels, comments, internal txs |
| **MetaSuites** | Chrome extension adding extra data to explorers | Chrome Web Store | Enhances Etherscan with more context |
| **Solscan** | Solana block explorer | solscan.io | SOL ecosystem |
| **Blockchair** | Bitcoin + multi-chain explorer | blockchair.com | Privacy-focused BTC analysis |
| **Openchain** | EVM trace explorer | openchain.xyz/trace | Detailed internal call traces |
| **Dedaub** | Smart contract decompiler + library | library.dedaub.com | Decompile unverified contracts |
| **Heimdall-rs** | EVM bytecode decompiler (CLI) | github.com/Jon-Becker/heimdall-rs | Local decompilation |

**Etherscan Power Moves:**
- Check the **"More Info"** section for labels (exchange, phishing, hack)
- Read **comments** on addresses — community often flags scams
- Use **"Internal Txs"** tab to see contract-to-contract transfers
- Check **"Analytics"** for balance over time charts
- **Token Transfers** tab shows ERC-20 movements
- **etherscan-labels** repo: github.com/brianleect/etherscan-labels (JSON/CSV dumps)

### Phase 5: Identity OSINT (Off-Chain Pivot)
**Goal:** Connect on-chain addresses to real-world identities. This is where investigations become attributions.

**⚠️ Ethics:** Only use for investigating crimes/scams. Never for doxxing, harassment, or stalking. Respect privacy laws in your jurisdiction.

**Process:**
1. Check if any connected address has ENS name → search that name elsewhere
2. Check if address received funds from a KYC'd exchange → subpoena potential
3. Search leaked databases for email/username associated with the address
4. Cross-reference social media for wallet address mentions
5. Check domain registrations, GitHub commits, forum posts

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **OSINT Industries** | Email, username, phone lookups | osint.industries | Aggregates multiple data sources |
| **LeakPeek** | Leaked data search | leakpeek.com | Check if credentials appear in breaches |
| **Snusbase** | Breach database search | snusbase.com | Email/username/password breach lookup |
| **Intelligence X** | OSINT search engine (dark web, leaks, public data) | intelx.io | Historical data, paste sites, dark web |
| **Spur** | IP address intelligence | spur.us | VPN/proxy/residential detection |
| **Hudson Rock (Cavalier)** | Infostealer lookup | hudsonrock.com/cavalier | Check if device was compromised by stealer malware |
| **TelegramDB** | Telegram user OSINT | telegramdb.org | Basic Telegram identity lookup |
| **Discord.ID** | Discord account OSINT | discord.id | Discord identity lookup |

**Identity Pivots:**
- ENS name → Twitter/GitHub/forum username
- Email from breach data → social media accounts
- IP from transaction metadata → geolocation
- GitHub commits → email in git config
- Domain registration → WHOIS (historical via DomainTools)
- NFT metadata → IPFS uploads with embedded creator info

### Phase 6: Historical Archival & Evidence Preservation
**Goal:** Archive everything. Web pages get deleted. Tweets get removed. Preserve evidence.

**Tools:**
| Tool | What It Does | URL | Notes |
|------|-------------|-----|-------|
| **Wayback Machine** | Web page archival | web.archive.org | Archive URLs before they disappear |
| **Archive Today** | Alternative web archiver | archive.today | Better for dynamic pages |
| **Mugetsu** | Historical X/Twitter username tracking + memecoin lookup | Telegram: @the_mugetsu_bot | See who changed their username |

**Evidence Chain:**
1. Screenshot everything with timestamps
2. Archive web pages immediately (they WILL be deleted)
3. Save transaction hashes — they're permanent but context isn't
4. Document your methodology — how you got from A to B
5. Use Obsidian or similar for flow charts connecting entities

---

## Investigation Templates

### Template: Hack/Exploit Investigation
```
1. INCIDENT
   - Protocol:
   - Date/Time (UTC):
   - Exploit TX:
   - Estimated loss:
   - Attack vector:

2. ATTACKER WALLET TREE
   - Primary: 0x...
   - Fund source: [CEX withdrawal / contract deployment / funded by 0x...]
   - Intermediaries: [list hop wallets]
   - Destinations: [CEX deposits, bridges, mixers, DeFi]

3. BRIDGE HOPS
   - Chain A → Chain B via [bridge name], TX: [hash]
   - Amount: [tokens/value]

4. MIXER INTERACTION
   - Tornado Cash: [yes/no, amounts, deposit/withdrawal TXs]
   - Railgun: [yes/no]
   - Other: [specify]

5. CEX TOUCHPOINTS
   - Exchange: [name]
   - Deposit address: 0x...
   - Amount:
   - [Potential for law enforcement subpoena: yes/no]

6. IDENTITY LEADS
   - ENS: [if any]
   - Social: [linked accounts]
   - Breach data: [if relevant]

7. TIMELINE
   [Chronological event list]

8. EVIDENCE ARCHIVE
   [List of archived URLs, screenshots, saved data]
```

### Template: Scam/Rug Investigation
```
1. PROJECT
   - Name:
   - Contract(s):
   - Deployer:
   - Website (archived):
   - Social accounts:

2. FUND FLOW
   - Total raised:
   - Rug TX / drain TX:
   - Where funds went:

3. TEAM IDENTITY
   - Claimed team: [names, social profiles]
   - Actual identity leads: [breach data, historical wallets, connected projects]
   - Prior rugs by same actor: [list if found]

4. PATTERN MATCHING
   - Same deployer as other projects?
   - Same contract code (bytecode match)?
   - Same social media patterns?
   - Connected wallets to known scammers?

5. EVIDENCE
   [Archived pages, screenshots, saved social posts]
```

---

## Operational Security for Investigators

1. **Use a dedicated browser profile** — separate from personal browsing
2. **VPN always on** — some targets monitor who's looking at their wallets
3. **Never connect your real wallet** to investigation tools
4. **Use Impersonator extension** (impersonator.xyz) to safely view dApps as any address
5. **Don't announce findings prematurely** — tip-off lets attackers move funds
6. **Archive before publishing** — pages get scrubbed within hours of exposure
7. **Document methodology** — if findings go to law enforcement, chain of evidence matters

---

## Quick Reference: Tool Selection by Task

| Task | First Choice | Backup |
|------|-------------|--------|
| Multi-chain wallet tracking | Cielo | Arkham |
| Transaction graphing | Arkham | MetaSleuth |
| Enterprise investigation | TRM Labs | Chainalysis |
| Bridge tracking | Pulsy | Range + Socketscan |
| SQL analytics | Dune | Flipside |
| Block explorer+ | Etherscan + MetaSuites | Blockchair |
| Email/username OSINT | OSINT Industries | IntelX |
| Breach data | Snusbase | LeakPeek |
| IP intelligence | Spur | — |
| Infostealer check | Hudson Rock | — |
| Web archival | Wayback Machine | archive.today |
| Username history (Twitter) | Mugetsu | — |
| Contract decompilation | Dedaub | Heimdall-rs |
| Token holder clustering | Bubblemaps | Nansen |

---

## Common Laundering Patterns

### The Classic CEX Cashout
```
Exploit → Split across 5-10 wallets → DEX swaps to ETH/USDC → CEX deposit
```
**Detection:** Watch for fresh wallets receiving funds → swapping → depositing to labeled exchange addresses.

### The Bridge Hop
```
Exploit on Chain A → Bridge to Chain B → Bridge to Chain C → DEX → CEX on Chain C
```
**Detection:** Use Pulsy/Range to track cross-chain movements. Each bridge is a chokepoint.

### The Tornado/Mixer Wash
```
Exploit → ETH → Tornado Cash (0.1/1/10/100 increments) → Fresh wallets → Slow CEX deposits
```
**Detection:** Look for standardized deposit amounts to known mixer contracts. Timing analysis on withdrawals.

### The DeFi Layering
```
Exploit → Supply to Aave → Borrow different token → Bridge → Swap → CEX
```
**Detection:** Track DeFi protocol interactions. Borrowed tokens create a layer of indirection.

### The NFT Wash
```
Exploit → Buy high-value NFT → Sell to accomplice wallet → Accomplice sells on marketplace → Fiat
```
**Detection:** NFT sales between fresh wallets at inflated prices. Check Bubblemaps for cluster analysis.

---

## Sources & Further Reading

- ZachXBT's toolkit announcement: Telegram @investigations
- OffcierCia investigations handbook: github.com/OffcierCia/On-Chain-Investigations-Tools-List
- OffcierCia methodology article: officercia.mirror.xyz/BFzv17UwH6QG4q711NAljtSiP8eKR17daLjTdmAgbHw
- BitPinas toolkit breakdown: bitpinas.com/learn-how-to-guides/zachxbt-complete-toolkit-top-blockchain-investigation/
- Etherscan labels dataset: github.com/brianleect/etherscan-labels
- OSINT Industries case studies: osint.industries/project/
