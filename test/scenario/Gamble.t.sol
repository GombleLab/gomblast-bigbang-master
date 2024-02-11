// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/interfaces/IGamble.sol";
import "../../src/MockToken.sol";
import "../../src/MockSwapRouter.sol";
import "../../src/MockRandomOracle.sol";
import "../../src/Gamble.sol";

contract GambleScenarioTest is Test {
    MockToken public entryToken;
    MockToken public rewardToken;
    ISwapRouter public swapRouter;
    IRandomOracle public randomOracle;
    IGamble public gamble;

    address[] public users;

    function setUp() public {
        entryToken = new MockToken("GOMBLAST", "$GBLST", 18);
        rewardToken = new MockToken("USD Tether", "USDT", 6);

        swapRouter = new MockSwapRouter(1e17);
        randomOracle = new MockRandomOracle();

        gamble = new Gamble(
            address(this),
            IERC20(entryToken),
            IERC20(rewardToken),
            swapRouter,
            randomOracle,
            20 * 10000,
            2 ether,
            4 ether
        );

        entryToken.mint(address(swapRouter), 100 ether);
        entryToken.mint(address(this), 100 ether);
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

    function testScenario() public {
        entryToken.mint(address(gamble), 10 ether);

        uint256 round = gamble.currentRound();

        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = rewardToken.balanceOf(users[i]);
            uint256 pot = gamble.currentPot();
            uint256 beforeTotalUsers = gamble.totalUsers(round);
            vm.prank(users[i]);
            gamble.join(users[i]);
            assertEq(gamble.currentPot(), pot + 2 ether, "POT");
            assertEq(gamble.totalUsers(round), beforeTotalUsers + 1, "TOTAL_USERS");
            assertEq(gamble.getUserInfo(users[i]).lastParticipatedRoundId, round, "LAST_PARTICIPATED_ROUND_ID");
            uint256 index = gamble.getUserInfo(users[i]).currentIndex;
            assertEq(gamble.getUser(round, index), users[i], "USER");
        }
        uint256 beforeTotalUnclaimedAmount = gamble.totalUnclaimedAmount();
        uint256 beforeBurnBalance = entryToken.balanceOf(address(0xdead));

        uint256 expectedWinAmount = 0.8 * 1e6;

        randomOracle.setRandomNumber(round, gamble.totalUsers(round) - 1);
        address winner = gamble.selectWinner(0);

        assertEq(gamble.totalUnclaimedAmount(), beforeTotalUnclaimedAmount + expectedWinAmount, "TOTAL_UNCLAIMED");

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            if (users[i] == winner) {
                assertEq(rewardToken.balanceOf(users[i]), beforeUserBalances[i], "WINNER_BALANCE_0");
                assertEq(gamble.getUserInfo(users[i]).winAmount, expectedWinAmount, "WINNER_WIN_AMOUNT_0");
                gamble.claim(users[i]);
                assertEq(rewardToken.balanceOf(users[i]), beforeUserBalances[i] + expectedWinAmount, "WINNER_BALANCE_1");
                assertEq(gamble.getUserInfo(users[i]).winAmount, 0, "WINNER_WIN_AMOUNT_1");
            } else {
                assertEq(rewardToken.balanceOf(users[i]), beforeUserBalances[i], "LOSER_BALANCE");
            }
        }

        assertEq(gamble.currentRound(), round + 1, "ROUND_ID");
        assertEq(gamble.totalUnclaimedAmount(), 0, "TOTAL_UNCLAIMED");
        assertEq(gamble.getAllUsers(round + 1).length, 0, "ALL_USERS");
        assertEq(gamble.totalUsers(round + 1), 0, "TOTAL_USERS");
        assertEq(entryToken.balanceOf(address(0xdead)), beforeBurnBalance + 2 ether, "BURNT_AMOUNT");
        assertEq(gamble.currentPot(), 0, "POT");
    }
}
