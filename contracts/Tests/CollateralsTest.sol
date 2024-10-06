// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Collaterals.sol";
import "./ERC20Test.sol";
import "./AggregatorV3Test.sol";

contract CollateralsTest is Collaterals
{
    constructor(address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouter)
    Collaterals(_usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouter)
    {
    }

    function getWeiPerUSDTTest() public view returns (uint256) {
        return getWeiPerUSDT();
    }

    function calculateLTVTest(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) public pure returns(uint256) {
        return calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
    }

    function calculateLiquidationTest(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) internal pure returns (uint256) {
        return calculateLiquidation(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
    }
}