// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollaterals {
    function validateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external view returns(bool);
    function liquidate(address _liquidator, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external returns(uint256 _liquidationAmount, uint256 _coveredDebt);
    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external;
    function withdrawCollateral(address _borrower, uint256 _usdtCollateralAmount) external;
}
