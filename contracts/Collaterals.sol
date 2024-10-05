// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Interfaces/ICollaterals.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract Collaterals is Ownable, ReentrancyGuard, ICollaterals {
    uint8 public constant ltv = 80;
    
    IERC20 usdtContract;
    // 0xEe9F2375b4bdF6387aa8265dD4FB8F16512A1d46
    AggregatorV3Interface usdtPriceFeed;

    constructor(address _usdtAddress, address _usdtPriceFeedAddress)
    Ownable(msg.sender)
    {
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

    function depositCollateral(address _borrower, uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external onlyOwner nonReentrant
    {
        require(validateLTV(_ethBorrowAmountInWei, _usdtCollateralAmount)); // TODO: Custom error message
        
        uint256 _usdtAmount = _usdtCollateralAmount * 1e6; // TODO: Possibly switch to a more dynamic approach. Get decimals from the contract.
        
        require(usdtContract.allowance(_borrower, address(this)) >= _usdtAmount); // TODO: Custom error message
        
        usdtContract.transferFrom(_borrower, address(this), _usdtAmount);
    }

    function withdrawCollateral(address _borrower, uint256 _collateralAmount) external onlyOwner nonReentrant
    {
        bool success = usdtContract.approve(_borrower, _collateralAmount);

        require(success); // TODO
    }
}
