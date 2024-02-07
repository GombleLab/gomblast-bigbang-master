// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INativeSwap {
    function token() external view returns (address);

    function swapToNative(uint256 amount, uint256 minOut) external returns (uint256 out);

    function swapFromNative(uint256 minOut) external payable returns (uint256 out);
}
