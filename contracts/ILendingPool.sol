// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ILendingPool {
    function lendETH(address _borrower, uint256 amount) external;
}
