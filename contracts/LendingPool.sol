// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./MathHelper.sol";
import "./Interfaces/ILendingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title LendingPool Contract
/// @notice This contract manages deposits, withdrawals, and lending for the ETH lending platform.
contract LendingPool is Ownable, ReentrancyGuard, ILendingPool {
    
    using MathHelper for uint256;

    /// @notice Tracks the total amount of ETH deposited in the pool
    uint256 totalETHDeposit;

    /// @notice Array of lender addresses who have deposited ETH
    address[] lenders;

    /// @notice Mapping of lender addresses to their total deposit amounts
    mapping(address => uint256) lenderAmounts;

    /// @notice Mapping of lender addresses to their available amounts for lending
    mapping(address => uint256) lenderAvailableAmounts;

    /// @notice Mapping to track if a lender has deposited before
    mapping(address => bool) lenderHasDeposited;

    /// @notice Emitted when a lender deposits ETH
    /// @param lender The address of the lender
    /// @param amount The amount of ETH deposited
    event Deposited(address lender, uint256 amount);

    /// @notice Emitted when a lender withdraws ETH
    /// @param lender The address of the lender
    /// @param amount The amount of ETH withdrawn
    event Withdrawn(address lender, uint256 amount);

    /// @notice Emitted when ETH is lent to a borrower
    /// @param borrower The address of the borrower
    /// @param amount The amount of ETH lent
    event Lent(address borrower, uint256 amount);

    /// @notice Emitted when a borrower repays their loan
    /// @param borrower The address of the borrower
    /// @param amount The amount of ETH repaid
    /// @param timestamp Timestamp when the event emitted
    event Repaid(address borrower, uint256 amount, uint256 timestamp);

    /// @notice Constructor to initialize the LendingPool contract
    constructor() Ownable(msg.sender) {}

    /// @notice Updates the balance of a lender during deposit/withdraw operations
    /// @param _lender The address of the lender
    /// @param _amount The amount of ETH to update
    /// @param _deposit A boolean indicating whether it's a deposit (true) or a withdrawal (false)
    function _updateBalance(address _lender, uint256 _amount, bool _deposit) internal
    {
        lenderAvailableAmounts[_lender] = lenderAvailableAmounts[_lender].addOrSub(_amount, _deposit);
        lenderAmounts[_lender] = lenderAmounts[_lender].addOrSub(_amount, _deposit);
        totalETHDeposit = totalETHDeposit.addOrSub(_amount, _deposit);
    }

    /// @notice Returns the available amount of ETH for a specific lender
    /// @param _lender The address of the lender
    /// @return The available amount of ETH for the lender
    function getAvailableAmount(address _lender) external view returns (uint256) {
        return lenderAvailableAmounts[_lender];
    }

    /// @notice Allows the contract owner to deposit ETH on behalf of a lender
    /// @param _lender The address of the lender
    function deposit(address _lender) external payable onlyOwner {
        require(msg.value > 0, "Lending amount must be greater than 0!");

        if (!lenderHasDeposited[_lender])
        {
            lenderHasDeposited[_lender] = true;
            lenders.push(_lender);
        }

        _updateBalance(_lender, msg.value, true);

        emit Deposited(_lender, msg.value);
    }

    /// @notice Allows the contract owner to withdraw ETH for a lender
    /// @param _lender The address of the lender
    /// @param _amount The amount of ETH to withdraw
    function withdraw(address _lender, uint256 _amount) external onlyOwner nonReentrant {
        require(lenderAvailableAmounts[_lender] >= _amount, "Not enough available amount to withdraw.");

        _updateBalance(_lender, _amount, false);

        (bool _success, ) = _lender.call{value: _amount}("");
        require(_success, "Failed to withdraw funds.");
        
        emit Withdrawn(_lender, _amount);
    }
    
    /// @notice Lends ETH to a borrower by distributing the loan among available lenders
    /// @param _borrower The address of the borrower
    /// @param _amount The amount of ETH to lend
    function lend(address _borrower, uint256 _amount) external onlyOwner nonReentrant
    {
        uint256 availableETH = address(this).balance;

        require(availableETH >= _amount, "Not enough available Ether to lend.");

        for (uint256 i = 0; i < lenders.length; i++) {
            address _lender = lenders[i];
            uint256 _lenderAvailableAmount = lenderAvailableAmounts[_lender];

            if (_lenderAvailableAmount == 0 && _borrower == _lender)
                continue;

            uint256 _lentAmount = _lenderAvailableAmount * _amount / availableETH;
            lenderAvailableAmounts[_lender] -= _lentAmount;
        }

        (bool _success, ) = _borrower.call{value: _amount}("");
        require(_success, "Failed to lend Ether.");

        emit Lent(_borrower, _amount);
    }

    /// @notice Repays a loan on behalf of the borrower, distributing the repayment to lenders
    /// @param _borrower The address of the borrower
    function repay(address _borrower) external payable onlyOwner nonReentrant
    {
        require(msg.value > 0, "Ether amount must be greater than 0.");

        uint256 _availableETH = address(this).balance - msg.value;

        for (uint256 i = 0; i < lenders.length; i++) {
            address _lender = lenders[i];
            uint256 _lenderAvailableAmount = lenderAvailableAmounts[_lender];

            if (_lenderAvailableAmount == 0 && _borrower == _lender)
                continue;

            uint256 _debtShare = _lenderAvailableAmount * msg.value / _availableETH;
            lenderAvailableAmounts[_lender] += _debtShare;
        }

        emit Repaid(_borrower, msg.value, block.timestamp);
    }
}
