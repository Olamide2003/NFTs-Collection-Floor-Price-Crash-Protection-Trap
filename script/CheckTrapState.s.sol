// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/NFTFloorPriceCrashTrap.sol";

contract CheckTrapStateScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Reference the deployed trap
        NFTFloorPriceCrashTrap trap = NFTFloorPriceCrashTrap(0xe12B581141f2e1B029F45920300DB648e0e355A2);

        console.log("Checking Trap State...");
        console.log("Trap Address:", address(trap));

        // Optional: call collect() safely
        try trap.collect() returns (bytes memory result) {
            console.log("Collect succeeded, bytes length:", result.length);
        } catch {
            console.log("Collect failed!");
        }

        vm.stopBroadcast();
    }
}
