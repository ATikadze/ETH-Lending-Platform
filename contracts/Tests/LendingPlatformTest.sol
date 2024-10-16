// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../LendingPlatform.sol";
import "../Tests/LoansTest.sol";
import "../Tests/LendingPoolTest.sol";
import "../Tests/CollateralsTest.sol";

contract LendingPlatformTest is LendingPlatform
{
    constructor(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress)
    LendingPlatform(_tokenDecimalsCount, _usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouterAddress)
    {}

    function _initializeContracts(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress) internal override
    {
        loans = new LoansTest();
        lendingPool = new LendingPoolTest();
        collaterals = new CollateralsTest(_tokenDecimalsCount, _usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouterAddress);
    }
}