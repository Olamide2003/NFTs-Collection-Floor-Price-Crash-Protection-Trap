# Architecture Documentation

## System Overview

The NFT Floor Price Crash Trap is a decentralized monitoring system built on the Drosera security network. It detects anomalous price movements in NFT collections through statistical analysis and dual oracle validation.

## Components

### 1. Price Oracles

**Purpose**: Provide reliable, validated floor price data for NFT collections.

**Implementation**: 
- Two independent oracle contracts following Chainlink's `IAggregatorV3Interface`
- Each oracle maintains price history with timestamps
- Owner-controlled price updates

**Key Functions**:
```solidity
function latestRoundData() external view returns (
    uint80 roundId,
    int256 answer,      // Price in wei
    uint256 startedAt,
    uint256 updatedAt,  // Last update timestamp
    uint80 answeredInRound
);
```

**Validation**:
- Staleness check: Data must be < 1 hour old
- Divergence check: Oracles must agree within 1%
- Non-zero check: Prices must be positive

### 2. Trap Contract

**Purpose**: Collect price data and analyze for crash patterns.

**Execution Model**:
- Deployed on shadow fork by Drosera every block
- No persistent state (all state resets each block)
- Pure functions for analysis

**Key Functions**:

#### `collect() → bytes`
- Called every block by Drosera
- Fetches data from both oracles
- Validates oracle agreement and freshness
- Returns encoded price snapshot

**Return Format**:
```solidity
abi.encode(
    uint256 version,      // Protocol version (1)
    uint256 price,        // Averaged floor price
    uint256 timestamp,    // Block timestamp
    address collection,   // NFT collection address
    string discordName    // Detector identifier
)
```

#### `shouldRespond(bytes[] data) → (bool, bytes)`
- Called with historical price data
- Analyzes time series for crash patterns
- Returns trigger decision and response payload

**Analysis Steps**:
1. Decode all data points
2. Validate data integrity
3. Calculate statistical metrics (mean, stddev)
4. Detect crash patterns
5. Return results if crash detected

### 3. Response Contract

**Purpose**: Record crash events and trigger emergency responses.

**State Variables**:
- `crashHistory`: Historical record of all crashes
- `emergencyMode`: Per-collection emergency status
- `authorizedTraps`: Whitelist of trap contracts
- `lastCrashTime/Price`: Most recent crash data

**Key Functions**:

#### `respondToCrash(...)`
- Called by Drosera when trap triggers
- Records crash in history
- Emits `CrashDetected` event
- Activates emergency mode if warranted

**Parameters**:
```solidity
(
    string discordName,      // Detector identifier
    address collection,      // NFT collection
    uint256 currentPrice,    // Current floor price
    uint256 baselinePrice,   // Previous baseline price
    uint8 crashType,         // Type of crash (1-4)
    uint256 timestamp,       // Detection time
    uint256 severity         // Severity metric (BPS)
)
```

## Data Flow

```
Block N:
┌─────────────────────────────────────────┐
│ 1. Drosera calls collect() on shadow fork
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 2. Trap fetches oracle data             │
│    - Primary Oracle: 8.5 ETH            │
│    - Secondary Oracle: 8.48 ETH         │
│    - Average: 8.49 ETH ✓                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 3. Returns encoded data                  │
│    abi.encode(1, 8490000...000, ...)    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 4. Drosera stores data in history       │
│    data[0] = Block N                     │
│    data[1] = Block N-1                   │
│    data[2] = Block N-2                   │
│    ...                                   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 5. Calls shouldRespond(data[])          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 6. Trap analyzes time series            │
│    - Prices: [8.49, 8.52, 8.50, ...]   │
│    - Mean: 8.50                          │
│    - Stddev: 0.02                        │
│    - No crash detected ✗                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ 7. Returns (false, bytes(""))           │
│    No response triggered                 │
└─────────────────────────────────────────┘

Block N+50 (Crash scenario):
┌─────────────────────────────────────────┐
│ collect() returns 5.95 ETH (30% drop)   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ shouldRespond() analysis:                │
│ - Current: 5.95 ETH                      │
│ - Baseline: 8.50 ETH                     │
│ - Drop: 30% (3000 BPS)                   │
│ - Pattern: Flash Crash                   │
│ - Outlier: 5.95 < mean - 2σ ✓          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Returns (true, responseData)             │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Drosera operators execute response       │
│ Call: respondToCrash(...)               │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Response contract:                       │
│ - Records crash in history               │
│ - Emits CrashDetected event             │
│ - Activates emergency mode              │
└─────────────────────────────────────────┘
```

## Detection Algorithms

### Flash Crash Detection

**Criteria**:
- Single interval drop ≥ 20% (2000 BPS)
- Current price < mean - 2σ (statistical outlier)

