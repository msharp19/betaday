// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract MockOracle {
    int256 public mockPrice;

    constructor(int256 _initialPrice) {
        mockPrice = _initialPrice;
    }

    function setPrice(int256 _newPrice) external {
        mockPrice = _newPrice;
    }

    function latestRoundData() external view returns (
        uint80 roundId, 
        int256 answer, 
        uint256 startedAt, 
        uint256 updatedAt, 
        uint80 answeredInRound
    ) {
        uint256 timestamp = block.timestamp;

        roundId = 10000000000000000000;
        answer = mockPrice;
        startedAt = timestamp;
        updatedAt = timestamp;
        answeredInRound = 10000000000000000001;
    }
}