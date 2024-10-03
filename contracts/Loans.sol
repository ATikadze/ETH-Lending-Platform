// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILoans.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loans is Ownable, ILoans {
    struct Loan {
        uint256 amount;
        uint256 borrowedTimestamp;
        uint256 paidTimestamp;
        Lender[] lenders;
    }

    struct Lender {
        address lender;
        uint256 lentAmount;
    }

    uint8 constant public ethAPR = 5;
    
    uint256 loanId = 0;

    mapping(address => bool) whitelist;
    mapping(address => uint256[]) borrowerLoans;
    mapping(uint256 => address) loanBorrowers;
    mapping(uint256 => Loan) loans;

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Unauthorized");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function addWhitelist(address _address) external onlyOwner
    {
        whitelist[_address] = true;
    }

    function removeWhitelist(address _address) external onlyOwner
    {
        whitelist[_address] = false;
    }

    function getBorrower(uint256 _loanId) external view returns(address)
    {
        return loanBorrowers[_loanId];
    }

    function getDaysElapsed(uint256 _timestamp) internal view virtual returns(uint256)
    {
        return (block.timestamp - _timestamp) / (24 * 60 * 60);
    }

    function calculateInterest(uint256 _amount, uint256 _timestamp) internal view returns(uint256)
    {
        uint256 _daysElapsed = getDaysElapsed(_timestamp);
        uint256 _interest = (_amount * ethAPR * (_daysElapsed / 365)) / 100;

        return _interest;
    }
    
    // TODO: Maybe add onlyLoanOwner?
    // TODO: Add check for if the loan is paid
    function calculateDebt(uint256 _loanId) external view returns(uint256)
    {
        Loan memory _loan = loans[_loanId];

        return _loan.amount + calculateInterest(_loan.amount, _loan.borrowedTimestamp);
    }

    function getLoanRepaymentDetails(uint256 _loanId) external view onlyWhitelist returns(uint256 _amount, address[] memory _lenderAddresses, uint256[] memory _lentAmounts)
    {
        Loan memory _loan = loans[_loanId];
        _amount = _loan.amount;

        _lenderAddresses = new address[](_loan.lenders.length);
        _lentAmounts = new uint256[](_loan.lenders.length);

        for (uint256 i = 0; i < _loan.lenders.length; i++) {
            _lenderAddresses[i] = _loan.lenders[i].lender;
            _lentAmounts[i] = _loan.lenders[i].lentAmount;
        }
    }

    function newLoan(address _borrower, uint256 _amount, address[] memory _lenderAddresses, uint256[] memory _lentAmounts) external onlyWhitelist returns(uint256)
    {
        require(_lenderAddresses.length == _lentAmounts.length); // TODO
        
        loanId++;

        borrowerLoans[_borrower].push(loanId);
        loanBorrowers[loanId] = _borrower;

        Loan storage _loan = loans[loanId];

        for (uint256 i = 0; i < _lenderAddresses.length; i++) {
            _loan.lenders.push(Lender(_lenderAddresses[i], _lentAmounts[i]));
        }
        
        _loan.amount = _amount;
        _loan.borrowedTimestamp = block.timestamp;
        
        return loanId;
    }
    
    function loanPaid(uint256 _loanId) external onlyWhitelist
    {
        require(loans[_loanId].paidTimestamp == 0); // TODO
        
        loans[_loanId].paidTimestamp = block.timestamp;
    }
}
