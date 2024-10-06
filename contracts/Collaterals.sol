// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

contract Collaterals is Ownable, ReentrancyGuard, ICollaterals {
    uint8 public constant ltv = 80;
    uint8 public constant liquidatorBonus = 5;
    
    IERC20 immutable usdtContract;
    IERC20 immutable wethContract;
    IWETH immutable wethSpecificContract;
    // 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46
    AggregatorV3Interface immutable usdtPriceFeed;
    IUniswapV2Router01 immutable uniswapRouter;

    constructor(address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouter)
    Ownable(msg.sender)
    {
        usdtContract = IERC20(_usdtAddress);
        wethContract = IERC20(_wethAddress);
        wethSpecificContract = IWETH(_wethAddress);
        usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeedAddress);
        uniswapRouter = IUniswapV2Router01(_uniswapRouter);
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

    function calculateLiquidation(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) public pure returns (uint256)
    {
        return ((_ethBorrowAmountInWei * 10 / _weiPerUSDT) - (8 * _usdtCollateralAmount)) / 2;

        // _usdtCollateralAmount = 12000
        // _ethBorrowAmountInWei = 4000000000000000000
        // _weiPerUSDT = 400000000000000
        // ((4000000000000000000 * 10 / 400000000000000) - (8 * 12000)) / 2 = 2000
        // ((_ethBorrowAmountInWei * 10 / _weiPerUSDT) - (8 * _usdtCollateralAmount)) / 2
        // 4000000000000000000/(12000*500000000000000)
        
        // Steps:
        // LTV Formula: (_ethBorrowAmountInWei * 100) / (_weiPerUSDT * _usdtCollateralAmount)
        // Valid LTV: (4000000000000000000 * 100) / (500000000000000 * 12000)
        // Price of ETH increased from 2000 USDT to 2500 USDT. So now _weiPerUSDT = 400000000000000
        // Invalid LTV: (4000000000000000000 * 100) / (400000000000000 * 12000)
        // Liquidation Amount Formula: ((_ethBorrowAmountInWei * 10 / _weiPerUSDT) - (8 * _usdtCollateralAmount)) / 2;
        // Liquidation Amount: ((4000000000000000000 * 10 / 400000000000000) - (8 * 12000)) / 2 = 2000
        // Liquidate: ((4000000000000000000 - (2000 * 400000000000000)) * 100) / (400000000000000 * (12000 - 2000))
        // Valid LTV: (3200000000000000000 * 100) / (400000000000000 * 10000)
    }

    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        require(validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount)); // TODO: Custom error message
        
        uint256 _usdtAmount = _usdtCollateralAmount * 1e6; // TODO: Possibly switch to a more dynamic approach. Get decimals from the contract.
        
        require(usdtContract.allowance(_borrower, address(this)) >= _usdtAmount); // TODO: Custom error message
        
        usdtContract.transferFrom(_borrower, address(this), _usdtAmount);
    }

    function withdrawCollateral(address _borrower, uint256 _collateralAmount) external onlyOwner nonReentrant
    {
        bool _success = usdtContract.approve(_borrower, _collateralAmount); // TODO: Check if needs * 1e6
        require(_success); // TODO
    }

    function liquidate(address _liquidator, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant returns(uint256 _liquidationAmount, uint256 _coveredDebt)
    {
        uint256 _weiPerUSDT = getWeiPerUSDT();
        uint256 _currentLTV = calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        assert(_currentLTV > ltv);

        uint256 liquidationAmount = calculateLiquidation(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
        uint256 liquidatorIncentive = liquidationAmount * liquidatorBonus / 100;

        // liquidationAmount into WETH and then unwrap WETH to ETH
        uint256 wethAmount = swapUSDTForWETH(liquidationAmount, liquidationAmount * _weiPerUSDT); // TODO: liquidationAmount * _weiPerUSDT check if this should be in WEI
        wethSpecificContract.withdraw(wethAmount); // TODO: Upon receiving ETH, move it to the owner (LendingPlatform)

        (bool _success,) = owner().call{value: wethAmount}("");
        require(_success);

        // Pay liquidator
        _success = usdtContract.approve(_liquidator, liquidatorIncentive);
        require(_success); // TODO

        _liquidationAmount = liquidationAmount + liquidatorIncentive;
        _coveredDebt = wethAmount;
    }
    
    function swapUSDTForWETH(uint256 amountIn, uint256 amountOutMin) internal returns (uint256)
    {
        usdtContract.approve(address(uniswapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(usdtContract);
        path[1] = address(wethContract);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp);

        // amounts[0] = USDT amount, amounts[1] = WETH amount
        return amounts[1];
    }
}
