# Quick Start Guide

Get your NFT Floor Price Crash Trap deployed in 10 minutes.

## Prerequisites

```bash
# Verify installations
forge --version
drosera --version
git --version

# Set private key
export PRIVATE_KEY=0xYOUR_PRIVATE_KEY
```

## Step 1: Update Configuration (2 min)

```bash
# Update Discord name
nano src/NFTFloorPriceCrashTrap.sol
# Line 12: Change "your_discord_here" to your Discord username

# Update your info in README
nano README.md
# Replace [your_discord_username] and [@yourusername]
```

## Step 2: Build & Test (1 min)

```bash
forge build
forge test
```

## Step 3: Deploy Oracles (2 min)

```bash
forge script script/DeployNFTTrap.s.sol \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --broadcast \
    --private-key $PRIVATE_KEY
```

Save the oracle addresses from output.

## Step 4: Update Trap with Oracle Addresses (2 min)

```bash
nano src/NFTFloorPriceCrashTrap.sol
# Lines 32-35: Add your deployed oracle addresses

# Rebuild
forge build

# Redeploy just the trap
forge create src/NFTFloorPriceCrashTrap.sol:NFTFloorPriceCrashTrap \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

## Step 5: Configure Drosera (2 min)

```bash
# Update drosera.toml with your trap address
nano drosera.toml

# Test
drosera dryrun

# Deploy
drosera apply
```

## Verify

```bash
# Check registration
drosera list

# Test collection
cast call YOUR_TRAP_ADDRESS "collect()" \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

## Test Crash

```bash
# Crash both oracles by 30%
cast send YOUR_PRIMARY_ORACLE \
    "simulateCrash(address,uint256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D 30 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY

# Wait 4 minutes, check for events
cast logs --address 0x1c446Def189616AB89a10f538a9Aed89b7b2ecE5 \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

Done!
