// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {NFTFloorPriceCrashTrap} from "../src/NFTFloorPriceCrashTrap.sol";
import {MockNFTMarketplace} from "../src/MockNFTMarketplace.sol";

contract FixCollectionsScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Update with new addresses after redeployment
        MockNFTMarketplace marketplace = MockNFTMarketplace(0x8cE3C6aB7b598885692c3951AE3AB60dA6D11854);
        NFTFloorPriceCrashTrap trap = NFTFloorPriceCrashTrap(0xe12B581141f2e1B029F45920300DB648e0e355A2);

        console.log("Setting marketplace...");
        trap.setMarketplace(address(marketplace));
        console.log("Marketplace set to:", address(marketplace));

        console.log("Creating sample collections...");
        marketplace.createSampleCollections();

        console.log("Adding collections to trap...");
        trap.addCollection(0x1111111111111111111111111111111111111111);
        console.log("Added collection:", 0x1111111111111111111111111111111111111111);
        trap.addCollection(0x2222222222222222222222222222222222222222);
        console.log("Added collection:", 0x2222222222222222222222222222222222222222);
        trap.addCollection(0x3333333333333333333333333333333333333333);
        console.log("Added collection:", 0x3333333333333333333333333333333333333333);

        console.log("Updating collection data...");
        trap.updateCollectionData();

        vm.stopBroadcast();
    }
}
