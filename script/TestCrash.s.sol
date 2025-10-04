// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {NFTFloorPriceCrashTrap} from "../src/NFTFloorPriceCrashTrap.sol";
import {MockPriceOracle} from "../src/MockPriceOracle.sol";

/// @title TestCrash Script
/// @notice Simulates an NFT floor crash and tests the Trap
contract TestCrash is Script {
    // Replace with deployed addresses from Deploy.s.sol
    address constant ORACLE_ADDR = 0x1111111111111111111111111111111111111111;
    address constant TRAP_ADDR   = 0x2222222222222222222222222222222222222222;

    function run() external {
        console.log("=== Running Crash Simulation Test ===");

        // Attach to deployed contracts
        MockPriceOracle oracle = MockPriceOracle(ORACLE_ADDR);
        NFTFloorPriceCrashTrap trap = NFTFloorPriceCrashTrap(TRAP_ADDR);

        // 1. Simulate crash
        oracle.simulateCrash(
            0x1111111111111111111111111111111111111111,
            40
        );

        // 2. Collect two snapshots: newest (after crash) + older (baseline)
        bytes memory snapshot1 = trap.collect(); // after crash
        bytes memory snapshot2 = abi.encode(
            1,                                      // version
            0x1111111111111111111111111111111111111111, // collection
            50 ether,                               // baseline floor price
            block.timestamp - 100,                  // fake older timestamp
            bytes32("albarika")                     // reporter tag
        );

        // Declare the snapshots array (fixed size 2 for this test)
        bytes ;
        snapshots[0] = snapshot1; // newest
        snapshots[1] = snapshot2; // oldest

        // 3. Run shouldRespond
        (bool triggered, bytes memory response) = trap.shouldRespond(snapshots);

        if (triggered) {
            (
                address collection,
                uint256 dropBps,
                uint256 curFloorWei,
                uint256 baseFloorWei,
                uint256 ts,
                bytes32 reporter
            ) = abi.decode(response, (address, uint256, uint256, uint256, uint256, bytes32));

            console.log("Crash Detected");
            console.log("Collection:", collection);
            console.log("Drop (bps):", dropBps);
            console.log("Current Price (wei):", curFloorWei);
            console.log("Baseline Price (wei):", baseFloorWei);
            console.log("Timestamp:", ts);
            console.logBytes32(reporter);
        } else {
            console.log("No crash detected.");
        }
    }
}
