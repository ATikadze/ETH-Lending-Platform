// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Test is ERC20, Ownable {
    constructor(address owner) ERC20("Mock USDT", "MUSDT") Ownable(owner) {}

    function mint(address account, uint256 value) public onlyOwner
    {
        _mint(account, value);
    }
}
