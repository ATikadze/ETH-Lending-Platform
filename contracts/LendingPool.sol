// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is Ownable, ReentrancyGuard, ILendingPool {
    using SafeMath for uint256;
    
    uint256 totalETHDeposit;

    address[] lenders;
    mapping(address => uint256) lenderAmounts;
    mapping(address => uint256) lenderAvailableAmounts;
    mapping(address => bool) lenderHasDeposited;
    
    constructor() Ownable(msg.sender) {}
    
    // TODO: Test this out
    function updateBalance(address _lender, uint256 _amount, bool _deposit) internal
    {
        lenderAvailableAmounts[_lender] = lenderAvailableAmounts[_lender].addOrSub(_amount, _deposit);
        lenderAmounts[_lender] = lenderAmounts[_lender].addOrSub(_amount, _deposit);
        totalETHDeposit = totalETHDeposit.addOrSub(_amount, _deposit);
    }

    function getAvailableAmount(address _lender) external view onlyOwner returns (uint256) {
        return lenderAvailableAmounts[_lender];
    }

    function deposit(address _lender) external payable onlyOwner {
        require(msg.value > 0, "Lending amount must be greater than 0!");

        if (!lenderHasDeposited[_lender])
        {
            lenderHasDeposited[_lender] = true;
            lenders.push(_lender);
        }

        updateBalance(_lender, msg.value, true);
    }

    function withdraw(address _lender, uint256 _amount) external onlyOwner nonReentrant {
        require(lenderAvailableAmounts[_lender] >= _amount, "Not enough amount.");
        
        updateBalance(_lender, _amount, false);

        (bool _success, ) = _lender.call{value: _amount}("");
        
        require(_success);
    }
    
    // TODO: Restrict borrowing from themselves
    function lend(address _borrower, uint256 _amount) external onlyOwner nonReentrant
    {
        uint256 availableETH = address(this).balance;

        require(availableETH >= _amount); // TODO: Custom error message
        
        for (uint256 i = 0; i < lenders.length; i++) {
            address _lender = lenders[i];
            uint256 _lenderAvailableAmount = lenderAvailableAmounts[_lender];

            if (_lenderAvailableAmount == 0)
                continue;

            uint256 _lentAmount = _lenderAvailableAmount * _amount / availableETH;
            lenderAvailableAmounts[_lender] -= _lentAmount;
        }
        
        (bool _success, ) = _borrower.call{value: _amount}("");

        require(_success);
    }

    function repay() external payable onlyOwner nonReentrant
    {
        require(msg.value > 0);
        
        uint256 _availableETH = address(this).balance - msg.value;
        
        for (uint256 i = 0; i < lenders.length; i++) {
            address _lender = lenders[i];
            uint256 _lenderAvailableAmount = lenderAvailableAmounts[_lender];

            if (_lenderAvailableAmount == 0)
                continue;

            uint256 _debtShare = _lenderAvailableAmount * msg.value / _availableETH;
            lenderAvailableAmounts[_lender] += _debtShare;
        }
    }
}
