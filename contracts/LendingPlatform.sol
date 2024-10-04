// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ILendingPlatform.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";
import "./Interfaces/ILoans.sol";

contract LendingPlatform is ILendingPlatform {
    ILendingPool lendingPool;
    ICollaterals collaterals;
    ILoans loans;

    constructor(address _lendingPoolAddress, address _collateralsAddress, address _loansAddress) {
        lendingPool = ILendingPool(_lendingPoolAddress);
        collaterals = ICollaterals(_collateralsAddress);
        loans = ILoans(_loansAddress);
    }
    
    function depositETH() external payable {
        lendingPool.deposit{value: msg.value}(msg.sender);
    }

    function withdrawETH(uint256 _amount) external {
        lendingPool.withdraw(msg.sender, _amount);
    }
    
    // Expecting _ethBorrowAmountInWei in ETH * 10^18 and _usdtCollateralAmount in USDT
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external
    {
        loans.newLoan(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);

        collaterals.depositCollateral(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
        lendingPool.lend(loans.loanId(), msg.sender, _ethBorrowAmountInWei);
    }
    
    // TODO: Add partial repayment
    // TODO: Add collateral refund
    function repayETHDebt(uint256 _loanId) external payable
    {
        (address _borrower, uint256 _loanAmount, uint256 _collateralAmount,,, uint256 _totalDebt) = loans.getLoanDetails(_loanId);(_loanId);
        
        require(msg.sender == _borrower); // TODO
        require(msg.value >= _totalDebt); // TODO
        
        lendingPool.repay{value: msg.value}(_loanId, _loanAmount, _totalDebt);
        collaterals.withdrawCollateral(msg.sender, _collateralAmount);

        loans.loanPaid(_loanId);
        
        if (msg.value > _totalDebt)
        {
            uint256 _refund = msg.value - _totalDebt;
            (bool _success,) = msg.sender.call{value: _refund}("");
            
            require(_success);
        }
    }
}
