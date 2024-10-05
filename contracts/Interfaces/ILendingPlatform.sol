// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPlatform {
    function getAvailableAmount() external view returns (uint256);
    function depositETH() external payable;
    function withdrawETH(uint256 _amount) external;
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external;
    function repayETHDebt(uint256 _loanId) external payable;
}
