// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

interface ICustomWETH is IERC20, IWETH {
    function transfer(address to, uint value) external override(IERC20, IWETH) returns (bool);
}
