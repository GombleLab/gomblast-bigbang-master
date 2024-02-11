// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./IRandomOracle.sol";
import "./ISwapRouter.sol";

interface IGamble {
    error AlreadyJoined();
    error InsufficientPot();

    event Join(address indexed user, uint256 indexed round, uint256 index);
    event SelectWinner(address indexed winner, uint256 indexed round, uint256 pot, uint256 winAmount);
    event Claim(address indexed user, uint256 amount);
    event Collect(address indexed recipient, uint256 amount);

    struct UserInfo {
        uint64 lastParticipatedRoundId;
        uint64 index;
        uint128 winAmount;
    }

    function entryToken() external view returns (IERC20);

    function rewardToken() external view returns (IERC20);

    function swapRouter() external view returns (ISwapRouter);

    function randomOracle() external view returns (IRandomOracle);

    function burnRate() external view returns (uint256);

    function joinAmount() external view returns (uint256);

    function currentPot() external view returns (uint256);

    function minimumPot() external view returns (uint256);

    function currentRound() external view returns (uint64);

    function totalUnclaimedAmount() external view returns (uint256);

    function totalUsers(uint256 round) external view returns (uint256);

    function getAllUsers(uint256 round) external view returns (address[] memory);

    function getUser(uint256 round, uint256 position) external view returns (address);

    function getUsers(uint256 round, uint256 start, uint256 end) external view returns (address[] memory);

    function getUserInfo(address user) external view returns (UserInfo memory);

    function joinWithPermit(address user, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function join(address user) external;

    function selectWinner(uint256 minOut) external returns (address winner);

    function claim(address user) external;

    function collectable() external view returns (uint256);

    function collect(address recipient) external;
}
