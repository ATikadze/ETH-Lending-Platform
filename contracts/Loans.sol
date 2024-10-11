// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Interfaces/ILoans.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Loans Contract
/// @notice This contract handles loan creation, repayment, and collateral liquidation.
contract Loans is Ownable, ILoans {

    /// @notice The structure representing a loan
    struct Loan {
        uint256 amount; // The loan amount in ETH
        uint256 collateralAmount; // The amount of USDT collateral
        uint256 borrowedTimestamp; // Timestamp when the loan was borrowed
        uint256 paidTimestamp; // Timestamp when the loan was fully repaid
    }

    /// @notice The annual percentage rate (APR) for ETH loans, set to 5%
    uint8 public constant ethAPR = 5;

    /// @notice Tracks the current loan ID
    uint256 public loanId = 0;

    /// @notice Mapping of borrowers to their loan IDs
    mapping(address => uint256[]) borrowerLoans;

    /// @notice Mapping of loan IDs to borrowers' addresses
    mapping(uint256 => address) loanBorrowers;

    /// @notice Mapping of loan IDs to the loan details
    mapping(uint256 => Loan) loans;

    /// @notice Emitted when a new loan is created
    /// @param loanId The ID of the loan
    /// @param borrower The address of the borrower
    /// @param amount The amount of ETH borrowed
    event LoanCreated(uint256 loanId, address borrower, uint256 amount);

    /// @notice Emitted when a loan is marked as paid
    /// @param loanId The ID of the loan
    /// @param paidTimestamp The timestamp when the loan was fully repaid
    event LoanMarkedAsPaid(uint256 loanId, uint256 paidTimestamp);

    /// @notice Emitted when collateral is liquidated
    /// @param loanId The ID of the loan
    /// @param coveredDebt The amount of debt covered by the liquidation
    /// @param liquidatedCollateral The amount of collateral liquidated
    event CollateralLiquidated(uint256 loanId, uint256 coveredDebt, uint256 liquidatedCollateral);

    /// @notice Constructor to initialize the Loans contract
    constructor() Ownable(msg.sender) {}

    /// @notice Returns the borrower associated with a loan ID
    /// @param _loanId The loan ID
    /// @return The address of the borrower
    function getBorrower(uint256 _loanId) external view returns(address)
    {
        return loanBorrowers[_loanId];
    }

    /// @notice Internal function to calculate the number of days elapsed since a given timestamp
    /// @param _timestamp The timestamp to calculate days from
    /// @return The number of days elapsed
    function _getDaysElapsed(uint256 _timestamp) internal view virtual returns(uint256)
    {
        return (block.timestamp - _timestamp) / (24 * 60 * 60);
    }

    /// @notice Checks if a loan has been fully repaid
    /// @param _loanId The ID of the loan
    /// @return True if the loan has been fully repaid, otherwise false
    function loanPaid(uint256 _loanId) public view returns(bool)
    {
        return loans[_loanId].paidTimestamp != 0;
    }

    /// @notice Internal function to calculate the interest on a loan
    /// @param _amount The loan amount
    /// @param _timestamp The timestamp when the loan was borrowed
    /// @return The calculated interest
    function _calculateInterest(uint256 _amount, uint256 _timestamp) internal view returns(uint256)
    {
        uint256 _daysElapsed = _getDaysElapsed(_timestamp);
        uint256 _interest = (_amount * ethAPR * (_daysElapsed / 365)) / 100;

        return _interest;
    }

    /// @notice Internal function to calculate the total debt of a loan
    /// @param _amount The loan amount
    /// @param _borrowedTimestamp The timestamp when the loan was borrowed
    /// @return The total debt including the loan amount and interest
    function _calculateDebt(uint256 _amount, uint256 _borrowedTimestamp) internal view returns(uint256)
    {
        return _amount + _calculateInterest(_amount, _borrowedTimestamp);
    }

    /// @notice Returns the total debt for a specific loan
    /// @param _loanId The ID of the loan
    /// @return The total debt including the loan amount and interest
    function calculateDebt(uint256 _loanId) external view returns(uint256)
    {
        Loan memory _loan = loans[_loanId];

        if (_loan.paidTimestamp != 0)
            return 0;

        return _calculateDebt(_loan.amount, _loan.borrowedTimestamp);
    }

    /// @notice Returns the details of a specific loan
    /// @param _loanId The ID of the loan
    /// @return _borrower The address of the borrower
    /// @return _amount The amount of ETH borrowed
    /// @return _collateralAmount The amount of USDT provided as collateral
    /// @return _borrowedTimestamp The timestamp when the loan was borrowed
    /// @return _paidTimestamp The timestamp when the loan was fully repaid (if applicable)
    /// @return _totalDebt The total debt including the loan amount and interest
    function getLoanDetails(uint256 _loanId) external view returns(address _borrower, uint256 _amount, uint256 _collateralAmount, uint256 _borrowedTimestamp, uint256 _paidTimestamp, uint256 _totalDebt)
    {
        _borrower = loanBorrowers[_loanId];
        
        Loan memory _loan = loans[_loanId];
        _amount = _loan.amount;
        _collateralAmount = _loan.collateralAmount;
        _borrowedTimestamp = _loan.borrowedTimestamp;
        _paidTimestamp = _loan.paidTimestamp;
        _totalDebt = _calculateDebt(_loan.amount, _loan.borrowedTimestamp);
    }

    /// @notice Creates a new loan for a borrower
    /// @param _borrower The address of the borrower
    /// @param _amount The amount of ETH borrowed
    /// @param _collateralAmount The amount of USDT provided as collateral
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

    /// @notice Marks a loan as fully paid
    /// @param _loanId The ID of the loan to mark as paid
    function markLoanPaid(uint256 _loanId) external onlyOwner
    {
        require(!loanPaid(_loanId), "Loan already paid.");

        uint256 _paidTimestamp = block.timestamp;
        loans[_loanId].paidTimestamp = _paidTimestamp;

        emit LoanMarkedAsPaid(_loanId, _paidTimestamp);
    }

    /// @notice Liquidates collateral for a specific loan if the loan is in default
    /// @param _loanId The ID of the loan
    /// @param _coveredDebt The amount of debt covered by the liquidation
    /// @param _liquidatedCollateral The amount of collateral liquidated
    function liquidateCollateral(uint256 _loanId, uint256 _coveredDebt, uint256 _liquidatedCollateral) external onlyOwner
    {
        loans[_loanId].amount -= _coveredDebt;
        loans[_loanId].collateralAmount -= _liquidatedCollateral;

        emit CollateralLiquidated(_loanId, _coveredDebt, _liquidatedCollateral);
    }
}
