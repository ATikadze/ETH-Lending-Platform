// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./Loans.sol";
import "./LendingPool.sol";
import "./Collaterals.sol";
import "./Interfaces/ILoans.sol";
import "./Interfaces/ILendingPool.sol";
import "./Interfaces/ICollaterals.sol";
import "./Interfaces/ILendingPlatform.sol";
import "./Interfaces/IETHErrors.sol";

/// @title LendingPlatform Contract
/// @notice This contract manages the interactions between loans, lending pool, and collaterals for the ETH lending platform.
contract LendingPlatform is ILendingPlatform, IETHErrors {

    /// @notice The Loans contract that handles loan creation and repayment
    ILoans public loans;

    /// @notice The LendingPool contract that manages the deposits and withdrawals of ETH
    ILendingPool public lendingPool;

    /// @notice The Collaterals contract that manages collateral deposits, withdrawals, and liquidations
    ICollaterals public collaterals;

    /// @notice Custom error thrown when attempting to repay a loan that is already marked as paid
    error LoanAlreadyPaid(uint256 loanId);

    /// @notice Initializes the LendingPlatform with collateral-related parameters
    /// @param _tokenDecimalsCount The number of decimals for USDT token
    /// @param _usdtAddress The address of the USDT token contract
    /// @param _wethAddress The address of the Wrapped ETH (WETH) token contract
    /// @param _usdtPriceFeedAddress The address of the Chainlink price feed for USDT/ETH
    /// @param _uniswapRouterAddress The address of the Uniswap V2 router contract
    constructor(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress) {
        _initializeContracts(_tokenDecimalsCount, _usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouterAddress);
    }

    /// @notice Fallback function to receive ETH; any ETH received is treated as a deposit if the sender is not the Collaterals contract
    receive() external payable
    {
        if (msg.sender != address(collaterals))
            depositETH();
    }

    /// @notice Initializes the Loans, LendingPool, and Collaterals contracts
    /// @param _tokenDecimalsCount The number of decimals for USDT token
    /// @param _usdtAddress The address of the USDT token contract
    /// @param _wethAddress The address of the Wrapped ETH (WETH) token contract
    /// @param _usdtPriceFeedAddress The address of the Chainlink price feed for USDT/ETH
    /// @param _uniswapRouterAddress The address of the Uniswap V2 router contract
    function _initializeContracts(uint256 _tokenDecimalsCount, address _usdtAddress, address _wethAddress, address _usdtPriceFeedAddress, address _uniswapRouterAddress) internal virtual
    {
        loans = new Loans(); // Initializes the Loans contract
        lendingPool = new LendingPool(); // Initializes the LendingPool contract
        collaterals = new Collaterals(_tokenDecimalsCount, _usdtAddress, _wethAddress, _usdtPriceFeedAddress, _uniswapRouterAddress); // Initializes the Collaterals contract
    }

    /// @notice Returns the available ETH amount for a lender
    /// @return The available ETH amount
    function getAvailableAmount() external view returns (uint256) {
        return lendingPool.getAvailableAmount(msg.sender);
    }
    
    /// @notice Allows a lender to deposit ETH into the lending pool
    function depositETH() public payable {
        lendingPool.deposit{value: msg.value}(msg.sender);
    }

    /// @notice Allows a lender to withdraw ETH from the lending pool
    /// @param _amount The amount of ETH to withdraw
    function withdrawETH(uint256 _amount) external {
        lendingPool.withdraw(msg.sender, _amount);
    }
    
    /// @notice Allows a borrower to borrow ETH by providing USDT as collateral
    /// @param _ethBorrowAmountInWei The amount of ETH to borrow (in wei)
    /// @param _usdtCollateralAmount The amount of USDT provided as collateral
    function borrowETH(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external
    {
        collaterals.depositCollateral(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
        lendingPool.lend(msg.sender, _ethBorrowAmountInWei);
        loans.newLoan(msg.sender, _ethBorrowAmountInWei, _usdtCollateralAmount);
    }
    
    /// @notice Allows a borrower to repay their loan in ETH
    /// @param _loanId The ID of the loan to be repaid
    function repayETHDebt(uint256 _loanId) external payable
    {
        if (loans.loanPaid(_loanId))
            revert LoanAlreadyPaid(_loanId);

        (address _borrower,, uint256 _collateralAmount,,, uint256 _totalDebt) = loans.getLoanDetails(_loanId);

        require(msg.sender == _borrower, "Only the original borrower can repay the debt.");

        if (msg.value < _totalDebt)
            revert InsufficientEtherSent(msg.value, _totalDebt);
        
        lendingPool.repay{value: _totalDebt}(_borrower);
        collaterals.withdrawCollateral(msg.sender, _collateralAmount);
        loans.markLoanPaid(_loanId);

        if (msg.value > _totalDebt)
        {
            uint256 _refund = msg.value - _totalDebt;
            (bool _success,) = msg.sender.call{value: _refund}("");

            if (!_success)
                revert ETHTransferFailed(msg.sender, _refund);
        }
    }

    /// @notice Allows a liquidator to liquidate a borrower's collateral
    /// @param _loanId The ID of the loan to liquidate
    function liquidateCollateral(uint256 _loanId) external
    {
        if (loans.loanPaid(_loanId))
            revert LoanAlreadyPaid(_loanId);

        (address _borrower, uint256 _amount, uint256 _collateralAmount,,,) = loans.getLoanDetails(_loanId);

        (uint256 _liquidationAmount, uint256 _coveredDebt) = collaterals.liquidate(msg.sender, _amount, _collateralAmount);
        lendingPool.repay{value: _coveredDebt}(_borrower);
        loans.liquidateCollateral(_loanId, _coveredDebt, _liquidationAmount);
    }
}
