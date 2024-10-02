// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILoans {
    function getBorrower(uint256 _loanId) external view returns(address);
    function calculateDebt(uint256 _loanId) external view returns(uint256);
    function getLoanRepaymentDetails(uint256 _loanId) external view returns(uint256 _amount, address[] memory _lenderAddresses, uint256[] memory _lentAmounts);
    function newLoan(address _borrower, uint256 _amount, address[] memory _lenderAddresses, uint256[] memory _lentAmounts) external returns(uint256);
    function loanPaid(uint256 _loanId) external;
}
