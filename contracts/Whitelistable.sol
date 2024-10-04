// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Whitelistable is Ownable {
    mapping(address => bool) whitelist;

    modifier onlyWhitelist() {
        require(whitelist[msg.sender], "Unauthorized");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function addWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }
}
