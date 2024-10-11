// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

/// @title Collaterals Contract
/// @notice This contract manages collateral deposits, withdrawals, and liquidation for borrowers.
contract Collaterals is Ownable, ReentrancyGuard, ICollaterals {

    /// @notice The maximum Loan-to-Value (LTV) ratio allowed for collateralized loans, set to 80%
    uint8 public constant ltv = 80;

    /// @notice Number of decimals for the token used in the collateral (USDT)
    uint256 public immutable tokenDecimalsCount;
    
    /// @notice Interface for the USDT token contract
    IERC20 immutable usdtContract;

    /// @notice Interface for the Wrapped ETH (WETH) contract
    IWETH immutable wethContract;

    /// @notice Interface for fetching the price of USDT in ETH via Chainlink price feed
    AggregatorV3Interface immutable usdtPriceFeed;

    /// @notice Uniswap V2 router interface for swapping tokens
    IUniswapV2Router02 immutable uniswapRouter;

    /// @notice Event emitted when collateral is deposited by a borrower
    event CollateralDeposited(address borrower, uint256 ethBorrowAmountInWei, uint256 usdtCollateralAmount);

    /// @notice Event emitted when collateral is withdrawn by a borrower
    event CollateralWithdrawn(address borrower, uint256 usdtCollateralAmount);

    /// @notice Event emitted when collateral is liquidated due to an invalid Loan-to-Value (LTV) ratio
    event CollateralLiquidated(uint256 liquidationAmount, uint256 coveredDebt);

    /// @notice Constructor to initialize contract with necessary parameters
    /// @param _tokenDecimalsCount The number of decimals for USDT token
    /// @param _usdtAddress The address of the USDT token contract
    /// @param _wethAddress The address of the Wrapped ETH (WETH) token contract
    /// @param _usdtPriceFeedAddress The address of the Chainlink price feed for USDT/ETH
    /// @param _uniswapRouterAddress The address of the Uniswap V2 router contract
    constructor(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress)
    Ownable(msg.sender)
    {
        tokenDecimalsCount = _tokenDecimalsCount;
        usdtContract = IERC20(_usdtAddress);
        wethContract = IWETH(_wethAddress);
        usdtPriceFeed = AggregatorV3Interface(_usdtPriceFeedAddress);
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
    }

    /// @notice Allows the contract to receive ETH, but only from the WETH contract
    receive() external payable
    {
        require(msg.sender == address(wethContract), "Only WETH contract can send ETH");
    }

    /// @notice Internal function to adjust amounts based on token decimals
    /// @param _amount Amount of USDT to convert
    /// @return Converted amount with decimals
    function _getAmountWithDecimals(uint256 _amount) internal view returns (uint256)
    {
        return tokenDecimalsCount == 0 ? _amount : _amount * (10 ** tokenDecimalsCount);
    }

    /// @notice Internal function to retrieve the current price of USDT in WEI from the Chainlink price feed
    /// @return The current price of 1 USDT in wei
    function _getWeiPerUSDT() internal view returns (uint256)
    {
        (, int256 price,,,) = usdtPriceFeed.latestRoundData();
        
        require(price > 0, "Failed to retrieve price feed.");
        
        // latestRoundDate() returns the price multiplied by 10^8. So by multiplying it by 1e10 we normalize the value into WEI.
        uint256 _weiPerUSDT = uint256(price) * 1e10;

        return _weiPerUSDT;
    }

    /// @notice Internal function to calculate Loan-to-Value (LTV) ratio
    /// @param _ethBorrowAmountInWei Amount of ETH borrowed (in wei)
    /// @param _usdtCollateralAmount Amount of USDT collateral provided
    /// @param _weiPerUSDT Current price of USDT in wei
    /// @return Calculated LTV ratio as a percentage
    function _calculateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) internal pure returns (uint256)
    {
        return (_ethBorrowAmountInWei * 100) / (_weiPerUSDT * _usdtCollateralAmount);
    }

    /// @notice Public function to validate the Loan-to-Value ratio
    /// @param _ethBorrowAmountInWei Amount of ETH borrowed (in wei)
    /// @param _usdtCollateralAmount Amount of USDT collateral provided
    /// @return True if LTV is valid, otherwise false
    function validateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) public view returns (bool)
    {
        uint256 _weiPerUSDT = _getWeiPerUSDT();
        uint256 _currentLTV = _calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);
        
        return _currentLTV <= ltv;
    }

    /// @notice Internal function to calculate liquidation amount
    /// @param _ethBorrowAmountInWei Amount of ETH borrowed (in wei)
    /// @param _usdtCollateralAmount Amount of USDT collateral provided
    /// @param _weiPerUSDT Current price of USDT in wei
    /// @return Amount to liquidate
    function _calculateLiquidation(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount, uint256 _weiPerUSDT) internal pure returns (uint256)
    {
        uint256 _borrowedAmountInUSDT = (_ethBorrowAmountInWei * 10 / _weiPerUSDT);
        uint256 _collateral = (8 * _usdtCollateralAmount);
        
        if (_borrowedAmountInUSDT < _collateral) {
            return 0;
        } else {
            return (_borrowedAmountInUSDT - _collateral) / 2;
        }
    }

    /// @notice Allows the contract owner to deposit collateral for a borrower
    /// @param _borrower Address of the borrower
    /// @param _ethBorrowAmountInWei Amount of ETH borrowed (in wei)
    /// @param _usdtCollateralAmount Amount of USDT collateral provided
    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        require(validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount), "Invalid LTV: Borrowed amount must be less than 80% of the collateral.");
        
        uint256 _usdtAmount = _getAmountWithDecimals(_usdtCollateralAmount);
        require(usdtContract.allowance(_borrower, address(this)) >= _usdtAmount, "No allowance for the collateral funds.");
        
        bool _success = usdtContract.transferFrom(_borrower, address(this), _usdtAmount);
        require(_success, "Failed to deposit collateral.");

        emit CollateralDeposited(_borrower, _ethBorrowAmountInWei, _usdtCollateralAmount);
    }

    /// @notice Allows the contract owner to withdraw collateral for a borrower
    /// @param _borrower Address of the borrower
    /// @param _usdtCollateralAmount Amount of USDT collateral to withdraw
    function withdrawCollateral(address _borrower, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        bool _success = usdtContract.transfer(_borrower, _getAmountWithDecimals(_usdtCollateralAmount));
        require(_success, "Failed to refund collateral.");

        emit CollateralWithdrawn(_borrower, _usdtCollateralAmount);
    }

    /// @notice Allows the contract owner to liquidate collateral when LTV ratio is exceeded
    /// @param _liquidator Address of the liquidator
    /// @param _ethBorrowAmountInWei Amount of ETH borrowed (in wei)
    /// @param _usdtCollateralAmount Amount of USDT collateral provided
    /// @return _totalLiquidatedUSDTAmount Total amount of collateral liquidated
    /// @return _coveredDebtInWEI Amount of debt covered by liquidation
    function liquidate(address _liquidator, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant returns (uint256 _totalLiquidatedUSDTAmount, uint256 _coveredDebtInWEI)
    {
        uint256 _weiPerUSDT = _getWeiPerUSDT();
        uint256 _currentLTV = _calculateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        assert(_currentLTV > ltv);

        _totalLiquidatedUSDTAmount = _calculateLiquidation(_ethBorrowAmountInWei, _usdtCollateralAmount, _weiPerUSDT);

        _coveredDebtInWEI = _swapUSDTForWETH(_getAmountWithDecimals(_totalLiquidatedUSDTAmount), _totalLiquidatedUSDTAmount * _weiPerUSDT);
        wethContract.withdraw(_coveredDebtInWEI);

        (bool _success,) = owner().call{value: _coveredDebtInWEI}("");
        require(_success, "Failed to send liquidated amount.");

        emit CollateralLiquidated(_totalLiquidatedUSDTAmount, _coveredDebtInWEI);
    }

    /// @notice Swaps USDT for WETH using Uniswap V2
    /// @param amountIn Amount of USDT to swap
    /// @param amountOutMin Minimum amount of WETH to receive from the swap
    /// @return Amount of WETH received from the swap
    function _swapUSDTForWETH(uint256 amountIn, uint256 amountOutMin) internal returns (uint256)
    {
        usdtContract.approve(address(uniswapRouter), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(usdtContract);
        path[1] = address(wethContract);

        uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(amountIn, amountOutMin, path, address(this), block.timestamp);

        return amounts[1];
    }
}
