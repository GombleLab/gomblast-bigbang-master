// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/access/Ownable.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/utils/math/SafeCast.sol";

import "./interfaces/ITreasury.sol";

contract Treasury is Ownable, ITreasury {
    using SafeERC20 for IERC20;

    uint256 private constant _RATE_PRECISION = 1e6;
    address private constant _BURN_ADDRESS = address(0xdead);

    IERC20 public immutable override token;
    uint256 public immutable override minimumPot;
    uint256 public immutable override burnRate;
    INativeSwap public immutable override nativeSwap;
    IRandomOracle public immutable override randomOracle;

    uint256 public override rewardSnapshot;
    uint256 public override unclaimedInterest;
    uint256 public override unclaimedWinPrize;
    address[] private _userList;
    mapping(address user => UserInfo) private _userInfoMap;

    constructor(
        IERC20 token_,
        uint256 minimumPot_,
        uint256 burnRate_,
        INativeSwap nativeSwap_,
        IRandomOracle randomOracle_
    ) Ownable(msg.sender) {
        token = token_;
        minimumPot = minimumPot_;
        burnRate = burnRate_;
        nativeSwap = nativeSwap_;
        randomOracle = randomOracle_;
    }

    function totalUsers() external view returns (uint256) {
        return _userList.length;
    }

    function getAllUsers() external view returns (address[] memory) {
        return _userList;
    }

    function getUsers(uint256 start, uint256 end) external view returns (address[] memory) {
        address[] memory users = new address[](end - start);
        for (uint256 i = start; i < end; ++i) {
            unchecked {
                users[i - start] = _userList[i];
            }
        }
        return users;
    }

    function claimableInterest(address user) public view returns (uint256) {
        if (!isRegistered(user)) return 0;
        uint256 userSnapshot = _userInfoMap[user].snapshot;

        uint256 snapshot = rewardSnapshot;
        if (snapshot > userSnapshot) {
            unchecked {
                return (snapshot - userSnapshot) >> 128;
            }
        }
        return 0;
    }

    function distribute(uint256 minOut) external {
        uint256 interest;
        unchecked {
            interest = address(this).balance - unclaimedWinPrize;
        }

        uint256 out = nativeSwap.swapFromNative{value: interest}(minOut);
        if (out == 0) return;

        unclaimedInterest += out;
        rewardSnapshot += (out << 128) / _userList.length;

        emit Distribute(out, rewardSnapshot);
    }

    function selectWinner(uint256 minOut) external returns (address winner) {
        uint256 thisBalance = token.balanceOf(address(this));
        uint256 pot;
        unchecked {
            pot = thisBalance - unclaimedInterest;
        }
        if (pot < minimumPot) revert InsufficientPot();

        uint256 total = _userList.length;
        uint256 rand = randomOracle.getRandomNumber();
        uint256 winnerIndex = rand % total;
        winner = _userList[winnerIndex];

        uint256 burnAmount;
        unchecked {
            burnAmount = pot * burnRate / _RATE_PRECISION;
            token.safeTransfer(_BURN_ADDRESS, burnAmount);
            pot -= burnAmount;
        }

        token.approve(address(nativeSwap), pot);
        uint256 out = nativeSwap.swapToNative(pot, minOut);
        _userInfoMap[winner].winAmount += SafeCast.toUint128(out);
        unclaimedWinPrize += out;

        emit Win(winner, out, burnAmount);
    }

    function claimInterest(address user) public {
        uint256 claimedAmount = claimableInterest(user);
        _userInfoMap[user].snapshot = rewardSnapshot;

        token.safeTransfer(user, claimedAmount);
        unchecked {
            unclaimedInterest -= claimedAmount;
        }

        emit ClaimInterest(user, claimedAmount);
    }

    function claimWinPrize(address user) external {
        uint256 claimedAmount = _userInfoMap[user].winAmount;

        _userInfoMap[user].winAmount = 0;
        unchecked {
            unclaimedWinPrize -= claimedAmount;
        }

        (bool success,) = user.call{value: claimedAmount}("");
        if (!success) revert NativeTransferFailed();

        emit ClaimWinPrize(user, claimedAmount);
    }

    function isRegistered(address user) public view returns (bool) {
        return _userInfoMap[user].registered;
    }

    function getUserInfo(address user) external view returns (UserInfo memory) {
        return _userInfoMap[user];
    }

    function register(address user) external onlyOwner {
        if (isRegistered(user)) revert UserAlreadyRegistered();

        UserInfo storage userInfo = _userInfoMap[user];
        userInfo.registered = true;
        userInfo.position = uint64(_userList.length);
        userInfo.snapshot = rewardSnapshot;

        _userList.push(user);

        emit Register(user);
    }

    function unregister(address user) external onlyOwner {
        if (!isRegistered(user)) revert UnregisteredUser();
        claimInterest(user);

        UserInfo storage userInfo = _userInfoMap[user];
        uint256 position = userInfo.position;
        unchecked {
            _userList[position] = _userList[_userList.length - 1];
        }
        _userList.pop();
        userInfo.registered = false;

        emit Unregister(user);
    }

    receive() external payable {}
}
