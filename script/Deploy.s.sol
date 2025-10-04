// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {MockPriceOracle} from "../src/MockPriceOracle.sol";
import {NFTFloorPriceCrashTrap} from "../src/NFTFloorPriceCrashTrap.sol";
import {NFTFloorProtectionResponse} from "../src/NFTFloorProtectionResponse.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MockPriceOracle oracle = new MockPriceOracle();
        NFTFloorProtectionResponse response = new NFTFloorProtectionResponse();
        NFTFloorPriceCrashTrap trap = new NFTFloorPriceCrashTrap(address(oracle));

        console.log("Oracle deployed at:", address(oracle));
        console.log("Response deployed at:", address(response));
        console.log("Trap deployed at:", address(trap));

        vm.stopBroadcast();
    }
}
