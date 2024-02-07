// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../src/MockToken.sol";
import "../src/ITreasury.sol";
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
        treasury = new Treasury(token, 1 ether, 20 * 10000, swap, new MockRandomOracle());

        vm.deal(address(this), 100 ether);
        vm.deal(address(swap), 100 ether);
        token.mint(address(swap), 100 ether);
        token.mint(address(this), 100 ether);

        for (uint256 i; i < 5; ++i) {
            address user = address(uint160(1000 + i));
            treasury.register(user);
            users.push(user);
        }
    }

    function testScenario1() public {
        payable(address(treasury)).transfer(1 ether);

        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = token.balanceOf(users[i]);
        }
        uint256 beforeUnclaimedInterest = treasury.unclaimedInterest();

        uint256 expectedSwapAmount = 10 ether;
        treasury.distribute(0);

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

        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = users[i].balance;
        }
        uint256 beforeBurnAccountBalance = token.balanceOf(address(0xdead));
        uint256 beforeUnclaimedWinPrize = treasury.unclaimedWinPrize();

        uint256 expectedSwapAmount = 1 ether;

        address winner = treasury.selectWinner(0);

        assertEq(treasury.unclaimedWinPrize(), beforeUnclaimedWinPrize + expectedSwapAmount, "UNCLAIMED_WIN_PRIZE");

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            if (users[i] == winner) {
                uint256 winAmount = expectedSwapAmount * 8 / 10;
                assertEq(users[i].balance, beforeUserBalances[i], "WINNER_BALANCE_0");
                assertEq(treasury.getUserInfo(users[i]).winAmount, winAmount, "WINNER_WIN_AMOUNT_0");
                treasury.claimWinPrize(users[i]);
                assertEq(users[i].balance, beforeUserBalances[i] + winAmount, "WINNER_BALANCE_1");
                assertEq(treasury.getUserInfo(users[i]).winAmount, 0, "WINNER_WIN_AMOUNT_1");
            } else {
                assertEq(users[i].balance, beforeUserBalances[i], "LOSER_BALANCE");
            }
        }
        assertEq(token.balanceOf(address(0xdead)), beforeBurnAccountBalance + 2 ether, "BURNT_AMOUNT");

        assertEq(treasury.unclaimedWinPrize(), 0, "UNCLAIMED_WIN_PRIZE");
    }
}
