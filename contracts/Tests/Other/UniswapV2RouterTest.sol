// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapV2RouterTest {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts)
    {
        bool _success = IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        require(_success, "Unable to receive funds.");

        _success = IERC20(path[1]).transfer(to, amountOutMin);
        require(_success, "Unable to transfer funds.");
        
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountOutMin;
    }
}
