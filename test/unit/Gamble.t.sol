// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/MockToken.sol";
import "../../src/interfaces/ISwapRouter.sol";
import "../../src/interfaces/IGamble.sol";
import "../../src/MockSwapRouter.sol";
import "../../src/Gamble.sol";
import "../../src/MockRandomOracle.sol";

contract GambleTest is Test {
    MockToken public entryToken;
    MockToken public rewardToken;
    ISwapRouter public swapRouter;
    IGamble public gamble;

    address[] public users;

    function setUp() public {
        entryToken = new MockToken("GOMBLAST", "$GBLST", 18);
        rewardToken = new MockToken("USD Tether", "USDT", 6);

        swapRouter = new MockSwapRouter(1e17);

        gamble = new Gamble(
            address(this),
            IERC20(entryToken),
            IERC20(rewardToken),
            swapRouter,
            new MockRandomOracle(),
            20 * 10000,
            10 ether,
            20 ether
        );

        entryToken.mint(address(swapRouter), 100 ether);
        entryToken.mint(address(this), 100 ether);
        entryToken.approve(address(gamble), type(uint256).max);
        rewardToken.mint(address(swapRouter), 100 * 1e6);
        rewardToken.mint(address(this), 100 * 1e6);

        for (uint256 i; i < 5; ++i) {
            address user = address(uint160(1000 + i));
            users.push(user);
            entryToken.mint(user, 100 ether);
            vm.prank(user);
            entryToken.approve(address(gamble), type(uint256).max);
        }
    }

    function testJoin() public {
        uint256 beforeBalance = entryToken.balanceOf(address(this));
        uint256 round = gamble.currentRound();

        vm.expectEmit(address(gamble));
        emit IGamble.Join(users[0], round, 0);
        gamble.join(users[0]);

        assertEq(entryToken.balanceOf(address(this)), beforeBalance - gamble.joinAmount(), "TOKEN_BALANCE");
        assertEq(gamble.totalUsers(round), 1, "TOTAL_USERS");
        assertEq(gamble.getUser(round, 0), users[0], "USER");
        IGamble.UserInfo memory userInfo = gamble.getUserInfo(users[0]);
        assertEq(userInfo.lastParticipatedRoundId, round, "LAST_PARTICIPATED_ROUND_ID");
        assertEq(userInfo.index, 0, "INDEX");
        assertEq(userInfo.winAmount, 0, "WIN_AMOUNT");
        address[] memory allUsers = gamble.getAllUsers(round);
        assertEq(allUsers.length, 1, "ALL_USERS_LENGTH");
        assertEq(allUsers[0], users[0], "ALL_USERS");
    }

    function testJoinMany() public {
        uint256 beforeGambleBalance = entryToken.balanceOf(address(gamble));
        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = entryToken.balanceOf(users[i]);
        }
        uint256 round = gamble.currentRound();
        uint256 currentPot = gamble.currentPot();

        for (uint256 i; i < users.length; ++i) {
            vm.expectEmit(address(gamble));
            emit IGamble.Join(users[i], round, i);
            vm.prank(users[i]);
            gamble.join(users[i]);
        }

        assertEq(
            entryToken.balanceOf(address(gamble)),
            beforeGambleBalance + users.length * gamble.joinAmount(),
            "GAMBLE_BALANCE"
        );
        assertEq(gamble.totalUsers(round), users.length, "TOTAL_USERS");
        assertEq(gamble.currentPot(), currentPot + users.length * gamble.joinAmount(), "POT");

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            assertEq(entryToken.balanceOf(users[i]), beforeUserBalances[i] - gamble.joinAmount(), "USER_BALANCE");
            assertEq(gamble.getUser(round, i), users[i], "USER");
            IGamble.UserInfo memory userInfo = gamble.getUserInfo(users[i]);
            assertEq(userInfo.lastParticipatedRoundId, round, "LAST_PARTICIPATED_ROUND_ID");
            assertEq(userInfo.index, i, "INDEX");
            assertEq(userInfo.winAmount, 0, "WIN_AMOUNT");
        }
    }

    function testJoinTwice() public {
        gamble.join(users[0]);
        vm.expectRevert(abi.encodeWithSelector(IGamble.AlreadyJoined.selector));
        gamble.join(users[0]);
    }

    function testSelectWinner() public {
        uint256[] memory beforeUserRewardBalances = new uint256[](users.length);
        for (uint256 i; i < users.length; ++i) {
            vm.prank(users[i]);
            gamble.join(users[i]);
            beforeUserRewardBalances[i] = rewardToken.balanceOf(users[i]);
        }

        uint256 round = gamble.currentRound();
        uint256 pot = gamble.currentPot();
        uint256 beforeGambleBalance = entryToken.balanceOf(address(gamble));
        uint256 beforeGambleRewardBalance = rewardToken.balanceOf(address(gamble));
        uint256 beforeBurnAccountBalance = entryToken.balanceOf(address(0xdead));

        vm.expectEmit(false, true, true, true, address(gamble));
        emit IGamble.SelectWinner(address(0), round, pot, 5 * 0.8 * 1e6);
        address winner = gamble.selectWinner(0);

        assertEq(gamble.currentRound(), round + 1, "ROUND");
        assertEq(gamble.currentPot(), 0, "POT");
        assertEq(gamble.totalUsers(round + 1), 0, "TOTAL_USERS");
        assertEq(
            rewardToken.balanceOf(address(gamble)), beforeGambleRewardBalance + 5 * 0.8 * 1e6, "GAMBLE_REWARD_BALANCE"
        );
        assertEq(entryToken.balanceOf(address(gamble)), beforeGambleBalance - pot, "GAMBLE_BALANCE");
        assertEq(entryToken.balanceOf(address(0xdead)), beforeBurnAccountBalance + pot / 5, "BURN_ACCOUNT_BALANCE");

        for (uint256 i; i < users.length; ++i) {
            if (users[i] == winner) {
                assertEq(rewardToken.balanceOf(users[i]), beforeUserRewardBalances[i], "WINNER_REWARD_BALANCE");
                assertEq(gamble.getUserInfo(users[i]).winAmount, 5 * 0.8 * 1e6, "WINNER_WIN_AMOUNT");
            } else {
                assertEq(rewardToken.balanceOf(users[i]), beforeUserRewardBalances[i], "LOSER_REWARD_BALANCE");
                assertEq(gamble.getUserInfo(users[i]).winAmount, 0, "LOSER_WIN_AMOUNT");
            }
        }
    }

    function testSelectWinnerUnderMinimumPot() public {
        vm.prank(users[0]);
        gamble.join(users[0]);

        vm.expectRevert(abi.encodeWithSelector(IGamble.InsufficientPot.selector));
        gamble.selectWinner(0);
    }

    function testClaim() public {
        gamble.join(users[0]);
        gamble.join(users[1]);
        gamble.join(users[2]);
        address winner = gamble.selectWinner(0);

        uint256 beforeUserBalance = rewardToken.balanceOf(winner);
        uint256 beforeGambleBalance = rewardToken.balanceOf(address(gamble));
        uint256 beforeUserWinAmount = gamble.getUserInfo(winner).winAmount;

        vm.expectEmit(address(gamble));
        emit IGamble.Claim(winner, beforeUserWinAmount);
        gamble.claim(winner);

        assertEq(rewardToken.balanceOf(winner), beforeUserBalance + beforeUserWinAmount, "USER_BALANCE");
        assertEq(rewardToken.balanceOf(address(gamble)), beforeGambleBalance - beforeUserWinAmount, "GAMBLE_BALANCE");
        assertEq(gamble.getUserInfo(winner).winAmount, 0, "WIN_AMOUNT");
    }

    function testCollect() public {
        rewardToken.mint(address(gamble), 1000);

        uint256 beforeGambleBalance = rewardToken.balanceOf(address(gamble));
        uint256 beforeUserBalance = rewardToken.balanceOf(users[0]);
        assertEq(gamble.collectable(), 1000, "COLLECTABLE_AMOUNT");

        vm.expectEmit(address(gamble));
        emit IGamble.Collect(users[0], 1000);
        gamble.collect(users[0]);

        assertEq(rewardToken.balanceOf(address(gamble)), beforeGambleBalance - 1000, "GAMBLE_BALANCE");
        assertEq(rewardToken.balanceOf(users[0]), beforeUserBalance + 1000, "USER_BALANCE");
        assertEq(gamble.collectable(), 0, "COLLECTABLE_AMOUNT");
    }
}
