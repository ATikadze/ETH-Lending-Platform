// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILoans {
    function loanId() external view returns(uint256);
    function getBorrower(uint256 _loanId) external view returns(address);
    function calculateDebt(uint256 _loanId) external view returns(uint256);
    function getLoanDetails(uint256 _loanId) external view returns(address _borrower, uint256 _amount, uint256 _collateralAmount, uint256 _borrowedTimestamp, uint256 _paidTimestamp, uint256 _totalDebt);
    function newLoan(address _borrower, uint256 _amount, uint256 _collateralAmount) external;
    function loanPaid(uint256 _loanId) external;
}
