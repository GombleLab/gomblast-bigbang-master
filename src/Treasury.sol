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
    uint256 public immutable override joinAmount;
    INativeSwap public immutable override nativeSwap;
    IRandomOracle public immutable override randomOracle;

    uint256 public override rewardSnapshot = 1 << 128;
    uint256 public override unclaimedInterest;
    uint256 public override unclaimedWinPrize;
    uint256 public override interestReceiverLength;
    uint64 public override roundId = 1;
    mapping(uint256 id => address[] users) private _roundUsers;
    mapping(address user => UserInfo) private _userInfoMap;

    constructor(
        IERC20 token_,
        uint256 minimumPot_,
        uint256 burnRate_,
        uint256 joinAmount_,
        INativeSwap nativeSwap_,
        IRandomOracle randomOracle_
    ) Ownable(msg.sender) {
        token = token_;
        minimumPot = minimumPot_;
        burnRate = burnRate_;
        joinAmount = joinAmount_;
        nativeSwap = nativeSwap_;
        randomOracle = randomOracle_;
    }

    function totalUsers(uint256 id) external view returns (uint256) {
        return _roundUsers[id].length;
    }

    function getAllUsers(uint256 id) external view returns (address[] memory) {
        return _roundUsers[id];
    }

    function getUser(uint256 id, uint256 position) external view returns (address) {
        return _roundUsers[id][position];
    }

    function getUsers(uint256 id, uint256 start, uint256 end) external view returns (address[] memory) {
        address[] memory users = new address[](end - start);
        for (uint256 i = start; i < end; ++i) {
            unchecked {
                users[i - start] = _roundUsers[id][i];
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

    function distribute(uint256 minOut) external payable {
        uint256 out = nativeSwap.swapFromNative{value: msg.value}(minOut);
        if (out == 0) return;

        unclaimedInterest += out;
        rewardSnapshot += (out << 128) / interestReceiverLength;

        emit Distribute(out, rewardSnapshot);
    }

    function currentPot() public view returns (uint256) {
        unchecked {
            return address(this).balance - unclaimedWinPrize;
        }
    }

    function selectWinner() external returns (address winner) {
        uint256 pot = currentPot();
        if (pot < minimumPot) revert InsufficientPot();

        uint64 currentRoundId = roundId;
        uint256 total = _roundUsers[currentRoundId].length;
        uint256 rand = randomOracle.getRandomNumber();
        uint256 winnerIndex = rand % total;
        winner = _roundUsers[currentRoundId][winnerIndex];

        _userInfoMap[winner].winAmount += SafeCast.toUint128(pot);

        unchecked {
            unclaimedWinPrize += pot;
            roundId = currentRoundId + 1;
        }

        emit Win(currentRoundId, winner, pot);
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
        return _userInfoMap[user].snapshot > 0;
    }

    function getUserInfo(address user) external view returns (UserInfo memory) {
        return _userInfoMap[user];
    }

    function join(address user, uint256 minOut) external {
        uint64 currentRoundId = roundId;
        if (_userInfoMap[user].lastParticipatedRoundId == currentRoundId) revert AlreadyJoined();

        token.safeTransferFrom(user, address(this), joinAmount);

        uint256 burnAmount;
        uint256 swapAmount;
        unchecked {
            burnAmount = joinAmount * burnRate / _RATE_PRECISION;
            token.safeTransfer(_BURN_ADDRESS, burnAmount);
            swapAmount = joinAmount - burnAmount;
        }

        _userInfoMap[user].lastParticipatedRoundId = currentRoundId;
        uint64 index = uint64(_roundUsers[currentRoundId].length);
        _userInfoMap[user].index = index;
        _roundUsers[currentRoundId].push(user);

        token.approve(address(nativeSwap), swapAmount);
        nativeSwap.swapToNative(swapAmount, minOut);

        emit Join(user, currentRoundId, index);
    }

    function register(address receiver) external onlyOwner {
        if (isRegistered(receiver)) revert ReceiverAlreadyRegistered();

        unchecked {
            interestReceiverLength++;
        }
        _userInfoMap[receiver].snapshot = rewardSnapshot;

        emit Register(receiver);
    }

    function unregister(address receiver) external onlyOwner {
        if (!isRegistered(receiver)) revert UnregisteredReceiver();
        claimInterest(receiver);

        unchecked {
            interestReceiverLength--;
        }
        _userInfoMap[receiver].snapshot = 0;

        emit Unregister(receiver);
    }

    receive() external payable {}
}
