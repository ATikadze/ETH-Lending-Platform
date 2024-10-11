// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IETHErrors {
    /// @notice Thrown when an operation requires more Ether than is available.
    /// @param requested The amount of Ether requested.
    /// @param available The amount of Ether available.
    error InsufficientEtherBalance(uint256 requested, uint256 available);

    /// @notice Thrown when the amount of Ether sent is less than required.
    /// @param received The amount of Ether received.
    /// @param minimumRequired The minimum required Ether for the operation.
    error InsufficientEtherSent(uint256 received, uint256 minimumRequired);

    /// @notice Thrown when an Ether transfer to the recipient fails.
    /// @param recipient The recipient address to which the Ether was being sent.
    /// @param amount The amount of Ether that was attempted to be transferred.
    error ETHTransferFailed(address recipient, uint256 amount);
}
