// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICollaterals {
    function validateLTV(uint256 _ethBorrowAmountInWei, uint256 _usdtCollateralAmount) external view returns(bool);
}
