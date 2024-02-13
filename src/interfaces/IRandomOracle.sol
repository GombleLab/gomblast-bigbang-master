// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface IRandomOracle {
    function getRandomNumber(uint256 id) external view returns (uint256);
}
