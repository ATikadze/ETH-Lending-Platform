// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    function getAvailableAmount(address _lender) external view returns (uint256);
    function deposit(address _lender) external payable;
    function withdraw(address _lender, uint256 _amount) external;
    function lend(uint256 _loanId, address _borrower, uint256 _amount) external;
    function repay(uint256 _loanId, uint256 _loanAmount, uint256 _totalDebt) external payable;
}
