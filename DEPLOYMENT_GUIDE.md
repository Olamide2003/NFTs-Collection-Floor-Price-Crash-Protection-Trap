# NFT Floor Price Crash Trap - Deployment Guide

Complete step-by-step guide to deploy your NFT trap to Drosera on Hoodi Testnet.

## Prerequisites

1. **Foundry installed**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Drosera CLI installed**
   ```bash
   curl -L https://install.drosera.io | bash
   ```

3. **Testnet ETH on Hoodi**
   - Get testnet ETH from faucet
   - Ensure your wallet has sufficient balance

4. **Environment variables set**
   ```bash
   export PRIVATE_KEY=0xYOUR_PRIVATE_KEY
   ```

## Step-by-Step Deployment

### Step 1: Update Discord Name

Open `src/NFTFloorPriceCrashTrap.sol` and replace the Discord name:

```solidity
string constant DISCORD_NAME = "your_actual_discord_username";
```

### Step 2: Compile Contracts

```bash
forge build
```

Ensure compilation succeeds with no errors.

### Step 3: Run Tests

```bash
forge test -vv
```

All tests should pass. This validates your trap logic.

### Step 4: Deploy Contracts

Run the deployment script:

```bash
forge script script/DeployNFTTrap.s.sol \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --broadcast \
    --private-key $PRIVATE_KEY
```

**IMPORTANT**: Save all deployed addresses from the output:
- Primary Oracle address
- Secondary Oracle address
- Response Contract address
- Trap Contract address

### Step 5: Update Oracle Addresses in Trap Contract

Open `src/NFTFloorPriceCrashTrap.sol` and update these constants with your deployed oracle addresses:

```solidity
IAggregatorV3Interface public constant PRIMARY_ORACLE = IAggregatorV3Interface(0xYOUR_PRIMARY_ORACLE_ADDRESS);
IAggregatorV3Interface public constant SECONDARY_ORACLE = IAggregatorV3Interface(0xYOUR_SECONDARY_ORACLE_ADDRESS);
```

### Step 6: Recompile and Redeploy Trap

After updating oracle addresses:

```bash
# Recompile
forge build

# Redeploy just the trap
forge create src/NFTFloorPriceCrashTrap.sol:NFTFloorPriceCrashTrap \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

Save the new trap contract address.

### Step 7: Authorize New Trap on Response Contract

```bash
cast send YOUR_RESPONSE_CONTRACT_ADDRESS \
    "authorizeTrap(address)" \
    YOUR_NEW_TRAP_CONTRACT_ADDRESS \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

### Step 8: Update drosera.toml

Edit `drosera.toml` and fill in your deployed addresses:

```toml
[network]
private_key = "0xYOUR_PRIVATE_KEY"

[traps.nft_floor_crash]
response_contract = "0xYOUR_RESPONSE_CONTRACT_ADDRESS"
address = "0xYOUR_TRAP_CONTRACT_ADDRESS"
```

### Step 9: Test with Drosera Dryrun

```bash
drosera dryrun
```

This should succeed without errors. If you get errors:
- Check oracle addresses are correct
- Verify response_function signature matches
- Ensure all contracts are deployed

### Step 10: Deploy to Drosera Network

```bash
drosera apply
```

If this succeeds, your trap is now live on Drosera!

## Verification Steps

### 1. Check Trap Registration

```bash
cast call 0x91cB447BaFc6e0EA0F4Fe056F5a9b1F14bb06e5D \
    "gettrap(address)" \
    YOUR_TRAP_CONTRACT_ADDRESS \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

### 2. Test Data Collection

```bash
cast call YOUR_TRAP_CONTRACT_ADDRESS \
    "collect()" \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

Should return encoded data without reverting.

### 3. Verify Oracle Prices

```bash
# Check primary oracle
cast call YOUR_PRIMARY_ORACLE_ADDRESS \
    "latestRoundData()" \
    --rpc-url https://rpc.hoodi.ethpandaops.io

# Check secondary oracle
cast call YOUR_SECONDARY_ORACLE_ADDRESS \
    "latestRoundData()" \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

## Testing Crash Detection

### Simulate Flash Crash (30% drop)

```bash
# Drop primary oracle price by 30%
cast send YOUR_PRIMARY_ORACLE_ADDRESS \
    "simulateCrash(address,uint256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    30 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY

# Drop secondary oracle price by 30%
cast send YOUR_SECONDARY_ORACLE_ADDRESS \
    "simulateCrash(address,uint256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    30 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

Wait 20 blocks (~4 minutes), then check if the trap triggered by looking for events.

### Check for Crash Detection Events

```bash
# Check response contract for CrashDetected events
cast logs --from-block latest:1000 \
    --address YOUR_RESPONSE_CONTRACT_ADDRESS \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

### Reset Prices After Testing

```bash
# Reset primary oracle to baseline (8.45 ETH)
cast send YOUR_PRIMARY_ORACLE_ADDRESS \
    "resetPrice(address,int256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    8450000000000000000 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY

# Reset secondary oracle to baseline
cast send YOUR_SECONDARY_ORACLE_ADDRESS \
    "resetPrice(address,int256)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    8450000000000000000 \
    --rpc-url https://rpc.hoodi.ethpandaops.io \
    --private-key $PRIVATE_KEY
