// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "./Whitelistable.sol";
import "./Interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is Whitelistable, ReentrancyGuard, ILendingPool {
    using SafeMath for uint256;
    
    uint256 totalETHDeposit;

    address[] lenders;
    mapping(address => uint256) lenderAmounts;
    mapping(address => uint256) lenderAvailableAmounts;
    mapping(address => bool) lenderHasDeposited;
    mapping(uint256 => address[]) lenderAddresses;
    mapping(uint256 => uint256[]) lentAmounts;
    
    // TODO: Test this out
    function updateBalance(address _lender, uint256 _amount, bool _deposit) internal
    {
        lenderAvailableAmounts[_lender] = lenderAvailableAmounts[_lender].addOrSub(_amount, _deposit);
        lenderAmounts[_lender] = lenderAmounts[_lender].addOrSub(_amount, _deposit);
        totalETHDeposit = totalETHDeposit.addOrSub(_amount, _deposit);
    }

    function getAvailableAmount(address _lender) external view onlyWhitelist returns (uint256) {
        return lenderAvailableAmounts[_lender];
    }

    function deposit(address _lender) external payable onlyWhitelist {
        require(msg.value > 0, "Lending amount must be greater than 0!");

        if (!lenderHasDeposited[_lender])
        {
            lenderHasDeposited[_lender] = true;
            lenders.push(_lender);
        }

        updateBalance(_lender, msg.value, true);
    }

    function withdraw(address _lender, uint256 _amount) external onlyWhitelist nonReentrant {
        require(lenderAvailableAmounts[_lender] >= _amount, "Not enough amount.");
        
        updateBalance(_lender, _amount, false);

        (bool _success, ) = _lender.call{value: _amount}("");
        
        require(_success);
    }
    
    // TODO: Restrict borrowing from themselves
    function lend(uint256 _loanId, address _borrower, uint256 _amount) external onlyWhitelist nonReentrant
    {
        uint256 availableETH = address(this).balance;

        require(availableETH >= _amount); // TODO: Custom error message
        
        address[] memory _lenderAddresses = new address[](lenders.length);
        uint256[] memory _lentAmounts = new uint256[](lenders.length);
        uint256 _validLendersCount = 0;

        // Percentage: (x / y) * 100
        for (uint256 i = 0; i < lenders.length; i++) {
            address _lender = lenders[i];
            uint256 _lenderAvailableAmount = lenderAvailableAmounts[_lender];

            if (_lenderAvailableAmount == 0)
                continue;

            uint256 _lentAmount = _lenderAvailableAmount * _amount / availableETH;
            lenderAvailableAmounts[_lender] -= _lentAmount;
            _lenderAddresses[_validLendersCount] = _lender;
            _lentAmounts[_validLendersCount] = _lentAmount;
            _validLendersCount++;
        }
        
        address[] memory _validLenderAddresses = new address[](_validLendersCount);
        uint256[] memory _validLentAmounts = new uint256[](_validLendersCount);

        for (uint256 i = 0; i < _validLendersCount; i++) {
            _validLenderAddresses[i] = _lenderAddresses[i];
            _validLentAmounts[i] = _lentAmounts[i];
        }
        
        lenderAddresses[_loanId] = _validLenderAddresses;
        lentAmounts[_loanId] = _validLentAmounts;
        
        (bool _success, ) = _borrower.call{value: _amount}("");

        require(_success);
    }

    function repay(uint256 _loanId, uint256 _loanAmount, uint256 _totalDebt) external payable onlyWhitelist nonReentrant
    {
        require(msg.value == _totalDebt); // TODO
        
        for (uint256 i = 0; i < lenderAddresses[_loanId].length; i++) {
            uint256 _amount = lentAmounts[_loanId][i] * _totalDebt / _loanAmount;
            lenderAvailableAmounts[lenderAddresses[_loanId][i]] += _amount;
        }
    }
}
