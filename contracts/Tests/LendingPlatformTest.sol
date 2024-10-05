// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../LendingPlatform.sol";
import "../Tests/LoansTest.sol";
import "../Tests/LendingPoolTest.sol";
import "../Tests/CollateralsTest.sol";

contract LendingPlatformTest is LendingPlatform
{
    constructor(address _usdtAddress, address _usdtPriceFeedAddress)
    LendingPlatform(_usdtAddress, _usdtPriceFeedAddress) {
    }

    function initializeContracts(address _usdtAddress, address _usdtPriceFeedAddress) internal override
    {
        loans = new LoansTest();
        lendingPool = new LendingPoolTest();
        collaterals = new CollateralsTest(_usdtAddress, _usdtPriceFeedAddress);
    }
}