// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../LendingPool.sol";

contract LendingPoolTest is LendingPool {
    constructor(address _loansAddress) LendingPool(_loansAddress) {}
}
