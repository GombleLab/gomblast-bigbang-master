// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

import "./INativeSwap.sol";

contract MockSwap is INativeSwap {
    using SafeERC20 for IERC20;

    uint256 private constant _PRECISION = 1e18;

    address public immutable override token;

    uint256 public swapRate;

    constructor(address token_, uint256 initialRate_) {
        token = token_;
        swapRate = initialRate_;
    }

    function swapToNative(uint256 amount, uint256 minOut) external returns (uint256 out) {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        out = amount * _PRECISION / swapRate;
        require(out >= minOut, "min out");

        (bool success,) = msg.sender.call{value: out}("");
        require(success, "value transfer");
    }

    function swapFromNative(uint256 minOut) external payable returns (uint256 out) {
        out = msg.value * swapRate / _PRECISION;
        require(out >= minOut, "min out");

        IERC20(token).safeTransfer(msg.sender, out);
    }

    function setSwapRate(uint256 newRate) external {
        swapRate = newRate;
    }

    receive() external payable {}
}
