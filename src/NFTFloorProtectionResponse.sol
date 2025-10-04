// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title NFT Floor Protection Response Contract
 * @notice Handles automated responses when NFT floor price crashes are detected
 * @dev Called by Drosera operators when NFTFloorPriceCrashTrap triggers
 */
contract NFTFloorProtectionResponse {
    
    // ============= EVENTS =============
    
    /// @notice Emitted when a price crash is detected and responded to
    event CrashDetected(
        string indexed discordDetector,
        address indexed collection,
        uint256 currentPrice,
        uint256 baselinePrice,
        uint8 crashType,
        uint256 detectionTimestamp,
        uint256 severity,
        string crashDescription
    );
    
    /// @notice Emitted when emergency mode status changes
    event EmergencyModeChanged(
        bool isEmergencyMode,
        address collection,
        string reason,
        uint256 timestamp,
        address changedBy
    );
    
    /// @notice Emitted when trap authorization changes
    event TrapAuthorizationChanged(
        address indexed trapAddress,
        bool authorized,
        uint256 timestamp
    );
    
    // ============= STRUCTS =============
    
    /// @notice Record of a detected crash
    struct CrashRecord {
        address collection;        // NFT collection address
        uint256 detectionTime;     // When crash was detected
        uint256 currentPrice;      // Price at detection
        uint256 baselinePrice;     // Price before crash
        uint8 crashType;           // Type of crash (1-4)
        uint256 severity;          // Severity metric (drop % or volatility)
        string detectorDiscord;    // Who detected it
    }
    
    // ============= STATE VARIABLES =============
    
    /// @notice Contract owner (deployer)
    address public immutable owner;
    
    /// @notice Emergency mode status per collection
    mapping(address => bool) public emergencyMode;
    
    /// @notice Total number of crashes detected
    uint256 public totalCrashes;
    
    /// @notice Last crash detection time per collection
    mapping(address => uint256) public lastCrashTime;
    
    /// @notice Last crash price per collection
    mapping(address => uint256) public lastCrashPrice;
    
    /// @notice Mapping of authorized trap contracts
    mapping(address => bool) public authorizedTraps;
    
    /// @notice Historical record of all crashes
    mapping(uint256 => CrashRecord) public crashHistory;
    
    // ============= MODIFIERS =============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "NFTFloorProtectionResponse: Not owner");
        _;
    }
    
    modifier onlyAuthorizedTrap() {
        require(authorizedTraps[msg.sender], "NFTFloorProtectionResponse: Not authorized trap");
        _;
    }
    
    // ============= CONSTRUCTOR =============
    
    constructor() {
        owner = msg.sender;
        totalCrashes = 0;
    }
    
    // ============= MAIN FUNCTIONS =============
    
    /**
     * @notice Main response function called by Drosera when crash detected
     * @param discordName Discord username of the detector
     * @param collection NFT collection address
     * @param currentPrice Current floor price
     * @param baselinePrice Baseline price before crash
     * @param crashType Type of crash detected (1=GradualDecline, 2=FlashCrash, 3=HighVolatility, 4=Manipulation)
     * @param detectionTimestamp When the crash was detected
     * @param severity Severity metric (drop percentage in bps or volatility)
     */
    function respondToCrash(
        string memory discordName,
        address collection,
        uint256 currentPrice,
        uint256 baselinePrice,
        uint8 crashType,
        uint256 detectionTimestamp,
        uint256 severity
    ) external onlyAuthorizedTrap {
        
        // Validate input parameters
        require(bytes(discordName).length > 0, "Discord name required");
        require(collection != address(0), "Invalid collection address");
        require(crashType >= 1 && crashType <= 4, "Invalid crash type");
        require(currentPrice > 0, "Invalid current price");
        require(baselinePrice > 0, "Invalid baseline price");
        
        // Record the crash in history
        crashHistory[totalCrashes] = CrashRecord({
            collection: collection,
            detectionTime: detectionTimestamp,
            currentPrice: currentPrice,
            baselinePrice: baselinePrice,
            crashType: crashType,
            severity: severity,
            detectorDiscord: discordName
        });
        
        // Update state
        lastCrashTime[collection] = detectionTimestamp;
        lastCrashPrice[collection] = currentPrice;
        totalCrashes++;
        
        // Get human-readable description
        string memory description = _getCrashDescription(crashType);
        
        // Emit comprehensive event
        emit CrashDetected(
            discordName,
            collection,
            currentPrice,
            baselinePrice,
            crashType,
            detectionTimestamp,
            severity,
            description
        );
        
        // Check if this crash warrants emergency mode
        bool shouldEnterEmergency = _shouldEnterEmergencyMode(
            crashType,
            currentPrice,
            baselinePrice,
            severity
        );
        
        if (shouldEnterEmergency && !emergencyMode[collection]) {
            _setEmergencyMode(collection, true, description);
        }
    }
    
    /**
     * @notice Authorize a trap contract to trigger responses
     * @param trapAddress Address of the trap contract to authorize
     */
    function authorizeTrap(address trapAddress) external onlyOwner {
        require(trapAddress != address(0), "Invalid trap address");
        
        authorizedTraps[trapAddress] = true;
        
        emit TrapAuthorizationChanged(trapAddress, true, block.timestamp);
    }
    
    /**
     * @notice Revoke authorization for a trap contract
     * @param trapAddress Address of the trap contract to deauthorize
     */
    function deauthorizeTrap(address trapAddress) external onlyOwner {
        authorizedTraps[trapAddress] = false;
        
        emit TrapAuthorizationChanged(trapAddress, false, block.timestamp);
    }
    
    /**
     * @notice Manually control emergency mode (owner only)
     * @param collection NFT collection address
     * @param _emergencyMode New emergency mode status
     * @param reason Reason for the change
     */
    function setEmergencyMode(
        address collection,
        bool _emergencyMode,
        string memory reason
    ) external onlyOwner {
        _setEmergencyMode(collection, _emergencyMode, reason);
    }
    
    // ============= VIEW FUNCTIONS =============
    
    /**
     * @notice Check if a collection is currently considered healthy
     * @param collection NFT collection address
     * @return healthy True if no emergency mode and no recent severe crashes
     */
    function isCollectionHealthy(address collection) external view returns (bool healthy) {
        if (emergencyMode[collection]) {
            return false;
        }
        
        // Consider healthy if no crashes in last 100 blocks (~20 minutes on Ethereum)
        if (lastCrashTime[collection] > 0 && (block.timestamp - lastCrashTime[collection]) < 1200) {
            return false;
        }
        
        return true;
    }
    
    /**
     * @notice Get recent crash history
     * @param count Number of recent crashes to return (max 20)
     * @return crashes Array of recent crash records
     */
    function getRecentCrashes(uint256 count) external view returns (CrashRecord[] memory crashes) {
        if (count > 20) count = 20; // Limit to prevent gas issues
        if (count > totalCrashes) count = totalCrashes;
        
        crashes = new CrashRecord[](count);
        
        for (uint256 i = 0; i < count; i++) {
            crashes[i] = crashHistory[totalCrashes - 1 - i];
        }
        
        return crashes;
    }
    
    /**
     * @notice Get statistics about detected crashes
     * @param collection NFT collection address
     * @return total Total crashes detected across all collections
     * @return lastTime Timestamp of most recent crash for this collection
     * @return lastPrice Price at most recent crash for this collection
     * @return inEmergency Current emergency mode status for this collection
     */
    function getStats(address collection) external view returns (
        uint256 total,
        uint256 lastTime,
        uint256 lastPrice,
        bool inEmergency
    ) {
        return (
            totalCrashes,
            lastCrashTime[collection],
            lastCrashPrice[collection],
            emergencyMode[collection]
        );
    }
    
    // ============= INTERNAL HELPER FUNCTIONS =============
    
    /**
     * @notice Determine if detected crash warrants emergency mode
     * @param crashType Type of crash detected
     * @param currentPrice Current floor price
     * @param baselinePrice Baseline price before crash
     * @param severity Severity metric
     * @return shouldEnter True if emergency mode should be activated
     */
    function _shouldEnterEmergencyMode(
        uint8 crashType,
        uint256 currentPrice,
        uint256 baselinePrice,
        uint256 severity
    ) internal pure returns (bool shouldEnter) {
        // Emergency triggers for severe conditions
        
        if (crashType == 1) { // GradualDecline
            // Emergency if decline >50% total
            uint256 dropBps = ((baselinePrice - currentPrice) * 10000) / baselinePrice;
            return dropBps >= 5000;
        }
        
        if (crashType == 2) { // FlashCrash
            // Emergency if flash crash >40% in one interval
            return severity >= 4000;
        }
        
        if (crashType == 3) { // HighVolatility
            // Emergency if volatility >30%
            return severity >= 3000;
        }
        
        if (crashType == 4) { // Manipulation
            // Always emergency for suspected manipulation
            return true;
        }
        
        return false;
    }
    
    /**
     * @notice Internal function to set emergency mode
     * @param collection NFT collection address
     * @param _emergencyMode New emergency mode status
     * @param reason Reason for the change
     */
    function _setEmergencyMode(
        address collection,
        bool _emergencyMode,
        string memory reason
    ) internal {
        if (emergencyMode[collection] != _emergencyMode) {
            emergencyMode[collection] = _emergencyMode;
            emit EmergencyModeChanged(
                _emergencyMode,
                collection,
                reason,
                block.timestamp,
                msg.sender
            );
        }
    }
    
    /**
     * @notice Get human-readable description for crash type
     * @param crashType Numeric crash type
     * @return description Human-readable description
     */
    function _getCrashDescription(uint8 crashType) internal pure returns (string memory description) {
        if (crashType == 1) return "Gradual price decline detected - potential sell-off";
        if (crashType == 2) return "Flash price crash detected - possible dump";
        if (crashType == 3) return "High price volatility detected - unstable market";
        if (crashType == 4) return "Potential price manipulation detected";
        return "Unknown crash type";
    }
}
