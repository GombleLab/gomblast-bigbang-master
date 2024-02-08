// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import "./IRandomOracle.sol";
import "./INativeSwap.sol";

interface ITreasury {
    event Register(address indexed receiver);
    event Unregister(address indexed receiver);
    event Distribute(uint256 amount, uint256 snapshot);
    event ClaimInterest(address indexed receiver, uint256 amount);
    event Win(uint64 indexed roundId, address indexed winner, uint256 winAmount);
    event ClaimWinPrize(address indexed user, uint256 amount);
    event Join(address indexed user, uint64 indexed roundId, uint64 index);

    error ReceiverAlreadyRegistered();
    error UnregisteredReceiver();
    error InsufficientPot();
    error NativeTransferFailed();
    error AlreadyJoined();

    struct UserInfo {
        uint64 lastParticipatedRoundId;
        uint64 index;
        uint128 winAmount;
        uint256 snapshot;
    }

    function token() external view returns (IERC20);

    function rewardSnapshot() external view returns (uint256);

    function unclaimedInterest() external view returns (uint256);

    function unclaimedWinPrize() external view returns (uint256);

    function roundId() external view returns (uint64);

    function totalUsers(uint256 id) external view returns (uint256);

    function getAllUsers(uint256 id) external view returns (address[] memory);

    function getUser(uint256 id, uint256 position) external view returns (address);

    function getUsers(uint256 id, uint256 start, uint256 end) external view returns (address[] memory);

    function isRegistered(address user) external view returns (bool);

    function currentPot() external view returns (uint256);

    function minimumPot() external view returns (uint256);

    function nativeSwap() external view returns (INativeSwap);

    function burnRate() external view returns (uint256);

    function joinAmount() external view returns (uint256);

    function interestReceiverLength() external view returns (uint256);

    function randomOracle() external view returns (IRandomOracle);

    function claimableInterest(address user) external view returns (uint256);

    function getUserInfo(address user) external view returns (UserInfo memory);

    function distribute(uint256 minOut) external payable;

    function selectWinner() external returns (address winner);

    function claimInterest(address user) external;

    function claimWinPrize(address user) external;

    function join(address user, uint256 minOut) external;

    function register(address receiver) external;

    function unregister(address receiver) external;
}
