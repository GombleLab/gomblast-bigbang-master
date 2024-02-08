// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/MockToken.sol";
import "../src/interfaces/ITreasury.sol";
import "../src/MockSwap.sol";
import "../src/Treasury.sol";
import "../src/MockRandomOracle.sol";

contract ScenarioTest is Test {
    MockToken public token;
    Treasury public treasury;
    MockSwap public swap;
    address[] public users;

    function setUp() public {
        token = new MockToken("GOMBLAST", "$GBLST");
        swap = new MockSwap(address(token), 10 * 1e18);
        treasury = new Treasury(token, 0.5 ether, 20 * 10000, 2 ether, swap, new MockRandomOracle());

        vm.deal(address(this), 100 ether);
        vm.deal(address(swap), 100 ether);
        token.mint(address(swap), 100 ether);
        token.mint(address(this), 100 ether);

        for (uint256 i; i < 5; ++i) {
            address user = address(uint160(1000 + i));
            treasury.register(user);
            users.push(user);
            token.mint(user, 100 ether);
            vm.prank(user);
            token.approve(address(treasury), type(uint256).max);
        }
    }

    function testScenario1() public {
        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = token.balanceOf(users[i]);
        }
        uint256 beforeUnclaimedInterest = treasury.unclaimedInterest();

        uint256 expectedSwapAmount = 10 ether;
        treasury.distribute{value: 1 ether}(0);

        assertEq(treasury.unclaimedInterest(), beforeUnclaimedInterest + expectedSwapAmount, "UNCLAIMED_INTEREST");

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            assertEq(token.balanceOf(users[i]), beforeUserBalances[i], "AFTER_DISTRIBUTE_BALANCE_0");
            assertEq(treasury.claimableInterest(users[i]), 10 ether / users.length, "CLAIMABLE_AMOUNT_0");
            treasury.claimInterest(users[i]);
            assertEq(
                token.balanceOf(users[i]), beforeUserBalances[i] + 10 ether / users.length, "AFTER_DISTRIBUTE_BALANCE_1"
            );
            assertEq(treasury.claimableInterest(users[i]), 0, "CLAIMABLE_AMOUNT_1");
        }

        assertEq(treasury.unclaimedInterest(), 0, "UNCLAIMED_INTEREST");
    }

    function testScenario2() public {
        token.mint(address(treasury), 10 ether);

        uint256 roundId = treasury.roundId();

        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = users[i].balance;
            uint256 pot = treasury.currentPot();
            uint256 beforeTotalUsers = treasury.totalUsers(roundId);
            vm.prank(users[i]);
            treasury.join(users[i]);
            assertEq(treasury.currentPot(), pot + 2 ether, "POT");
            assertEq(treasury.totalUsers(roundId), beforeTotalUsers + 1, "TOTAL_USERS");
            assertEq(treasury.getUserInfo(users[i]).lastParticipatedRoundId, roundId, "LAST_PARTICIPATED_ROUND_ID");
            uint256 index = treasury.getUserInfo(users[i]).index;
            assertEq(treasury.getUser(roundId, index), users[i], "USER");
        }
        uint256 beforeUnclaimedWinPrize = treasury.unclaimedWinPrize();
        uint256 beforeBurnBalance = token.balanceOf(address(0xdead));

        uint256 expectedWinAmount = 0.8 ether;

        address winner = treasury.selectWinner(0);

        assertEq(treasury.unclaimedWinPrize(), beforeUnclaimedWinPrize + expectedWinAmount, "UNCLAIMED_WIN_PRIZE");

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            if (users[i] == winner) {
                assertEq(users[i].balance, beforeUserBalances[i], "WINNER_BALANCE_0");
                assertEq(treasury.getUserInfo(users[i]).winAmount, expectedWinAmount, "WINNER_WIN_AMOUNT_0");
                treasury.claimWinPrize(users[i]);
                assertEq(users[i].balance, beforeUserBalances[i] + expectedWinAmount, "WINNER_BALANCE_1");
                assertEq(treasury.getUserInfo(users[i]).winAmount, 0, "WINNER_WIN_AMOUNT_1");
            } else {
                assertEq(users[i].balance, beforeUserBalances[i], "LOSER_BALANCE");
            }
        }

        assertEq(treasury.roundId(), roundId + 1, "ROUND_ID");
        assertEq(treasury.unclaimedWinPrize(), 0, "UNCLAIMED_WIN_PRIZE");
        assertEq(treasury.getAllUsers(roundId + 1).length, 0, "ALL_USERS");
        assertEq(treasury.totalUsers(roundId + 1), 0, "TOTAL_USERS");
        assertEq(token.balanceOf(address(0xdead)), beforeBurnBalance + 2 ether, "BURNT_AMOUNT");
        assertEq(treasury.currentPot(), 0, "POT");
    }
}