```

## Common Issues and Solutions

### Issue 1: "Oracle mismatch" error during collect()

**Cause**: Primary and secondary oracle prices diverge by more than 1%

**Solution**: Ensure both oracles have similar prices
```bash
# Check both oracle prices
cast call YOUR_PRIMARY_ORACLE_ADDRESS "latestRoundData()" --rpc-url https://rpc.hoodi.ethpandaops.io
cast call YOUR_SECONDARY_ORACLE_ADDRESS "latestRoundData()" --rpc-url https://rpc.hoodi.ethpandaops.io

# Update both to same price
cast send YOUR_PRIMARY_ORACLE_ADDRESS "setPrice(address,int256)" 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D 8450000000000000000 --rpc-url https://rpc.hoodi.ethpandaops.io --private-key $PRIVATE_KEY
cast send YOUR_SECONDARY_ORACLE_ADDRESS "setPrice(address,int256)" 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D 8450000000000000000 --rpc-url https://rpc.hoodi.ethpandaops.io --private-key $PRIVATE_KEY
```

### Issue 2: "Stale primary oracle" error

**Cause**: Oracle hasn't been updated recently (> 1 hour old)

**Solution**: Update oracle prices
```bash
cast send YOUR_PRIMARY_ORACLE_ADDRESS "setPrice(address,int256)" 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D 8450000000000000000 --rpc-url https://rpc.hoodi.ethpandaops.io --private-key $PRIVATE_KEY
```

### Issue 3: drosera apply fails with function signature error

**Cause**: Response function signature in drosera.toml doesn't match encoded data

**Solution**: Verify the signature includes all 7 parameters in correct order:
```toml
response_function = "respondToCrash(string,address,uint256,uint256,uint8,uint256,uint256)"
```

### Issue 4: Trap doesn't trigger even with large price drops

**Possible causes**:
1. Not enough data points collected (need at least 3)
2. Price drop doesn't meet threshold (20% for flash crash, 30% for gradual decline)
3. Cooldown period still active

**Solution**: 
- Wait for more blocks to collect sufficient data
- Simulate larger price drops (40-50%)
- Check cooldown period hasn't been triggered recently

### Issue 5: drosera dryrun works but drosera apply fails

**Cause**: Oracle contracts aren't actually deployed or addresses are wrong

**Solution**: 
1. Verify oracle contracts are deployed:
   ```bash
   cast code YOUR_PRIMARY_ORACLE_ADDRESS --rpc-url https://rpc.hoodi.ethpandaops.io
   ```
2. Update oracle addresses in trap contract and redeploy
3. Re-authorize the new trap contract on response contract

## Monitoring Your Trap

### Check Trap Status

```bash
# Get trap configuration from Drosera
drosera list

# Check response contract stats
cast call YOUR_RESPONSE_CONTRACT_ADDRESS \
    "getStats(address)" \
    0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

### Monitor Events

Set up event monitoring to catch crashes in real-time:

```bash
# Watch for CrashDetected events
cast logs --follow \
    --address YOUR_RESPONSE_CONTRACT_ADDRESS \
    --rpc-url https://rpc.hoodi.ethpandaops.io
```

## Key Differences from Block Anomaly Trap

Your NFT trap has additional complexity compared to the working reference trap:

1. **External Dependencies**: Requires oracle contracts to be deployed first
2. **Oracle Validation**: Must ensure oracles agree within 1% tolerance
3. **Staleness Checks**: Oracle data must be fresh (< 1 hour old)
4. **More Parameters**: Response function has 7 parameters vs 6 in reference trap
5. **Collection Address**: Must match across all data points

The reference trap works immediately because it only uses block timestamps and numbers (always available). Your trap requires careful setup of oracle infrastructure.

## Production Deployment Notes

For mainnet or production deployment:

1. **Replace Mock Oracles**: Use real Chainlink oracles or reservoir.tools NFT oracles
2. **Update Collection Address**: Use the actual NFT collection you want to monitor
3. **Adjust Thresholds**: Tune crash detection thresholds based on collection volatility
4. **Increase Operators**: Use 3-5 operators for better security
5. **Test Thoroughly**: Run on testnet for at least 1 week before mainnet
6. **Monitor Closely**: Watch for false positives and adjust parameters

## Support

If you encounter issues:

1. Check Drosera documentation: https://docs.drosera.io
2. Join Drosera Discord for support
3. Review the working reference trap for comparison
4. Ensure all contract addresses are correct in drosera.toml

## Summary Checklist

- [ ] Updated Discord name in trap contract
- [ ] Compiled contracts successfully
- [ ] All tests passing
- [ ] Deployed mock oracles
- [ ] Updated oracle addresses in trap contract
- [ ] Redeployed trap with correct oracle addresses
- [ ] Authorized trap on response contract
- [ ] Updated drosera.toml with all addresses
- [ ] drosera dryrun successful
- [ ] drosera apply successful
- [ ] Tested crash simulation
- [ ] Verified events emitted correctly

Your trap is now live and monitoring NFT floor prices!
