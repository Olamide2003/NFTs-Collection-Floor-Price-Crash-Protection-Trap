// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Mock Price Oracle
 * @notice Mock Chainlink-style oracle for testing NFT floor prices
 * @dev Simulates oracle behavior for Hoodi testnet deployment
 */
contract MockPriceOracle {
    
    // ============= STATE VARIABLES =============
    
    /// @notice Contract owner
    address public owner;
    
    /// @notice Floor prices per collection (in wei, e.g., 8.45 ETH = 8450000000000000000)
    mapping(address => int256) public prices;
    
    /// @notice Last update timestamp per collection
    mapping(address => uint256) public updatedAt;
    
    /// @notice Round ID counter
    uint80 public roundId;
    
    // ============= EVENTS =============
    
    event PriceUpdated(
        address indexed collection,
        int256 price,
        uint256 timestamp,
        address updatedBy
    );
    
    event CrashSimulated(
        address indexed collection,
        int256 oldPrice,
        int256 newPrice,
        uint256 dropPercentage
    );
    
    // ============= CONSTRUCTOR =============
    
    constructor() {
        owner = msg.sender;
        roundId = 1;
        
        // Initialize with BAYC example price: 8.45 ETH
        address bayc = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        prices[bayc] = 8450000000000000000; // 8.45 ETH
        updatedAt[bayc] = block.timestamp;
    }
    
    // ============= MODIFIERS =============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "MockPriceOracle: Not owner");
        _;
    }
    
    // ============= MAIN FUNCTIONS =============
    
    /**
     * @notice Set floor price for a collection
     * @param collection NFT collection address
     * @param price Floor price in wei
     */
    function setPrice(address collection, int256 price) external onlyOwner {
        require(price > 0, "Price must be positive");
        
        prices[collection] = price;
        updatedAt[collection] = block.timestamp;
        roundId++;
        
        emit PriceUpdated(collection, price, block.timestamp, msg.sender);
    }
    
    /**
     * @notice Get latest price data (Chainlink-compatible interface)
     * @return roundId_ Round ID
     * @return answer Price in wei
     * @return startedAt Started timestamp (unused, returns 0)
     * @return updatedAt_ Last update timestamp
     * @return answeredInRound Answered in round (unused, returns 0)
     */
    function latestRoundData() external view returns (
        uint80 roundId_,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt_,
        uint80 answeredInRound
    ) {
        // Default to BAYC collection
        address collection = 0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D;
        
        int256 price = prices[collection];
        require(price > 0, "No price set for collection");
        
        uint256 timestamp = updatedAt[collection];
        require(timestamp > 0, "No timestamp set");
        
        return (roundId, price, 0, timestamp, 0);
    }
    
    /**
     * @notice Simulate a price crash for testing
     * @param collection NFT collection address
     * @param dropPercentage Percentage drop (0-100)
     */
    function simulateCrash(address collection, uint256 dropPercentage) external onlyOwner {
        require(dropPercentage <= 100, "Invalid percentage");
        
        int256 currentPrice = prices[collection];
        require(currentPrice > 0, "No price set for collection");
        
        int256 newPrice = currentPrice * int256(100 - dropPercentage) / 100;
        
        emit CrashSimulated(collection, currentPrice, newPrice, dropPercentage);
        
        prices[collection] = newPrice;
        updatedAt[collection] = block.timestamp;
        roundId++;
    }
    
    /**
     * @notice Simulate gradual price decline over multiple calls
     * @param collection NFT collection address
     * @param decrementPercentage Percentage to decrease per call (0-20)
     */
    function simulateGradualDecline(address collection, uint256 decrementPercentage) external onlyOwner {
        require(decrementPercentage <= 20, "Max 20% per call");
        
        int256 currentPrice = prices[collection];
        require(currentPrice > 0, "No price set for collection");
        
        int256 newPrice = currentPrice * int256(100 - decrementPercentage) / 100;
        prices[collection] = newPrice;
        updatedAt[collection] = block.timestamp;
        roundId++;
        
        emit PriceUpdated(collection, newPrice, block.timestamp, msg.sender);
    }
    
    /**
     * @notice Reset price to a baseline value
     * @param collection NFT collection address
     * @param baselinePrice New baseline price in wei
     */
    function resetPrice(address collection, int256 baselinePrice) external onlyOwner {
        require(baselinePrice > 0, "Price must be positive");
        
        prices[collection] = baselinePrice;
        updatedAt[collection] = block.timestamp;
        roundId++;
        
        emit PriceUpdated(collection, baselinePrice, block.timestamp, msg.sender);
    }
    
    /**
     * @notice Transfer ownership
     * @param newOwner New owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
}
