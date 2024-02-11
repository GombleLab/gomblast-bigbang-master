// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "./interfaces/IRandomOracle.sol";

contract MockRandomOracle is IRandomOracle {
    mapping(uint256 => uint256) private _randomNumbers;

    function setRandomNumber(uint256 id, uint256 maxValue) external {
        _randomNumbers[id] = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % (maxValue + 1);
    }

    function getRandomNumber(uint256 id) external view returns (uint256) {
        return _randomNumbers[id];
    }
}
