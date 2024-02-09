// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

interface ISwapRouter {
    function swap(address from, address to, uint256 inAmount, uint256 minOutAmount)
        external
        returns (uint256 outAmount);
}
