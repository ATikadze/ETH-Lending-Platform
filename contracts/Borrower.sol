// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ILoans.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Borrower is ReentrancyGuard
{
    ILoans loans;
    ILendingPool lendingPool;
    ICollaterals collaterals;
    IERC20 usdtContract;

    modifier onlyLoanOwner(uint256 _loanId)
    {
        require(msg.sender == loans.getBorrower(_loanId));
        _;
    }

    constructor(address _loansAddress, address _lendingPoolAddress, address _collateralsAddress, address _usdtAddress) {
        loans = ILoans(_loansAddress);
        lendingPool = ILendingPool(_lendingPoolAddress);
        collaterals = ICollaterals(_collateralsAddress);
        usdtContract = IERC20(_usdtAddress);
    }
    
    // Expecting _ethBorrowAmountInWei in ETH * 10^18 and _usdtCollateralAmount in USDT
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external nonReentrant
    {
        require(collaterals.validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount)); // TODO: Custom error message
        
        uint256 _usdtAmount = _usdtCollateralAmount * 1e6; // TODO: Possibly switch to a more dynamic approach. Get decimals from the contract.
        
        require(usdtContract.allowance(msg.sender, address(this)) >= _usdtAmount); // TODO: Custom error message
        
        usdtContract.transferFrom(msg.sender, address(this), _usdtAmount);
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
