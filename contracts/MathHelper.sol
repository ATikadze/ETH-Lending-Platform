// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library MathHelper {
    function addOrSub(uint256 a, uint256 b, bool add) public pure returns (uint256) {
        if (add) {
            return a + b;
        } else {
            return sub(a, b);
        }
    }

    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        if (b >= a) {
            return 0;
        } else {
            return a - b;
        }
    }
}
