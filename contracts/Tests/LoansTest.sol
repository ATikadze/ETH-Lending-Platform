// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../Loans.sol";

contract LoansTest is Loans
{
    function getDaysElapsed(uint256 _timestamp) internal view override returns(uint256) {
        return (block.timestamp + 365 days - _timestamp) / (24 * 60 * 60);
    }

    function getDaysElapsedTest(uint256 _timestamp) public view returns(uint256) {
        return super.getDaysElapsed(_timestamp);
    }

    function calculateInterestTest(uint256 _amount, uint256 _timestamp) public view returns(uint256) {
        return calculateInterest(_amount, _timestamp);
    }
}