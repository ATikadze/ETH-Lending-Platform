// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract AggregatorV3Test is AggregatorV3Interface {
    int256 usdtPerEther;
    
    function decimals() external view returns (uint8) {}

    function description() external view returns (string memory) {}

    function version() external view returns (uint256) {}

    function getRoundData(uint80 _roundId) external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {}

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (0, 1e8 / usdtPerEther, 0, 0, 0);
    }

    function setUSDTPricePerEther(int256 _usdtPerEther) external
    {
        usdtPerEther = _usdtPerEther;
    }
}
