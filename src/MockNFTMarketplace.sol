// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockNFTMarketplace is Ownable {
    struct MockCollectionData {
        uint256 floorPrice;
        uint256 volume24h;
        uint256 totalSupply;
        uint256 listedCount;
        bool exists;
    }
    
    mapping(address => MockCollectionData) public collections;
    address[] public registeredCollections;
    
    event CollectionRegistered(address indexed collection, uint256 floorPrice, uint256 totalSupply);
    event DataUpdated(address indexed collection, uint256 newFloorPrice, uint256 newVolume);
    event FloorPriceCrashSimulated(address indexed collection, uint256 oldPrice, uint256 newPrice);
    event MarketRecoverySimulated(address indexed collection, uint256 oldPrice, uint256 newPrice);
    
    constructor() {}
    
    function registerCollection(
        address collection,
        uint256 initialFloorPrice,
        uint256 totalSupply
    ) external onlyOwner {
        require(collection != address(0), "Invalid collection address");
        require(!collections[collection].exists, "Collection already registered");
        require(initialFloorPrice > 0, "Floor price must be greater than 0");
        require(totalSupply > 0, "Total supply must be greater than 0");
        collections[collection] = MockCollectionData({
            floorPrice: initialFloorPrice,
            volume24h: totalSupply * initialFloorPrice / 10,
            totalSupply: totalSupply,
            listedCount: totalSupply / 20,
            exists: true
        });
        registeredCollections.push(collection);
        emit CollectionRegistered(collection, initialFloorPrice, totalSupply);
    }
    
    function updateCollectionData(
        address collection,
        uint256 newFloorPrice,
        uint256 newVolume,
        uint256 newListedCount,
        uint256 newTotalSupply
    ) external onlyOwner {
        require(collections[collection].exists, "Collection not registered");
        require(newTotalSupply > 0, "Total supply must be greater than 0");
        collections[collection].floorPrice = newFloorPrice;
        collections[collection].volume24h = newVolume;
        collections[collection].listedCount = newListedCount;
        collections[collection].totalSupply = newTotalSupply;
        emit DataUpdated(collection, newFloorPrice, newVolume);
    }
    
    function simulateFloorPriceCrash(address collection, uint256 crashPercentage) external onlyOwner {
        require(collections[collection].exists, "Collection not registered");
        require(crashPercentage > 0 && crashPercentage <= 95, "Invalid crash percentage");
        uint256 oldPrice = collections[collection].floorPrice;
        uint256 newPrice = oldPrice - (oldPrice * crashPercentage / 100);
        uint256 panicVolume = collections[collection].volume24h * 500 / 100;
        uint256 panicListings = collections[collection].totalSupply * 30 / 100;
        collections[collection].floorPrice = newPrice;
        collections[collection].volume24h = panicVolume;
        collections[collection].listedCount = panicListings;
        emit FloorPriceCrashSimulated(collection, oldPrice, newPrice);
        emit DataUpdated(collection, newPrice, panicVolume);
    }
    
    function simulateMarketRecovery(address collection, uint256 recoveryPercentage) external onlyOwner {
        require(collections[collection].exists, "Collection not registered");
        require(recoveryPercentage > 0 && recoveryPercentage <= 200, "Invalid recovery percentage");
        uint256 oldPrice = collections[collection].floorPrice;
        uint256 newPrice = oldPrice + (oldPrice * recoveryPercentage / 100);
        uint256 normalVolume = collections[collection].totalSupply * newPrice / 20;
        uint256 normalListings = collections[collection].totalSupply / 20;
        collections[collection].floorPrice = newPrice;
        collections[collection].volume24h = normalVolume;
        collections[collection].listedCount = normalListings;
        emit MarketRecoverySimulated(collection, oldPrice, newPrice);
        emit DataUpdated(collection, newPrice, normalVolume);
    }
    
    function getFloorPrice(address collection) external view returns (uint256) {
        require(collections[collection].exists, "Collection not registered");
        return collections[collection].floorPrice;
    }
    
    function getVolume24h(address collection) external view returns (uint256) {
        require(collections[collection].exists, "Collection not registered");
        return collections[collection].volume24h;
    }
    
    function getTotalSupply(address collection) external view returns (uint256) {
        require(collections[collection].exists, "Collection not registered");
        return collections[collection].totalSupply;
    }
    
    function getListedCount(address collection) external view returns (uint256) {
        require(collections[collection].exists, "Collection not registered");
        return collections[collection].listedCount;
    }
    
    function getCollectionData(address collection) external view returns (MockCollectionData memory) {
        require(collections[collection].exists, "Collection not registered");
        return collections[collection];
    }
    
    function getRegisteredCollections() external view returns (address[] memory) {
        return registeredCollections;
    }
    
    function isRegistered(address collection) external view returns (bool) {
        return collections[collection].exists;
    }
    
    function batchUpdateCollections(
        address[] calldata _collections,
        uint256[] calldata _floorPrices,
        uint256[] calldata _volumes,
        uint256[] calldata _listedCounts,
        uint256[] calldata _totalSupplies
    ) external onlyOwner {
        require(_collections.length == _floorPrices.length, "Arrays length mismatch");
        require(_collections.length == _volumes.length, "Arrays length mismatch");
        require(_collections.length == _listedCounts.length, "Arrays length mismatch");
        require(_collections.length == _totalSupplies.length, "Arrays length mismatch");
        for (uint i = 0; i < _collections.length; i++) {
            require(collections[_collections[i]].exists, "Collection not registered");
            require(_totalSupplies[i] > 0, "Total supply must be greater than 0");
            collections[_collections[i]].floorPrice = _floorPrices[i];
            collections[_collections[i]].volume24h = _volumes[i];
            collections[_collections[i]].listedCount = _listedCounts[i];
            collections[_collections[i]].totalSupply = _totalSupplies[i];
            emit DataUpdated(_collections[i], _floorPrices[i], _volumes[i]);
        }
    }
    
    function createSampleCollections() external onlyOwner {
        address collection1 = address(0x1111111111111111111111111111111111111111);
        if (!collections[collection1].exists) {
            collections[collection1] = MockCollectionData({
                floorPrice: 50 ether,
                volume24h: 500 ether,
                totalSupply: 10000,
                listedCount: 500,
                exists: true
            });
            registeredCollections.push(collection1);
            emit CollectionRegistered(collection1, 50 ether, 10000);
        }
        address collection2 = address(0x2222222222222222222222222222222222222222);
        if (!collections[collection2].exists) {
            collections[collection2] = MockCollectionData({
                floorPrice: 30 ether,
                volume24h: 300 ether,
                totalSupply: 10000,
                listedCount: 300,
                exists: true
            });
            registeredCollections.push(collection2);
            emit CollectionRegistered(collection2, 30 ether, 10000);
        }
        address collection3 = address(0x3333333333333333333333333333333333333333);
        if (!collections[collection3].exists) {
            collections[collection3] = MockCollectionData({
                floorPrice: 5 ether,
                volume24h: 50 ether,
                totalSupply: 1000,
                listedCount: 50,
                exists: true
            });
            registeredCollections.push(collection3);
            emit CollectionRegistered(collection3, 5 ether, 1000);
        }
    }

    function isCollectionRegistered(address collection) external view returns (bool) {
        return collections[collection].exists;
    }
}
