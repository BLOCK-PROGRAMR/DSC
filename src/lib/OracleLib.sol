//SPDX-License-Identifier:MIT

pragma solidity ^0.8.22;
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib_stalePrice();
    uint256 constant TIMEOUT = 3 hours; // stateless

    function staleChecklatestprice(
        AggregatorV3Interface pricefeed
    )
        public
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        (roundId, answer, startedAt, updatedAt, answeredInRound) = pricefeed
            .latestRoundData();

        uint256 sinceCheck = block.timestamp - updatedAt;
        if (sinceCheck > TIMEOUT) revert OracleLib_stalePrice();
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
