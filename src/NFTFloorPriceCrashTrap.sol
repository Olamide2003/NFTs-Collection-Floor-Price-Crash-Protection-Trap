// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

/**
 * @title NFT Floor Price Crash Detector
 * @notice Detects significant price drops in NFT collections using dual oracle validation
 * @dev Monitors floor prices and detects crashes, gradual declines, and high volatility
 */
contract NFTFloorPriceCrashTrap is ITrap {
    
    // ============= CONFIGURATION =============
    
    /// @notice Discord username for identification - REPLACE WITH YOUR DISCORD
    string constant DISCORD_NAME = "albarika";
    
    /// @notice Data version for compatibility
    uint256 constant VERSION = 1;
    
    /// @notice Normal acceptable drop threshold (5%)
    uint256 constant NORMAL_DROP_BPS = 500;
    
    /// @notice Maximum drop threshold for gradual decline (30%)
    uint256 constant MAX_DROP_BPS = 3000;
    
    /// @notice Minimum drop threshold for flash crash (20%)
    uint256 constant MIN_DROP_BPS = 2000;
    
    /// @notice Volatility threshold for instability detection (15%)
    uint256 constant VOLATILITY_THRESHOLD_BPS = 1500;
    
    /// @notice Maximum allowed divergence between oracles (1%)
    uint256 public constant MAX_ORACLE_DIVERGENCE_BPS = 100;
    
    /// @notice NFT collection address to monitor (BAYC example - update for real deployment)
    address public constant COLLECTION = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
    
    /// @notice Primary price oracle address - UPDATE AFTER DEPLOYING MockPriceOracle
    IAggregatorV3Interface public constant PRIMARY_ORACLE = IAggregatorV3Interface(0x2755fa1e21F7Cb1055CD1a391d6b86E11EEFC910);
    
    /// @notice Secondary price oracle address - UPDATE AFTER DEPLOYING MockPriceOracle
    IAggregatorV3Interface public constant SECONDARY_ORACLE = IAggregatorV3Interface(0x3a8038854bE1A6237260Ce95E8C32913d19306BF);
    
    // ============= ENUMS =============
    
    /// @notice Types of price crash patterns
    enum CrashType {
        None,              // No crash detected
        GradualDecline,    // Steady decline over time (>30% total)
        FlashCrash,        // Sudden drop (>20% in one interval)
        HighVolatility,    // High price swings (>15% average)
        Manipulation       // Reserved for future use
    }
    
    // ============= STRUCTS =============
    
    /// @notice Data point structure for collected price data
    struct DataPoint {
        uint256 version;
        uint256 price;
        uint256 timestamp;
        address collection;
        string discordName;
    }
    
    // ============= MAIN FUNCTIONS =============
    
    /**
     * @notice Collects current floor price data from dual oracles
     * @return Encoded data containing version, price, timestamp, collection, and Discord name
     */
    function collect() external view returns (bytes memory) {
        // Fetch data from both oracles
        (, int256 price1,, uint256 updatedAt1,) = PRIMARY_ORACLE.latestRoundData();
        (, int256 price2,, uint256 updatedAt2,) = SECONDARY_ORACLE.latestRoundData();
        
        // Validate oracle data
        require(price1 > 0, "Invalid primary oracle price");
        require(price2 > 0, "Invalid secondary oracle price");
        require(updatedAt1 > 0 && updatedAt1 >= block.timestamp - 3600, "Stale primary oracle");
        require(updatedAt2 > 0 && updatedAt2 >= block.timestamp - 3600, "Stale secondary oracle");
        
        // Convert to unsigned integers
        uint256 uPrice1 = uint256(price1);
        uint256 uPrice2 = uint256(price2);
        
        // Ensure oracles agree within tolerance
        require(_oraclesAgree(uPrice1, uPrice2), "Oracle mismatch");
        
        // Use average of both oracles
        uint256 averagePrice = (uPrice1 + uPrice2) / 2;
        
        return abi.encode(
            VERSION,
            averagePrice,
            block.timestamp,
            COLLECTION,
            DISCORD_NAME
        );
    }
    
    /**
     * @notice Analyzes collected price data to detect crashes
     * @param data Array of collected data from recent blocks (requires minimum 3 blocks)
     * @return shouldTrigger True if crash detected
     * @return responseData Encoded response data for the response contract
     */
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory) {
        if (data.length < 3) return (false, bytes(""));
        
        // Decode the three most recent data points
        DataPoint memory point1;
        DataPoint memory point2;
        DataPoint memory point3;
        
        (point1.version, point1.price, point1.timestamp, point1.collection, point1.discordName) = 
            abi.decode(data[0], (uint256, uint256, uint256, address, string));
        (point2.version, point2.price, point2.timestamp, point2.collection, ) = 
            abi.decode(data[1], (uint256, uint256, uint256, address, string));
        (point3.version, point3.price, point3.timestamp, point3.collection, ) = 
            abi.decode(data[2], (uint256, uint256, uint256, address, string));
        
        // Validate data integrity
        if (!_isValidData(point1, point2, point3)) {
            return (false, bytes(""));
        }
        
        // Detect crash type and severity
        (CrashType crashType, uint256 severity) = _detectCrashType(data);
        
        // If crash detected, prepare response data
        if (crashType != CrashType.None) {
            bytes memory responseData = abi.encode(
                point1.discordName,
                point1.collection,
                point1.price,
                point3.price,
                uint8(crashType),
                point1.timestamp,
                severity
            );
            return (true, responseData);
        }
        
        return (false, bytes(""));
    }
    
    // ============= INTERNAL VALIDATION FUNCTIONS =============
    
    /**
     * @notice Validates the integrity of collected data points
     * @param point1 Most recent data point
     * @param point2 Middle data point
     * @param point3 Oldest data point
     * @return isValid True if data passes all validation checks
     */
    function _isValidData(
        DataPoint memory point1,
        DataPoint memory point2,
        DataPoint memory point3
    ) internal pure returns (bool) {
        // Check versions match
        if (point1.version != VERSION || point2.version != VERSION || point3.version != VERSION) {
            return false;
        }
        
        // Check Discord name exists
        if (bytes(point1.discordName).length == 0) {
            return false;
        }
        
        // Check all monitoring same collection
        if (point1.collection != point2.collection || point2.collection != point3.collection) {
            return false;
        }
        
        // Check timestamps in correct order (newest first)
        if (point1.timestamp <= point2.timestamp || point2.timestamp <= point3.timestamp) {
            return false;
        }
        
        // Check minimum time span (at least 60 seconds)
        if (point1.timestamp - point3.timestamp < 60) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @notice Checks if two oracle prices agree within acceptable divergence
     * @param price1 Price from first oracle
     * @param price2 Price from second oracle
     * @return agree True if prices are within MAX_ORACLE_DIVERGENCE_BPS
     */
    function _oraclesAgree(uint256 price1, uint256 price2) internal pure returns (bool) {
        if (price1 == 0 || price2 == 0) return false;
        
        uint256 higher = price1 > price2 ? price1 : price2;
        uint256 lower = price1 < price2 ? price1 : price2;
        uint256 divergence = higher - lower;
        
        if (divergence > higher) return false; // Overflow check
        
        uint256 divergenceBps = (divergence * 10000) / higher;
        return divergenceBps <= MAX_ORACLE_DIVERGENCE_BPS;
    }
    
    // ============= INTERNAL DETECTION FUNCTIONS =============
    
    /**
     * @notice Calculate price drop in basis points
     * @param currentPrice Current price
     * @param baselinePrice Baseline (earlier) price
     * @return dropBps Drop percentage in basis points (100 bps = 1%)
     */
    function _calculateDropBps(uint256 currentPrice, uint256 baselinePrice) internal pure returns (uint256) {
        if (baselinePrice == 0 || currentPrice >= baselinePrice) return 0;
        uint256 drop = baselinePrice - currentPrice;
        return (drop * 10000) / baselinePrice;
    }
    
    /**
     * @notice Detect crash type and severity from price data
     * @param data Array of collected price data
     * @return crashType Type of crash detected
     * @return severity Severity metric (drop percentage or volatility)
     */
    function _detectCrashType(bytes[] calldata data) internal pure returns (CrashType, uint256 severity) {
        uint256 length = data.length;
        uint256[] memory prices = new uint256[](length);
        
        // Extract prices
        for (uint256 i = 0; i < length; i++) {
            (, prices[i],,,) = abi.decode(data[i], (uint256, uint256, uint256, address, string));
        }
        
        // Calculate mean for statistical analysis
        uint256 mean = 0;
        for (uint256 i = 0; i < length; i++) {
            mean += prices[i];
        }
        mean /= length;
        
        // Calculate standard deviation
        uint256 variance = 0;
        for (uint256 i = 0; i < length; i++) {
            uint256 diff = prices[i] > mean ? prices[i] - mean : mean - prices[i];
            variance += diff * diff;
        }
        variance /= length;
        uint256 stddev = _sqrt(variance);
        
        // Pattern 1: Flash Crash Detection
        // Check for sudden drop >20% in single interval + price below 2 std dev
        for (uint256 i = 0; i < length - 1; i++) {
            uint256 dropBps = _calculateDropBps(prices[i], prices[i + 1]);
            if (dropBps >= MIN_DROP_BPS && prices[i] < mean - (2 * stddev)) {
                return (CrashType.FlashCrash, dropBps);
            }
        }
        
        // Pattern 2: Gradual Decline Detection
        // Check for consistent downward trend with >30% total drop
        bool allDecreasing = true;
        for (uint256 i = 0; i < length - 1; i++) {
            if (prices[i] >= prices[i + 1]) {
                allDecreasing = false;
                break;
            }
        }
        if (allDecreasing) {
            uint256 totalDropBps = _calculateDropBps(prices[0], prices[length - 1]);
            if (totalDropBps >= MAX_DROP_BPS && prices[0] < mean - (2 * stddev)) {
                return (CrashType.GradualDecline, totalDropBps);
            }
        }
        
        // Pattern 3: High Volatility Detection
        // Check for excessive price swings
        uint256 volatility = _calculateVolatility(prices);
        if (volatility >= VOLATILITY_THRESHOLD_BPS) {
            return (CrashType.HighVolatility, volatility);
        }
        
        return (CrashType.None, 0);
    }
    
    /**
     * @notice Calculate price volatility metric
     * @param prices Array of prices
     * @return volatility Average swing percentage in basis points
     */
    function _calculateVolatility(uint256[] memory prices) internal pure returns (uint256) {
        uint256 length = prices.length;
        if (length < 2) return 0;
        
        uint256 totalSwing = 0;
        for (uint256 i = 0; i < length - 1; i++) {
            uint256 swing = prices[i] > prices[i + 1] 
                ? prices[i] - prices[i + 1] 
                : prices[i + 1] - prices[i];
            totalSwing += (swing * 10000) / prices[i];
        }
        
        return totalSwing / (length - 1);
    }
    
    /**
     * @notice Calculate integer square root
     * @param x Input value
     * @return y Square root of x
     */
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
    
    // ============= VIEW FUNCTIONS =============
    
    /**
     * @notice Get current configuration parameters
     * @return normalDropBps Normal drop threshold
     * @return maxDropBps Maximum drop threshold
     * @return minDropBps Minimum crash threshold
     * @return volatilityThresholdBps Volatility threshold
     * @return maxDivergenceBps Maximum oracle divergence
     */
    function getConfig() external pure returns (
        uint256 normalDropBps,
        uint256 maxDropBps,
        uint256 minDropBps,
        uint256 volatilityThresholdBps,
        uint256 maxDivergenceBps
    ) {
        return (
            NORMAL_DROP_BPS,
            MAX_DROP_BPS,
            MIN_DROP_BPS,
            VOLATILITY_THRESHOLD_BPS,
            MAX_ORACLE_DIVERGENCE_BPS
        );
    }
    
    /**
     * @notice Get human-readable description for crash type
     * @param crashType Numeric crash type
     * @return description Human-readable description
     */
    function getCrashDescription(uint8 crashType) external pure returns (string memory) {
        if (crashType == 1) return "Gradual price decline detected - potential sell-off";
        if (crashType == 2) return "Flash price crash detected - possible dump";
        if (crashType == 3) return "High price volatility detected - unstable market";
        if (crashType == 4) return "Potential price manipulation detected";
        return "No crash detected";
    }
    
    /**
     * @notice Get the Discord name configured for this trap
     * @return discordName The Discord username
     */
    function getDiscordName() external pure returns (string memory) {
        return DISCORD_NAME;
    }
}

/**
 * @notice Chainlink-style price oracle interface
 */
interface IAggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}
