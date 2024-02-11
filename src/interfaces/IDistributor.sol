// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./ISwapRouter.sol";

interface IDistributor {
    error AlreadyRegistered();
    error NotRegistered();

    event Distribute(address indexed payment, uint256 amount, uint256 rewardAmount);
    event Claim(address indexed receiver, uint256 amount);
    event Register(address indexed receiver);
    event Unregister(address indexed receiver);

    function rewardToken() external view returns (IERC20);

    function swapRouter() external view returns (ISwapRouter);

    function rewardSnapshot() external view returns (uint256);

    function totalReceivers() external view returns (uint256);

    function isRegistered(address user) external view returns (bool);

    function getUserSnapshot(address user) external view returns (uint256);

    function claimable(address user) external view returns (uint256);

    function distribute(address payment, uint256 amount, uint256 minOut) external;

    function claim(address user) external;

    function register(address receiver) external;

    function unregister(address receiver) external;
}
