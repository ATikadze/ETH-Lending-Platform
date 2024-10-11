// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

/// @title MathHelper Library
/// @notice Provides utility functions for basic arithmetic operations
library MathHelper {

    /// @notice Adds or subtracts two numbers based on the 'add' flag
    /// @param a First operand
    /// @param b Second operand
    /// @param add If true, addition is performed; otherwise, subtraction
    /// @return Result of addition or subtraction
    function addOrSub(uint256 a, uint256 b, bool add) public pure returns (uint256) {
        if (add) {
            return a + b;
        } else {
            return sub(a, b);
        }
    }

    /// @notice Subtracts one number from another
    /// @param a First operand
    /// @param b Second operand
    /// @return Result of subtraction, or zero if b >= a
    function sub(uint256 a, uint256 b) public pure returns (uint256) {
        if (b >= a) {
            return 0;
        } else {
            return a - b;
        }
    }
}
