// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "../Loans.sol";

contract LoansTest is Loans
{
    function _getDaysElapsed(uint256 _timestamp) internal view override returns(uint256) {
        return (block.timestamp + 365 days - _timestamp) / (24 * 60 * 60);
    }

    function getDaysElapsedTest(uint256 _timestamp) public view returns(uint256) {
        return super._getDaysElapsed(_timestamp);
    }

    function calculateInterestTest(uint256 _amount, uint256 _timestamp) public view returns(uint256) {
        return _calculateInterest(_amount, _timestamp);
    }
}