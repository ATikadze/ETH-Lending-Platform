// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Borrower.sol";
import "./ERC20Test.sol";
import "./AggregatorV3Test.sol";

contract BorrowerTest is Borrower
{
    constructor(address _loansAddress, address _lendingPoolAddress, address _collateralsAddress, address _usdtAddress)
    Borrower(_loansAddress, _lendingPoolAddress, _collateralsAddress, _usdtAddress)
    {
    }
}