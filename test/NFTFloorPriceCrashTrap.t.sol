// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTFloorPriceCrashTrap} from "../src/NFTFloorPriceCrashTrap.sol";
import {MockPriceOracle} from "../src/MockPriceOracle.sol";

/**
 * @title Tests for NFT Floor Price Crash Trap
 * @notice Comprehensive test suite for crash detection logic
 */
contract NFTFloorPriceCrashTrapTest is Test {
    NFTFloorPriceCrashTrap public trap;
    MockPriceOracle public primaryOracle;
    MockPriceOracle public secondaryOracle;
    
    address constant COLLECTION = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    string constant DISCORD = "albarika";
    
    function setUp() public {
        // Deploy oracles
        primaryOracle = new MockPriceOracle();
        secondaryOracle = new MockPriceOracle();
        
        // Set initial prices (8.45 ETH)
        primaryOracle.setPrice(COLLECTION, 8450000000000000000);
        secondaryOracle.setPrice(COLLECTION, 8450000000000000000);
        
        // Deploy trap (NOTE: In real deployment, update oracle addresses in contract)
        trap = new NFTFloorPriceCrashTrap();
        
        // Advance time to ensure oracle data is fresh
        vm.warp(block.timestamp + 1);
    }
    
    function testCollectReturnsValidData() public {
        vm.warp(block.timestamp + 1000);
        
        primaryOracle.setPrice(COLLECTION, 8450000000000000000);
        secondaryOracle.setPrice(COLLECTION, 8450000000000000000);
        
        bytes memory data = trap.collect();
        (uint256 version, uint256 price, uint256 timestamp, address collection, string memory discord) = 
            abi.decode(data, (uint256, uint256, uint256, address, string));
        
        assertEq(version, 1);
        assertTrue(price > 0);
        assertTrue(timestamp > 0);
        assertEq(collection, COLLECTION);
        assertTrue(bytes(discord).length > 0);
    }
    
    function testShouldNotRespondWithInsufficientData() public {
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encode(1, 8450000000000000000, block.timestamp, COLLECTION, DISCORD);
        data[1] = abi.encode(1, 8450000000000000000, block.timestamp - 60, COLLECTION, DISCORD);
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testDetectsFlashCrash() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        vm.warp(baseTime);
        
        // Simulate 40% flash crash
        data[0] = abi.encode(1, 6000000000000000000, baseTime, COLLECTION, DISCORD); // 6 ETH
        data[1] = abi.encode(1, 10000000000000000000, baseTime - 60, COLLECTION, DISCORD); // 10 ETH
        data[2] = abi.encode(1, 10000000000000000000, baseTime - 120, COLLECTION, DISCORD); // 10 ETH
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        
        assertTrue(shouldRespond);
        
        (, , , , uint8 crashType, , uint256 severity) = 
            abi.decode(response, (string, address, uint256, uint256, uint8, uint256, uint256));
        
        assertEq(crashType, 2); // FlashCrash
        assertEq(severity, 4000); // 40% drop
    }
    
    function testDetectsGradualDecline() public {
        bytes[] memory data = new bytes[](4);
        uint256 baseTime = block.timestamp + 1000;
        vm.warp(baseTime);
        
        // Simulate gradual 35% decline
        data[0] = abi.encode(1, 6500000000000000000, baseTime, COLLECTION, DISCORD); // 6.5 ETH
        data[1] = abi.encode(1, 8000000000000000000, baseTime - 60, COLLECTION, DISCORD); // 8 ETH
        data[2] = abi.encode(1, 9000000000000000000, baseTime - 120, COLLECTION, DISCORD); // 9 ETH
        data[3] = abi.encode(1, 10000000000000000000, baseTime - 180, COLLECTION, DISCORD); // 10 ETH
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        
        assertTrue(shouldRespond);
        
        (, , , , uint8 crashType, ,) = 
            abi.decode(response, (string, address, uint256, uint256, uint8, uint256, uint256));
        
        assertEq(crashType, 1); // GradualDecline
    }
    
    function testDetectsHighVolatility() public {
        bytes[] memory data = new bytes[](4);
        uint256 baseTime = block.timestamp + 1000;
        vm.warp(baseTime);
        
        // Simulate high volatility with large swings
        data[0] = abi.encode(1, 11000000000000000000, baseTime, COLLECTION, DISCORD); // 11 ETH
        data[1] = abi.encode(1, 9000000000000000000, baseTime - 60, COLLECTION, DISCORD); // 9 ETH
        data[2] = abi.encode(1, 12000000000000000000, baseTime - 120, COLLECTION, DISCORD); // 12 ETH
        data[3] = abi.encode(1, 10000000000000000000, baseTime - 180, COLLECTION, DISCORD); // 10 ETH
        
        (bool shouldRespond, bytes memory response) = trap.shouldRespond(data);
        
        assertTrue(shouldRespond);
        
        (, , , , uint8 crashType, ,) = 
            abi.decode(response, (string, address, uint256, uint256, uint8, uint256, uint256));
        
        assertEq(crashType, 3); // HighVolatility
    }
    
    function testNormalPriceDoesNotTrigger() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        vm.warp(baseTime);
        
        // Normal price fluctuations (< 5%)
        data[0] = abi.encode(1, 9900000000000000000, baseTime, COLLECTION, DISCORD); // 9.9 ETH
        data[1] = abi.encode(1, 10000000000000000000, baseTime - 60, COLLECTION, DISCORD); // 10 ETH
        data[2] = abi.encode(1, 10100000000000000000, baseTime - 120, COLLECTION, DISCORD); // 10.1 ETH
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testRejectsInvalidVersions() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        
        // Invalid version in first data point
        data[0] = abi.encode(2, 6000000000000000000, baseTime, COLLECTION, DISCORD); // Wrong version
        data[1] = abi.encode(1, 10000000000000000000, baseTime - 60, COLLECTION, DISCORD);
        data[2] = abi.encode(1, 10000000000000000000, baseTime - 120, COLLECTION, DISCORD);
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testRejectsEmptyDiscordName() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        
        data[0] = abi.encode(1, 6000000000000000000, baseTime, COLLECTION, ""); // Empty Discord
        data[1] = abi.encode(1, 10000000000000000000, baseTime - 60, COLLECTION, DISCORD);
        data[2] = abi.encode(1, 10000000000000000000, baseTime - 120, COLLECTION, DISCORD);
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testRejectsIncorrectTimeOrder() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        
        // Timestamps not in descending order
        data[0] = abi.encode(1, 6000000000000000000, baseTime - 60, COLLECTION, DISCORD); // Wrong order
        data[1] = abi.encode(1, 10000000000000000000, baseTime, COLLECTION, DISCORD);
        data[2] = abi.encode(1, 10000000000000000000, baseTime - 120, COLLECTION, DISCORD);
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testRejectsMismatchedCollections() public {
        bytes[] memory data = new bytes[](3);
        uint256 baseTime = block.timestamp + 1000;
        
        // Different collection in first data point
        data[0] = abi.encode(1, 6000000000000000000, baseTime, address(0x1111), DISCORD);
        data[1] = abi.encode(1, 10000000000000000000, baseTime - 60, COLLECTION, DISCORD);
        data[2] = abi.encode(1, 10000000000000000000, baseTime - 120, COLLECTION, DISCORD);
        
        (bool shouldRespond,) = trap.shouldRespond(data);
        assertFalse(shouldRespond);
    }
    
    function testRejectsOracleMismatch() public {
        primaryOracle.setPrice(COLLECTION, 8450000000000000000); // 8.45 ETH
        secondaryOracle.setPrice(COLLECTION, 10140000000000000000); // 10.14 ETH (20% divergence)
        
        vm.expectRevert("Oracle mismatch");
        trap.collect();
    }
    
    function testRejectsStaleOracle() public {
        primaryOracle.setPrice(COLLECTION, 8450000000000000000);
        secondaryOracle.setPrice(COLLECTION, 8450000000000000000);
        
        // Advance time beyond 1 hour stale threshold
        vm.warp(block.timestamp + 7200);
        
        vm.expectRevert("Stale primary oracle");
        trap.collect();
    }
    
    function testGetConfigReturnsCorrectValues() public {
        (
            uint256 normal,
            uint256 max,
            uint256 min,
            uint256 vol,
            uint256 div
        ) = trap.getConfig();
        
        assertEq(normal, 500); // 5%
        assertEq(max, 3000); // 30%
        assertEq(min, 2000); // 20%
        assertEq(vol, 1500); // 15%
        assertEq(div, 100); // 1%
    }
    
    function testGetCrashDescriptions() public {
        assertEq(
            trap.getCrashDescription(1),
            "Gradual price decline detected - potential sell-off"
        );
        assertEq(
            trap.getCrashDescription(2),
            "Flash price crash detected - possible dump"
        );
        assertEq(
            trap.getCrashDescription(3),
            "High price volatility detected - unstable market"
        );
        assertEq(
            trap.getCrashDescription(4),
            "Potential price manipulation detected"
        );
        assertEq(
            trap.getCrashDescription(0),
            "No crash detected"
        );
    }
    
    function testGetDiscordName() public {
        string memory discord = trap.getDiscordName();
        assertTrue(bytes(discord).length > 0);
    }
}
