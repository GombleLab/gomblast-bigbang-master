// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./IRandomOracle.sol";
import "./INativeSwap.sol";

interface ITreasury {
    event Register(address indexed user);
    event Unregister(address indexed user);
    event Distribute(uint256 amount, uint256 snapshot);
    event ClaimInterest(address indexed user, uint256 amount);
    event Win(address indexed winner, uint256 winAmount, uint256 burnAmount);
    event ClaimWinPrize(address indexed user, uint256 amount);

    error UserAlreadyRegistered();
    error UnregisteredUser();
    error InsufficientPot();
    error NativeTransferFailed();

    struct UserInfo {
        bool registered;
        uint64 position;
        uint128 winAmount;
        uint256 snapshot;
    }

    function token() external view returns (IERC20);

    function rewardSnapshot() external view returns (uint256);

    function unclaimedInterest() external view returns (uint256);

    function unclaimedWinPrize() external view returns (uint256);

    function totalUsers() external view returns (uint256);

    function isRegistered(address user) external view returns (bool);

    function minimumPot() external view returns (uint256);

    function nativeSwap() external view returns (INativeSwap);

    function burnRate() external view returns (uint256);

    function randomOracle() external view returns (IRandomOracle);

    function claimableInterest(address user) external view returns (uint256);

    function getUserInfo(address user) external view returns (UserInfo memory);

    function distribute(uint256 minOut) external;

    function selectWinner(uint256 minOut) external returns (address winner);

    function claimInterest(address user) external;

    function claimWinPrize(address user) external;

    function register(address user) external;

    function unregister(address user) external;
}
