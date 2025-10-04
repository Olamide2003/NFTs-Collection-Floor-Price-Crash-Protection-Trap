// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract SignedPriceOracle {
    using ECDSA for bytes32;

    struct Price {
        uint256 price;
        uint256 timestamp;
        address reporter;
    }

    mapping(address => Price) public latest;
    mapping(address => bool) public allowedReporters;
    uint256 public maxStaleSeconds = 3600; // 1 hour

    event PriceSubmitted(address indexed collection, uint256 price, uint256 timestamp, address reporter);

    function setReporter(address who, bool ok) external {
        // NOTE: protect with onlyOwner/multisig in real deployment
        allowedReporters[who] = ok;
    }

    function submitPrice(
        address collection,
        uint256 price,
        uint256 timestamp,
        bytes calldata signature
    ) external {
        bytes32 message = keccak256(abi.encodePacked(block.chainid, collection, price, timestamp));
        bytes32 ethSigned = message.toEthSignedMessageHash();
        address signer = ethSigned.recover(signature);
        require(allowedReporters[signer], "unauthorized reporter");
        require(timestamp <= block.timestamp && block.timestamp + maxStaleSeconds >= block.timestamp, "stale/future");

        latest[collection] = Price(price, timestamp, signer);
        emit PriceSubmitted(collection, price, timestamp, signer);
    }

    function getFloorPrice(address collection) external view returns (uint256) {
        return latest[collection].price;
    }
}
