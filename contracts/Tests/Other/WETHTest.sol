// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "./ERC20Test.sol";
import "contracts/Interfaces/IETHErrors.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

contract WETHTest is ERC20Test, IWETH, IETHErrors {
    constructor() ERC20Test("Test Wrapped Ether", "TWETH") {}

    function transfer(address _to, uint _value) public override(ERC20, IWETH) returns (bool)
    {
        return super.transfer(_to, _value);
    }
    
    function deposit() external payable
    {
    }

    function withdraw(uint _amount) external
    {
        if (balanceOf(msg.sender) < _amount)
            revert InsufficientEtherBalance(_amount, balanceOf(msg.sender));

        if (address(this).balance < _amount)
            revert InsufficientEtherBalance(_amount, address(this).balance);

        _update(msg.sender, address(0), _amount);
        (bool _success,) = msg.sender.call{value: _amount}("");
        
        if (!_success)
            revert ETHTransferFailed(msg.sender, _amount);
    }
}
