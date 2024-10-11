// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ICollaterals {
    function validateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external view returns(bool);
    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external;
    function withdrawCollateral(address _borrower, uint256 _usdtCollateralAmount) external;
    function liquidate(address _liquidator, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external returns(uint256 _totalLiquidatedUSDTAmount, uint256 _coveredDebtInWEI);
}
