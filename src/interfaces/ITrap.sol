// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ITrap {
    /// @notice Called by the monitoring system to collect fresh data
    function collect() external view returns (bytes memory);

    /// @notice Called with historical data to decide if response is needed
    /// @param data array of encoded snapshots (latest is data[0])
    /// @return shouldTrigger whether response should fire
    /// @return payload encoded response payload
    function shouldRespond(bytes[] calldata data) external pure returns (bool shouldTrigger, bytes memory payload);
}
