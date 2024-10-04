// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Borrower.sol";
import "./ERC20Test.sol";
import "./AggregatorV3Test.sol";

contract BorrowerTest is Borrower
{
    constructor(address _loansAddress, address _lendingPoolAddress, address _usdtAddress, address _usdtPriceFeedAddress)
    Borrower(_loansAddress, _lendingPoolAddress, _usdtAddress, _usdtPriceFeedAddress)
    {
    }

    function getWeiPerUSDTTest() public view returns (uint256) {
        return getWeiPerUSDT();
    }

    function calculateLTVTest(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) public pure returns(uint256) {
        return calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
    }
}