// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ILendingPlatform.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";

contract LendingPlatform is ILendingPlatform {
    ILendingPool lendingPool;
    ICollaterals collaterals;

    constructor(address _lendingPoolAddress, address _collateralsAddress) {
        lendingPool = ILendingPool(_lendingPoolAddress);
        collaterals = ICollaterals(_collateralsAddress);
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
    }
    
    // TODO: Add partial repayment
    // TODO: Add collateral refund
    function repayETHDebt(uint256 _loanId) external payable
    {
        lendingPool.repay{value: msg.value}(_loanId);
        // TODO: collaterals.refundCollateral
    }
}
