// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ILoans.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Borrower is ReentrancyGuard
{
    ILoans loans;
    ILendingPool lendingPool;
    ICollaterals collaterals;

    modifier onlyLoanOwner(uint256 _loanId)
    {
        require(msg.sender == loans.getBorrower(_loanId));
        _;
    }

    constructor(address _loansAddress, address _lendingPoolAddress, address _collateralsAddress) {
        loans = ILoans(_loansAddress);
        lendingPool = ILendingPool(_lendingPoolAddress);
        collaterals = ICollaterals(_collateralsAddress);
    }
    
    // Expecting _ethBorrowAmountInWei in ETH * 10^18 and _usdtCollateralAmount in USDT
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external nonReentrant
    {
        collaterals.depositCollateral(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
        lendingPool.lendETH(msg.sender, _ethBorrowAmountInWei);
    }
    
    // TODO: Add partial repayment
    // TODO: Add collateral refund
    function repayETHDebt(uint256 _loanId) external payable onlyLoanOwner(_loanId) nonReentrant
    {
        uint256 _totalDebt = loans.calculateDebt(_loanId);
        
        require(msg.value >= _totalDebt); // TODO: Custom error

        lendingPool.repayETH{value: _totalDebt}(_loanId);
        
        if (msg.value > _totalDebt)
        {
            uint256 _refund = msg.value - _totalDebt;
            (bool _success,) = msg.sender.call{value: _refund}("");
            
            require(_success);
        }

        loans.loanPaid(_loanId);
    }
}
