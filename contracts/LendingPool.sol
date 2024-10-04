// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILoans.sol";
import "./ILendingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is ReentrancyGuard, Ownable, ILendingPool {
    uint256 totalETHDeposit;
    address borrowerContract;

    address[] lenders;
    mapping(address => uint256) lenderAmounts;
    mapping(address => uint256) lenderAvailableAmounts;
    mapping(address => bool) lenderHasDeposited;

    ILoans loans;

    modifier onlyBorrower() {
        require(msg.sender == borrowerContract, "Not authorized!");
        _;
    }

    constructor(address _loansAddress) Ownable(msg.sender) {
        loans = ILoans(_loansAddress);
    }

    function setBorrowerContract(address _borrowerContract) external onlyOwner {
        borrowerContract = _borrowerContract;
    }

    function getAvailableETHAmount() public view returns (uint256) {
        return lenderAvailableAmounts[msg.sender];
    }

    function depositETH() public payable {
        require(msg.value > 0, "Lending amount must be greater than 0!");

        if (!lenderHasDeposited[msg.sender])
        {
            lenderHasDeposited[msg.sender] = true;
            lenders.push(msg.sender);
        }

        lenderAvailableAmounts[msg.sender] += msg.value;
        lenderAmounts[msg.sender] += msg.value;
        totalETHDeposit += msg.value;
    }

    function withdrawETH(uint256 _amount) public nonReentrant {
        require(lenderAvailableAmounts[msg.sender] >= _amount, "Not enough amount.");
        
        lenderAvailableAmounts[msg.sender] -= _amount;

        if (_amount >= lenderAmounts[msg.sender]) {
            lenderAmounts[msg.sender] = 0;
        } else {
            lenderAmounts[msg.sender] -= _amount;
        }

        if (_amount >= totalETHDeposit) {
            totalETHDeposit = 0;
        } else {
            totalETHDeposit -= _amount;
        }

        (bool _success, ) = msg.sender.call{value: _amount}("");
        
        require(_success);
    }
    
    // TODO: Restrict borrowing from themselves
    function lendETH(address _borrower, uint256 _amount) external onlyBorrower nonReentrant {
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

            uint256 _lentAmount = _lenderAvailableAmount * _amount / availableETH; // TODO: Double check this
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

    function repayETH(uint256 _loanId) external payable onlyBorrower nonReentrant
    {
        (uint256 _loanAmount, address[] memory _lenderAddresses, uint256[] memory _lentAmounts) = loans.getLoanRepaymentDetails(_loanId);
        
        require(msg.value > _loanAmount); // TODO

        for (uint256 i = 0; i < _lenderAddresses.length; i++) {
            uint256 _amount = _lentAmounts[i] * msg.value / _loanAmount;
            lenderAvailableAmounts[_lenderAddresses[i]] += _amount;
        }
    }
}
