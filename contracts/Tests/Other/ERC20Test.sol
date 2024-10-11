// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Test is ERC20, Ownable {
    constructor(string memory _name, string memory _symbol)
    ERC20(_name, _symbol) Ownable(msg.sender) {}

    function mint(address account, uint256 value) public onlyOwner
    {
        _mint(account, value);
    }
}
