// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFTFloorProtectionResponse} from "../src/NFTFloorProtectionResponse.sol";
import {NFTFloorPriceCrashTrap} from "../src/NFTFloorPriceCrashTrap.sol";
import {MockPriceOracle} from "../src/MockPriceOracle.sol";

/**
 * @title Deployment Script for NFT Floor Price Crash Trap
 * @notice Complete deployment for Hoodi Testnet
 */
contract DeployNFTTrap is Script {
    
    function run() external {
        // Get deployer private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=================================================");
        console.log("NFT Floor Price Crash Trap Deployment");
        console.log("=================================================");
        console.log("Deploying with address:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Step 1: Deploy Mock Oracles
        console.log("Step 1: Deploying Primary Mock Oracle...");
        MockPriceOracle primaryOracle = new MockPriceOracle();
        console.log("Primary Oracle deployed at:", address(primaryOracle));
        
        console.log("Step 2: Deploying Secondary Mock Oracle...");
        MockPriceOracle secondaryOracle = new MockPriceOracle();
        console.log("Secondary Oracle deployed at:", address(secondaryOracle));
        console.log("");
        
        // Step 3: Deploy Response Contract
        console.log("Step 3: Deploying NFTFloorProtectionResponse...");
        NFTFloorProtectionResponse responseContract = new NFTFloorProtectionResponse();
        console.log("Response Contract deployed at:", address(responseContract));
        console.log("");
        
        // Step 4: Deploy Trap Contract
        // NOTE: You MUST manually update the oracle addresses in NFTFloorPriceCrashTrap.sol
        // before deploying with the addresses printed above
        console.log("Step 4: Deploying NFTFloorPriceCrashTrap...");
        console.log("WARNING: Ensure oracle addresses in trap contract match:");
        console.log("  PRIMARY_ORACLE =", address(primaryOracle));
        console.log("  SECONDARY_ORACLE =", address(secondaryOracle));
        
        NFTFloorPriceCrashTrap trapContract = new NFTFloorPriceCrashTrap();
        console.log("Trap Contract deployed at:", address(trapContract));
        console.log("");
        
        // Step 5: Authorize trap on response contract
        console.log("Step 5: Authorizing trap on response contract...");
        responseContract.authorizeTrap(address(trapContract));
        console.log("Trap authorized successfully");
        console.log("");
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console.log("=================================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("=================================================");
        console.log("Network: Hoodi Testnet (Chain ID: 560048)");
        console.log("Deployer:", deployer);
        console.log("");
        console.log("Deployed Contracts:");
        console.log("  Primary Oracle:    ", address(primaryOracle));
        console.log("  Secondary Oracle:  ", address(secondaryOracle));
        console.log("  Response Contract: ", address(responseContract));
        console.log("  Trap Contract:     ", address(trapContract));
        console.log("");
        
        // Print next steps
        console.log("=================================================");
        console.log("NEXT STEPS");
        console.log("=================================================");
        console.log("1. Update drosera.toml:");
        console.log("   response_contract = \"%s\"", vm.toString(address(responseContract)));
        console.log("   address = \"%s\"", vm.toString(address(trapContract)));
        console.log("");
        console.log("2. Deploy to Drosera:");
        console.log("   drosera apply");
        console.log("");
        console.log("3. Test the trap:");
        console.log("   drosera dryrun");
        console.log("");
        console.log("4. Simulate a crash (optional):");
        console.log("   cast send %s \"simulateCrash(address,uint256)\" 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D 30 --rpc-url https://rpc.hoodi.ethpandaops.io --private-key $PRIVATE_KEY", address(primaryOracle));
        console.log("=================================================");
    }
}
