// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ICollaterals.sol";
import "./Interfaces/ICustomWETH.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Collaterals is Ownable, ReentrancyGuard, ICollaterals {
    uint8 public constant ltv = 80;
    uint256 public immutable tokenDecimalsCount;
    
    IERC20 immutable usdtContract;
    ICustomWETH immutable wethContract;
    AggregatorV3Interface immutable usdtPriceFeed;
    IUniswapV2Router02 immutable uniswapRouter;

    event CollateralLiquidated(uint256 liquidationAmount, uint256 coveredDebt);

    constructor(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouter)
    Ownable(msg.sender)
    {
        tokenDecimalsCount = _tokenDecimalsCount;
        usdtContract = IERC20(_usdtAddress);
        wethContract = ICustomWETH(_wethAddress);
        usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeedAddress);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
    }
    
    receive() external payable
    {
        require(msg.sender == address(wethContract));
    }

    function getAmountWithDecimals(uint256 _amount) internal view returns(uint256)
    {
        return tokenDecimalsCount == 0 ? _amount : _amount * (10 ** tokenDecimalsCount);
    }

    function getWeiPerUSDT() internal view returns(uint256)
    {
        (,int256 price,,,) = usdtPriceFeed.latestRoundData();
        
        require(price > 0, "Failed to retrieve price feed.");

        // latestRoundDate() returns the price multiplied by 10^8. So by multiplying it by 1e10 we normalize the value into WEI.
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
        uint256 _currentLTV = calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        return _currentLTV <= ltv;
    }

    function calculateLiquidation(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) internal pure returns (uint256)
    {
        uint256 _borrowedAmountInUSDT = (_ethBorrowAmountInWei * 10 / _weiPerUSDT);
        uint256 _collateral = (8 * _usdtCollateralAmount);
        
        if (_borrowedAmountInUSDT < _collateral) {
            return 0;
        } else {
            return (_borrowedAmountInUSDT - _collateral) / 2;
        }
    }

    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        require(validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount), "Invalid LTV: Borrowed amount must be less than 80% of the collateral.");
        
        uint256 _usdtAmount = getAmountWithDecimals(_usdtCollateralAmount);
        
        require(usdtContract.allowance(_borrower, address(this)) >= _usdtAmount, "No allowance for the collateral funds.");
        
        bool _success = usdtContract.transferFrom(_borrower, address(this), _usdtAmount);
        require(_success, "Failed to deposit collateral.");
    }

    function withdrawCollateral(address _borrower, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        bool _success = usdtContract.transfer(_borrower, getAmountWithDecimals(_usdtCollateralAmount));
        require(_success, "Failed to refund collateral.");
    }

    function liquidate(address _liquidator, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant returns(uint256 _totalLiquidatedAmount, uint256 _coveredDebt)
    {
        uint256 _weiPerUSDT = getWeiPerUSDT();
        uint256 _currentLTV = calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        assert(_currentLTV > ltv);

        _totalLiquidatedAmount = calculateLiquidation(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        uint256 _wethAmount = swapUSDTForWETH(getAmountWithDecimals(_totalLiquidatedAmount), _totalLiquidatedAmount * _weiPerUSDT);
        wethContract.withdraw(_wethAmount);

        (bool _success,) = owner().call{value: _wethAmount}("");
        require(_success, "Failed to send liquidated amount.");

        _coveredDebt = _wethAmount;

        emit CollateralLiquidated(_totalLiquidatedAmount, _wethAmount);
    }
    
    function swapUSDTForWETH(uint256 amountIn, uint256 amountOutMin) internal returns (uint256)
    {
        usdtContract.approve(address(uniswapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(usdtContract);
        path[1] = address(wethContract);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp);

        return amounts[1];
    }
}