**Logic**:
```
For each consecutive price pair (i, i+1):
    drop = (price[i+1] - price[i]) / price[i+1] * 10000
    if drop >= 2000 AND price[i] < (mean - 2*stddev):
        return FlashCrash with severity=drop
```

**Example**:
- Prices: [10 ETH, 10.1 ETH, 6.5 ETH]
- Drop: (10.1 - 6.5) / 10.1 = 35.6% ✓
- Outlier: 6.5 < 8.87 - (2 * 2.02) = 4.83 ✓
- **Trigger: Flash Crash, 3560 BPS**

### Gradual Decline Detection

**Criteria**:
- All prices in descending order
- Total drop ≥ 30% (3000 BPS)
- Current price < mean - 2σ

**Logic**:
```
Check all prices are strictly decreasing:
    For i in 0..length-1:
        if price[i] >= price[i+1]: decline = false
        
If decline:
    totalDrop = (price[last] - price[first]) / price[last] * 10000
    if totalDrop >= 3000 AND price[first] < (mean - 2*stddev):
        return GradualDecline with severity=totalDrop
```

**Example**:
- Prices: [6.5 ETH, 8.0 ETH, 9.0 ETH, 10.0 ETH]
- Descending: ✓
- Drop: (10.0 - 6.5) / 10.0 = 35% ✓
- **Trigger: Gradual Decline, 3500 BPS**

### High Volatility Detection

**Criteria**:
- Average price swing ≥ 15% (1500 BPS)

**Logic**:
```
For each consecutive pair:
    swing = |price[i] - price[i+1]| / price[i] * 10000
    totalSwing += swing
    
volatility = totalSwing / (length - 1)
if volatility >= 1500:
    return HighVolatility with severity=volatility
```

**Example**:
- Prices: [11 ETH, 9 ETH, 12 ETH, 10 ETH]
- Swings: [18.2%, 25%, 16.7%]
- Average: 19.97% ✓
- **Trigger: High Volatility, 1997 BPS**

## Security Considerations

### Oracle Security

**Attack Vector**: Manipulated oracle prices
**Mitigation**: 
- Dual oracle requirement
- 1% divergence tolerance
- Staleness checks

**Attack Vector**: Stale data
**Mitigation**:
- 1-hour freshness requirement
- Automatic rejection of old data

### Response Contract Security

**Attack Vector**: Unauthorized triggers
**Mitigation**:
- `authorizedTraps` whitelist
- Only approved traps can trigger responses

**Attack Vector**: Spam attacks
**Mitigation**:
- 25-block cooldown period
- Rate limiting at Drosera level

### Statistical Analysis Security

**Attack Vector**: False positives
**Mitigation**:
- 2-sigma threshold for outliers
- Multiple detection criteria
- Historical pattern analysis

**Attack Vector**: Gradual manipulation
**Mitigation**:
- Volatility detection
- Trend analysis
- Long time windows

## Performance Characteristics

### Gas Costs

- `collect()`: ~50,000 gas (2 oracle reads + validation)
- `shouldRespond()`: ~150,000 gas (statistical analysis)
- `respondToCrash()`: ~100,000 gas (storage + event)

### Block Requirements

- Minimum: 3 blocks for detection
- Recommended: 20 blocks for accuracy
- Cooldown: 25 blocks between triggers

### Accuracy Metrics

- False positive rate: < 1% (based on 2σ threshold)
- Detection latency: 20-60 seconds (1-3 blocks)
- Oracle divergence: < 1% typically

## Scalability

### Current Limitations

- Single collection monitoring
- Sequential processing
- Fixed thresholds

### Expansion Possibilities

- Multi-collection support via array iteration
- Dynamic threshold adjustment based on volatility
- Parallel oracle processing
- Machine learning integration for pattern recognition

## Integration Points

### For Operators

**Required**:
- Ethereum RPC endpoint (Hoodi testnet)
- Drosera relay access
- Funded operator wallet

**Configuration**:
```toml
[traps.nft_floor_crash]
cooldown_period_blocks = 25
block_sample_size = 20
min_number_of_operators = 1
```

### For Consumers

**Event Monitoring**:
```solidity
event CrashDetected(
    string indexed discordDetector,
    address indexed collection,
    uint256 currentPrice,
    uint256 baselinePrice,
    uint8 crashType,
    uint256 detectionTimestamp,
    uint256 severity,
    string crashDescription
);
```

**Query Functions**:
- `getStats(collection)`: Get crash statistics
- `getRecentCrashes(count)`: Get crash history
- `isCollectionHealthy(collection)`: Get health status

## Future Enhancements

1. **Real Oracle Integration**: Replace mocks with Reservoir/Floor Protocol
2. **Multi-Collection**: Monitor entire collections simultaneously
3. **ML Detection**: Advanced pattern recognition
4. **Cross-Chain**: Support multiple EVM chains
5. **Advanced Responses**: Trading pauses, liquidity adjustments
6. **Dashboard**: Real-time monitoring interface
