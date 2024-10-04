// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Whitelistable.sol";
import "./Interfaces/ILoans.sol";
import "./Interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is Whitelistable, ReentrancyGuard, ILendingPool {
    uint256 totalETHDeposit;

    address[] lenders;
    mapping(address => uint256) lenderAmounts;
    mapping(address => uint256) lenderAvailableAmounts;
    mapping(address => bool) lenderHasDeposited;

    ILoans loans;

    constructor(address _loansAddress) {
        loans = ILoans(_loansAddress);
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

        lenderAvailableAmounts[_lender] += msg.value;
        lenderAmounts[_lender] += msg.value;
        totalETHDeposit += msg.value;
    }

    function withdraw(address _lender, uint256 _amount) external onlyWhitelist nonReentrant {
        require(lenderAvailableAmounts[_lender] >= _amount, "Not enough amount.");
        
        lenderAvailableAmounts[_lender] -= _amount;

        if (_amount >= lenderAmounts[_lender]) {
            lenderAmounts[_lender] = 0;
        } else {
            lenderAmounts[_lender] -= _amount;
        }

        if (_amount >= totalETHDeposit) {
            totalETHDeposit = 0;
        } else {
            totalETHDeposit -= _amount;
        }

        (bool _success, ) = _lender.call{value: _amount}("");
        
        require(_success);
    }
    
    // TODO: Restrict borrowing from themselves
    function lend(address _borrower, uint256 _amount) external onlyWhitelist nonReentrant {
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
        
        loans.newLoan(_borrower, _amount, _validLenderAddresses, _validLentAmounts);
        
        (bool _success, ) = _borrower.call{value: _amount}("");

        require(_success);
    }

    function repay(uint256 _loanId) external payable onlyWhitelist nonReentrant
    {
        uint256 _totalDebt = loans.calculateDebt(_loanId);
        
        require(msg.value >= _totalDebt); // TODO: Custom error
        
        (uint256 _loanAmount, address _borrower, address[] memory _lenderAddresses, uint256[] memory _lentAmounts) = loans.getLoanRepaymentDetails(_loanId);
        
        for (uint256 i = 0; i < _lenderAddresses.length; i++) {
            uint256 _amount = _lentAmounts[i] * _totalDebt / _loanAmount;
            lenderAvailableAmounts[_lenderAddresses[i]] += _amount;
        }
        
        if (msg.value > _totalDebt)
        {
            uint256 _refund = msg.value - _totalDebt;
            (bool _success,) = _borrower.call{value: _refund}("");
            
            require(_success);
        }

        loans.loanPaid(_loanId);
    }
}
