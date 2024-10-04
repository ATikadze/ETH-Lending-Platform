// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollaterals {
    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external;
}
