// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "contracts/Interfaces/ITokenErrors.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UniswapV2RouterTest is ITokenErrors {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts)
    {
        bool _success = IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        
        if (!_success)
            revert TokenTransferFailed(msg.sender, address(this), amountIn);

        _success = IERC20(path[1]).transfer(to, amountOutMin);
        
        if (!_success)
            revert TokenTransferFailed(msg.sender, to, amountOutMin);
        
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        amounts[1] = amountOutMin;
    }
}
