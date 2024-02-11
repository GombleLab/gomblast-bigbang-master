// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin-contracts/contracts/access/Ownable.sol";

import "./interfaces/ISwapRouter.sol";

contract MockSwapRouter is ISwapRouter, Ownable {
    using SafeERC20 for IERC20;

    uint256 private constant _PRECISION = 1e18;

    uint256 public swapRate;

    constructor(address owner_, uint256 initialRate_) Ownable(owner_) {
        swapRate = initialRate_;
    }

    function swap(address from, address to, uint256 inAmount, uint256 minOutAmount)
        external
        returns (uint256 outAmount)
    {
        IERC20(from).safeTransferFrom(msg.sender, address(this), inAmount);

        outAmount = inAmount * (10 ** IERC20Metadata(to).decimals()) * swapRate / _PRECISION
            / (10 ** IERC20Metadata(from).decimals());
        require(outAmount >= minOutAmount, "min out");

        IERC20(to).safeTransfer(msg.sender, outAmount);
    }

    function setSwapRate(uint256 newRate) external onlyOwner {
        swapRate = newRate;
    }
}
