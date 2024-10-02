// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILendingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LendingPool is ReentrancyGuard, Ownable, ILendingPool {
    uint256 totalETHDeposit;
    address borrowerContract;

    address[] lenders;
    mapping(address => uint256) lenderAmounts;
    mapping(address => bool) lenderHasDeposited;
    mapping(address => mapping(address => uint256)) borrower;

    modifier onlyBorrower() {
        require(msg.sender == borrowerContract, "Not authorized!");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setBorrowerContract(address _borrowerContract) external onlyOwner {
        borrowerContract = _borrowerContract;
    }

    function getAvailableETHAmount() public view returns (uint256) {
        return lenderAmounts[msg.sender];
    }

    function depositETH() public payable {
        require(msg.value > 0, "Lending amount must be greater than 0!");

        if (!lenderHasDeposited[msg.sender])
        {
            lenderHasDeposited[msg.sender] = true;
            lenders.push(msg.sender);
        }

        lenderAmounts[msg.sender] += msg.value;
        totalETHDeposit += msg.value;
    }

    function withdrawETH(uint256 _amount) public nonReentrant {
        require(lenderAmounts[msg.sender] >= _amount, "Not enough amount.");

        (bool _success, ) = msg.sender.call{value: _amount}("");
        
        require(_success);
        
        totalETHDeposit -= _amount;
    }

    function lendETH(address _borrower, uint256 _amount) external onlyBorrower nonReentrant {
        uint256 totalETH = address(this).balance;

        require(totalETH >= _amount); // TODO: Custom error message

        // Percentage: (x / y) * 100
        for (uint256 i = 0; i < lenders.length; i++) {
            uint256 lentAmount = (lenderAmounts[lenders[i]] / totalETHDeposit) * _amount;
            borrower[_borrower][lenders[i]] += lentAmount;
        }
        
        (bool _success, ) = _borrower.call{value: _amount}("");

        require(_success);
    }
}
