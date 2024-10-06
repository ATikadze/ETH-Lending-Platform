// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ILoans.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Loans is Ownable, ILoans {
    struct Loan {
        uint256 amount;
        uint256 collateralAmount;
        uint256 borrowedTimestamp;
        uint256 paidTimestamp;
    }

    uint8 public constant ethAPR = 5;
    uint256 public loanId = 0;

    mapping(address => uint256[]) borrowerLoans;
    mapping(uint256 => address) loanBorrowers;
    mapping(uint256 => Loan) loans;

    event LoanCreated(uint256 loanId, address borrower, uint256 amount);

    constructor() Ownable(msg.sender) {}

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
    
    function calculateDebt(uint256 _amount, uint256 _borrowedTimestamp) internal view returns(uint256)
    {
        return _amount + calculateInterest(_amount, _borrowedTimestamp);
    }
    
    // TODO: Maybe add onlyLoanOwner?
    function calculateDebt(uint256 _loanId) external view returns(uint256)
    {
        Loan memory _loan = loans[_loanId];

        if (_loan.paidTimestamp != 0)
            return 0;

        return calculateDebt(_loan.amount, _loan.borrowedTimestamp);
    }

    function getLoanDetails(uint256 _loanId) external view onlyOwner returns(address _borrower, uint256 _amount, uint256 _collateralAmount, uint256 _borrowedTimestamp, uint256 _paidTimestamp, uint256 _totalDebt)
    {
        _borrower = loanBorrowers[_loanId];
        
        Loan memory _loan = loans[_loanId];
        _amount = _loan.amount;
        _collateralAmount = _loan.collateralAmount;
        _borrowedTimestamp = _loan.borrowedTimestamp;
        _paidTimestamp = _loan.paidTimestamp;
        _totalDebt = calculateDebt(_loan.amount, _loan.borrowedTimestamp);
    }

    function newLoan(address _borrower, uint256 _amount, uint256 _collateralAmount) external onlyOwner
    {
        loanId++;

        borrowerLoans[_borrower].push(loanId);
        loanBorrowers[loanId] = _borrower;

        Loan storage _loan = loans[loanId];
        _loan.amount = _amount;
        _loan.collateralAmount = _collateralAmount;
        _loan.borrowedTimestamp = block.timestamp;

        emit LoanCreated(loanId, _borrower, _amount);
    }
    
    function loanPaid(uint256 _loanId) external onlyOwner
    {
        require(loans[_loanId].paidTimestamp == 0, "Loan already paid.");
        
        loans[_loanId].paidTimestamp = block.timestamp;
    }

    function liquidateCollateral(uint256 _loanId, uint256 _coveredDebt, uint256 _liquidatedCollateral) external onlyOwner
    {
        loans[_loanId].amount -= _coveredDebt;
        loans[_loanId].collateralAmount -= _liquidatedCollateral;

        // TODO: Check if the debt is already paid
    }
}
