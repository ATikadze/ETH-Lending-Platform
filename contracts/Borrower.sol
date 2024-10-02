// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ILendingPool.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Borrower is ReentrancyGuard
{
    uint8 constant public ltv = 80;
    uint8 constant public ethAPR = 5;
    
    ILendingPool lendingPool;
    IERC20 usdtContract;
    // 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46
    AggregatorV3Interface usdtPriceFeed;
    
    mapping(address => uint256[]) borrowTimestamps;
    mapping(address => mapping(uint256 => uint256)) borrowers;

    constructor(address _lendingPoolAddress, address _usdtAddress, address _usdtPriceFeedAddress) {
        lendingPool = ILendingPool(_lendingPoolAddress);
        usdtContract = IERC20(_usdtAddress);
        usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeedAddress);
    }

    function getWeiPerUSDT() private view returns(uint256)
    {
        (,int256 price,,,) = usdtPriceFeed.latestRoundData(); // latestRoundDate returns the price * 10^8
        uint256 _weiPerUSDT = uint256(price) * 1e10;

        return _weiPerUSDT;
    }

    function calculateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) private pure returns(uint256)
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

        borrowers[msg.sender][block.timestamp] += _ethBorrowAmountInWei;
        borrowTimestamps[msg.sender].push(block.timestamp);
    }

    function calculateInterest(uint256 _amount, uint256 _timestamp) private view returns(uint256)
    {
        uint256 _daysElapsed = (block.timestamp - _timestamp) / (24 * 60 * 60);
        uint256 _interest = (_amount * ethAPR * (_daysElapsed / 365)) / 100;

        return _interest;
    }
    
    // TODO: Add partial repayment
    function repayETH() external payable nonReentrant
    {
        require(msg.value > 0); // TODO: Custom error
        
        uint256 _accumulatedDebt = 0;

        for (uint256 i = 0; i < borrowTimestamps[msg.sender].length; i++)
        {
            uint256 _timestamp = borrowTimestamps[msg.sender][i];
            uint256 _amount = borrowers[msg.sender][_timestamp];
            
            if (_timestamp == 0 || _amount == 0)
                continue;
                
            uint256 _totalAmount = _amount + calculateInterest(_amount, _timestamp);

            if (_accumulatedDebt + _totalAmount >= msg.value)
                break;
            
            _accumulatedDebt += _totalAmount;

            borrowTimestamps[msg.sender][i] = 0;
            borrowers[msg.sender][_timestamp] = 0;
        }

        require(_accumulatedDebt > 0); // TODO: Custom error
        
        if (msg.value > _accumulatedDebt)
        {
            uint256 _refund = msg.value - _accumulatedDebt;
            (bool _success,) = msg.sender.call{value: _refund}("");
            
            require(_success);
        }
    }
}
