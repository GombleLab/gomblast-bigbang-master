// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {IRandomOracle} from "./IRandomOracle.sol";

contract MockRandomOracle is IRandomOracle {
    function getRandomNumber() external view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
    }
}
