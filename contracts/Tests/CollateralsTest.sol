// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../Collaterals.sol";

contract CollateralsTest is Collaterals
{
    constructor(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress)
    Collaterals(_tokenDecimalsCount, _usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouterAddress)
    {
    }

    function getWeiPerUSDTTest() public view returns (uint256) {
        return _getWeiPerUSDT();
    }

    function calculateLTVTest(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) public pure returns(uint256) {
        return _calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
    }

    function calculateLiquidationTest(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) public pure returns (uint256) {
        return _calculateLiquidation(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
    }
}