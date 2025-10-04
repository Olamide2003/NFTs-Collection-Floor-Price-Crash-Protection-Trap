# NFT Floor Price Crash Trap

A Drosera security trap that detects and responds to anomalous NFT floor price movements using dual oracle validation and statistical analysis.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue)](https://docs.soliditylang.org/)

## Overview

This trap monitors NFT collection floor prices and automatically detects three types of anomalous price behavior:

- **Flash Crash**: Sudden price drops >20% in a single interval
- **Gradual Decline**: Sustained downward trend with >30% total decline
- **High Volatility**: Excessive price swings averaging >15%

The trap uses dual oracle validation to ensure price accuracy and employs statistical analysis (mean, standard deviation) to reduce false positives.

## Features

- **Dual Oracle System**: Primary and secondary oracles with automatic validation
- **Statistical Detection**: Uses 2-sigma outlier detection to identify genuine crashes
- **Time-Series Analysis**: Analyzes price patterns across configurable block windows
- **Emergency Mode**: Automatic activation for severe crashes
- **Basis Points Precision**: All thresholds use BPS (1/10,000) for accuracy
- **Shadow-Fork Compatible**: No mutable state dependencies

## Architecture

```
┌─────────────────┐
│  NFT Collection │
└────────┬────────┘
         │
    ┌────▼────┐  ┌──────────┐
    │ Primary │  │Secondary │
    │ Oracle  │  │  Oracle  │
    └────┬────┘  └─────┬────┘
         │             │
         └──────┬──────┘
                │
        ┌───────▼────────┐
        │  Crash Trap    │
        │  (collect)     │
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │  Drosera       │
        │  (shouldRespond)│
        └───────┬────────┘
                │
        ┌───────▼────────┐
        │  Response      │
        │  Contract      │
        └────────────────┘
```

## Deployment

**Network**: Hoodi Testnet (Chain ID: 560048)

**Deployed Contracts**:
- Response Contract: `0x1c446Def189616AB89a10f538a9Aed89b7b2ecE5`
- Trap Contract: `0x15c08F2D5e8C23fA43926F1E5F698553202FAf85`

## Quick Start

### Prerequisites

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Install Drosera CLI
curl -L https://install.drosera.io | bash
```

### Installation

```bash
# Clone repository
git clone https://github.com/yourusername/nft-floor-crash-trap
cd nft-floor-crash-trap

# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test
forge test --match-test testDetectsFlashCrash
```

### Deployment

See [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) for complete deployment instructions.

## Configuration

### Detection Thresholds

```solidity
uint256 constant NORMAL_DROP_BPS = 500;          // 5%
uint256 constant MIN_DROP_BPS = 2000;            // 20% (flash crash)
uint256 constant MAX_DROP_BPS = 3000;            // 30% (gradual decline)
uint256 constant VOLATILITY_THRESHOLD_BPS = 1500; // 15%
uint256 constant MAX_ORACLE_DIVERGENCE_BPS = 100; // 1%
```

### Drosera Configuration

```toml
[traps.nft_floor_crash]
response_function = "respondToCrash(string,address,uint256,uint256,uint8,uint256,uint256)"
cooldown_period_blocks = 25
block_sample_size = 20
min_number_of_operators = 1
max_number_of_operators = 3
```

## How It Works

### 1. Data Collection

The trap's `collect()` function:
- Fetches prices from both oracles
- Validates data freshness (< 1 hour)
- Ensures oracles agree (< 1% divergence)
- Returns averaged price with metadata

### 2. Crash Detection

The `shouldRespond()` function:
- Analyzes time-series price data
- Calculates statistical metrics (mean, stddev)
- Identifies crash patterns
- Validates against thresholds
- Returns crash type and severity

### 3. Response Execution

When a crash is detected:
- Response contract receives crash details
- Event is emitted for monitoring
- Emergency mode activated if warranted
- Historical record maintained

## Crash Types

| Type | Description | Threshold | Severity Metric |
|------|-------------|-----------|-----------------|
| GradualDecline | Sustained downward trend | >30% total drop | Total drop in BPS |
| FlashCrash | Sudden single-interval drop | >20% + outlier | Drop percentage in BPS |
| HighVolatility | Excessive price swings | >15% avg swing | Average volatility in BPS |

## Contract Addresses

### Hoodi Testnet

| Contract | Address |
|----------|---------|
| Response | `0x1c446Def189616AB89a10f538a9Aed89b7b2ecE5` |
| Trap | `0x15c08F2D5e8C23fA43926F1E5F698553202FAf85` |
| Primary Oracle | [Update after deployment] |
| Secondary Oracle | [Update after deployment] |

## Testing Crash Detection

### Simulate Flash Crash

```bash
# Drop oracle prices by 30%
cast send $PRIMARY_ORACLE_ADDRESS \
    "simulateCrash(address,uint256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    30 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

### Monitor Events

```bash
cast logs --follow \
    --address $RESPONSE_CONTRACT \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

## Development

### Project Structure

```
.
├── src/
│   ├── NFTFloorPriceCrashTrap.sol    # Main trap contract
│   ├── NFTFloorProtectionResponse.sol # Response contract
│   ├── MockPriceOracle.sol            # Test oracle
│   └── interfaces/
│       └── ITrap.sol                  # Drosera interface
├── script/
│   └── DeployNFTTrap.s.sol           # Deployment script
├── test/
│   └── NFTFloorPriceCrashTrap.t.sol  # Test suite
├── drosera.toml                       # Drosera configuration
└── foundry.toml                       # Foundry configuration
```

### Running Local Tests

```bash
# Test crash detection
forge test --match-test testDetectsFlashCrash -vvv

# Test oracle validation
forge test --match-test testRejectsOracleMismatch -vvv

# Test statistical analysis
forge test --match-test testDetectsGradualDecline -vvv
```

## Production Considerations

For mainnet deployment:

1. **Replace Mock Oracles**: Integrate with Reservoir, Floor Protocol, or Chainlink NFT oracles
2. **Collection-Specific Tuning**: Adjust thresholds based on historical volatility
3. **Multi-Collection Support**: Monitor multiple collections simultaneously
4. **Enhanced Responses**: Implement trading pauses, alerts, liquidity management
5. **Operator Security**: Use multisig for response contract ownership

## Security

- Oracles validated for freshness and agreement
- Statistical analysis reduces false positives
- No mutable state dependencies (shadow-fork compatible)
- Authorization checks on response contract
- Comprehensive test coverage

## Limitations

- Mock oracles for testnet (not production-grade price feeds)
- Single collection monitoring (expandable)
- Requires oracle maintenance (price updates)
- Block-based sampling (not real-time)

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

MIT License - see [LICENSE](./LICENSE) for details

## Resources

- [Drosera Documentation](https://docs.drosera.io)
- [Deployment Guide](./DEPLOYMENT_GUIDE.md)
- [Key Fixes Summary](./KEY_FIXES_SUMMARY.md)

## Acknowledgments

Built for the Drosera security network. Feedback and improvements from the Drosera community.

## Contact

- Discord: [albarika]
