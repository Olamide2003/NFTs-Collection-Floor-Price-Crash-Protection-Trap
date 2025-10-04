// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MockPriceOracle.sol";
import "../src/NFTFloorPriceCrashTrap.sol";

contract NFTFloorTrapTest is Test {
    MockPriceOracle oracle;
    NFTFloorPriceCrashTrap trap;
    address constant COLLECTION = address(0x1111111111111111111111111111111111111111);

    function setUp() public {
        oracle = new MockPriceOracle();
        trap = new NFTFloorPriceCrashTrap(address(oracle));
    }

    function testNoTriggerWhenStable() public {
        bytes memory snapOld = trap.collect(); // baseline
        vm.warp(block.timestamp + 600);
        bytes memory snapNew = trap.collect(); // same price
        bytes;
        arr[0] = snapNew;
        arr[1] = snapOld;
        (bool should, ) = trap.shouldRespond(arr);
        assertFalse(should, "should not trigger when stable");
    }

    function testTriggerOnCrash() public {
        bytes memory snapOld = trap.collect(); // baseline 50 ETH
        vm.warp(block.timestamp + 600);
        oracle.simulateCrash(COLLECTION, 40); // 40% drop -> should exceed 30% threshold
        bytes memory snapNew = trap.collect();
        bytes;
        arr[0] = snapNew;
        arr[1] = snapOld;
        (bool should, bytes memory payload) = trap.shouldRespond(arr);
        assertTrue(should, "should trigger on >=30% drop");

        ( , uint256 dropBps, , , , ) = abi.decode(payload, (address, uint256, uint256, uint256, uint256, bytes32));
        assertTrue(dropBps >= 3000);
    }
}
