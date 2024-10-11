// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface ITokenErrors {
    /// @notice Thrown when requested token allowance exceeds available allowance.
    /// @param owner The address of the token owner.
    /// @param spender The address of the spender.
    /// @param requestedAllowance The amount of allowance requested.
    /// @param availableAllowance The available allowance for the spender.
    error NotEnoughTokenAllowance(address owner, address spender, uint256 requestedAllowance, uint256 availableAllowance);

    /// @notice Thrown when the token approval operation fails.
    /// @param owner The address of the token owner.
    /// @param spender The address of the spender.
    /// @param amount The amount of tokens attempted to be approved.
    error TokenApproveFailed(address owner, address spender, uint256 amount);
    
    /// @notice Thrown when a token transfer fails.
    /// @param owner The address of the token owner.
    /// @param recipient The address of the recipient to whom tokens were transferred.
    /// @param amount The amount of tokens attempted to be transferred.
    error TokenTransferFailed(address owner, address recipient, uint256 amount);
}
