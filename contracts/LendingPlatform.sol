// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Loans.sol";
import "./LendingPool.sol";
import "./Collaterals.sol";
import "./Interfaces/ILoans.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";
import "./Interfaces/ILendingPlatform.sol";

contract LendingPlatform is ILendingPlatform {
    ILoans public loans;
    ILendingPool public lendingPool;
    ICollaterals public collaterals;

    constructor(address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouter) {
        initializeContracts(_usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouter);
    }

    function initializeContracts(address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouter) internal virtual
    {
        loans = new Loans();
        lendingPool = new LendingPool();
        collaterals = new Collaterals(_usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouter);
    }

    function getAvailableAmount() external view returns (uint256) {
        return lendingPool.getAvailableAmount(msg.sender);
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
        collaterals.depositCollateral(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
        lendingPool.lend(msg.sender, _ethBorrowAmountInWei);

        loans.newLoan(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
    }
    
    // TODO: Add partial repayment
    // TODO: Add collateral refund
    function repayETHDebt(uint256 _loanId) external payable
    {
        (address _borrower,, uint256 _collateralAmount,,, uint256 _totalDebt) = loans.getLoanDetails(_loanId);
        
        require(msg.sender == _borrower); // TODO
        require(msg.value >= _totalDebt); // TODO
        
        lendingPool.repay{value: _totalDebt}();
        collaterals.withdrawCollateral(msg.sender, _collateralAmount);

        loans.loanPaid(_loanId);
        
        if (msg.value > _totalDebt)
        {
            uint256 _refund = msg.value - _totalDebt;
            (bool _success,) = msg.sender.call{value: _refund}("");
            require(_success);
        }
    }

    function liquidateCollateral(uint256 _loanId) external
    {
        (,uint256 _amount, uint256 _collateralAmount,,,) = loans.getLoanDetails(_loanId);

        (uint256 _liquidationAmount, uint256 _coveredDebt) = collaterals.liquidate(msg.sender, _amount, _collateralAmount);
        lendingPool.repay{value: _coveredDebt}();
        loans.liquidateCollateral(_loanId, _coveredDebt, _liquidationAmount);
    }
}
