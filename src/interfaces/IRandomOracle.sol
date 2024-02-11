// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface IRandomOracle {
    function setRandomNumber(uint256 id, uint256 maxValue) external;

    function getRandomNumber(uint256 id) external view returns (uint256);
}
