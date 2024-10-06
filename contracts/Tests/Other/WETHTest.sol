// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Test.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

contract WETHTest is ERC20Test, IWETH {
    function transfer(address _to, uint _value) public override(ERC20, IWETH) returns (bool)
    {
        return super.transfer(_to, _value);
    }
    
    function deposit() external payable
    {
    }

    function withdraw(uint _amount) external
    {
        require(balanceOf(msg.sender) >= _amount, "Not enough Ether to withdraw.");

        _update(msg.sender, address(0), _amount);
        (bool _success,) = msg.sender.call{value: _amount}("");
        
        require(_success, "Withdrawal of Ether unsuccessful.");
    }
}
