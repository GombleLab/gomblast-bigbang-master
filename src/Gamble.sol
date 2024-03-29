// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "@openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-contracts/contracts/access/Ownable2Step.sol";

import "./interfaces/IGamble.sol";

contract Gamble is IGamble, Ownable2Step {
    using SafeERC20 for IERC20;

    uint256 private constant _RATE_PRECISION = 1e6;
    address private constant _BURN_ADDRESS = address(0xdead);

    IERC20 public immutable override entryToken;
    IERC20 public immutable override rewardToken;
    ISwapRouter public immutable override swapRouter;
    IRandomOracle public immutable override randomOracle;
    uint256 public immutable override burnRate;
    uint256 public immutable override joinAmount;
    uint256 public immutable override minimumPot;

    uint256 public override currentPot;
    uint64 public override currentRound = 1;
    uint256 public override totalUnclaimedAmount;
    mapping(address => UserInfo) private _userInfoMap;
    mapping(uint256 round => address[]) private _roundUsers;

    constructor(
        address owner_,
        IERC20 entryToken_,
        IERC20 rewardToken_,
        ISwapRouter swapRouter_,
        IRandomOracle randomOracle_,
        uint256 burnRate_,
        uint256 joinAmount_,
        uint256 minimumPot_
    ) Ownable(owner_) {
        // @dev Assume that all the parameters are valid
        entryToken = entryToken_;
        rewardToken = rewardToken_;
        swapRouter = swapRouter_;
        randomOracle = randomOracle_;
        burnRate = burnRate_;
        joinAmount = joinAmount_;
        minimumPot = minimumPot_;
    }

    function totalUsers(uint256 round) external view returns (uint256) {
        return _roundUsers[round].length;
    }

    function getAllUsers(uint256 round) external view returns (address[] memory) {
        return _roundUsers[round];
    }

    function getUser(uint256 round, uint256 position) external view returns (address) {
        return _roundUsers[round][position];
    }

    function getUsers(uint256 round, uint256 start, uint256 end) external view returns (address[] memory users) {
        users = new address[](end - start + 1);
        for (uint256 i = start; i <= end; ++i) {
            unchecked {
                users[i - start] = _roundUsers[round][i];
            }
        }
    }

    function getUserInfo(address user) external view returns (UserInfo memory) {
        return _userInfoMap[user];
    }

    function joinWithPermit(address user, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        IERC20Permit(address(entryToken)).permit(msg.sender, address(this), joinAmount, deadline, v, r, s);
        join(user);
    }

    function join(address user) public {
        uint256 round = currentRound;
        if (_userInfoMap[user].lastParticipatedRoundId == round) revert AlreadyJoined();
        uint256 amount = joinAmount;
        entryToken.safeTransferFrom(msg.sender, address(this), amount);
        unchecked {
            currentPot += amount;
        }
        uint256 length = _roundUsers[round].length;
        _userInfoMap[user].lastParticipatedRoundId = uint64(round);
        _userInfoMap[user].currentIndex = uint64(length);
        _roundUsers[round].push(user);
        emit Join(user, round, length);
    }

    function selectWinner(uint256 minOut) external onlyOwner returns (address winner) {
        uint256 pot = currentPot;
        if (pot < minimumPot) revert InsufficientPot();

        uint256 round = currentRound;
        uint256 length = _roundUsers[round].length;
        uint256 burnAmount;
        uint256 swapAmount;
        unchecked {
            burnAmount = pot * burnRate / _RATE_PRECISION;
            swapAmount = pot - burnAmount;
            currentRound = uint64(round + 1);
            currentPot = 0;
        }
        entryToken.safeTransfer(_BURN_ADDRESS, burnAmount);
        entryToken.approve(address(swapRouter), swapAmount);

        uint256 beforeBalance = rewardToken.balanceOf(address(this));
        uint256 winAmount = swapRouter.swap(address(entryToken), address(rewardToken), swapAmount, minOut);
        // @dev Assume that the return value is valid
        //      We should check the real balance diff after the swap to avoid draining attack through `collect` function
        if (rewardToken.balanceOf(address(this)) - beforeBalance < winAmount) revert InvalidSwap();

        unchecked {
            totalUnclaimedAmount += winAmount;
        }
        uint256 index = randomOracle.getRandomNumber(round);
        if (index >= length) revert InvalidRandomValue();

        winner = _roundUsers[round][index];
        unchecked {
            _userInfoMap[winner].winAmount += uint128(winAmount);
        }
        emit SelectWinner(winner, round, pot, winAmount);
    }

    function claim(address user) external {
        uint256 amount = _userInfoMap[user].winAmount;
        if (amount > 0) {
            _userInfoMap[user].winAmount = 0;
            unchecked {
                totalUnclaimedAmount -= amount;
            }
            rewardToken.safeTransfer(user, amount);
            emit Claim(user, amount);
        }
    }

    function collectable() public view returns (uint256) {
        unchecked {
            return rewardToken.balanceOf(address(this)) - totalUnclaimedAmount;
        }
    }

    function collect(address recipient) external onlyOwner {
        uint256 amount = collectable();
        rewardToken.safeTransfer(recipient, amount);
        emit Collect(recipient, amount);
    }
}
