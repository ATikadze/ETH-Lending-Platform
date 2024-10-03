// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILoans.sol";
import "./ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Borrower is ReentrancyGuard
{
    uint8 constant public ltv = 80;
    
    ILoans loans;
    ILendingPool lendingPool;
    IERC20 usdtContract;
    // 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46
    AggregatorV3Interface usdtPriceFeed;

    modifier onlyLoanOwner(uint256 _loanId)
    {
        require(msg.sender == loans.getBorrower(_loanId));
        _;
    }

    constructor(address _loansAddress, address _lendingPoolAddress, address _usdtAddress, address _usdtPriceFeedAddress) {
        loans = ILoans(_loansAddress);
        lendingPool = ILendingPool(_lendingPoolAddress);
        usdtContract = IERC20(_usdtAddress);
        usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeedAddress);
    }

    function getWeiPerUSDT() internal view returns(uint256)
    {
        // latestRoundDate returns the price * 10^8
        (,int256 price,,,) = usdtPriceFeed.latestRoundData();
        uint256 _weiPerUSDT = uint256(price) * 1e10;

        return _weiPerUSDT;
    }

    function calculateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) internal pure returns(uint256)
    {
        return (_ethBorrowAmountInWei * 100) / (_weiPerUSDT * _usdtCollateralAmount);
    }

    function validateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) public view returns(bool)
    {
        uint256 _weiPerUSDT = getWeiPerUSDT();

        require(_weiPerUSDT > 0); // TODO: Custom error message
        
        uint256 _currentLTV = calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        return _currentLTV <= ltv;
    }
    
    // Expecting _ethBorrowAmountInWei in ETH * 10^18 and _usdtCollateralAmount in USDT
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external nonReentrant
    {
        require(validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount)); // TODO: Custom error message
        
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
