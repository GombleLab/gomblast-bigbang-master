// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/interfaces/IDistributor.sol";
import "../../src/MockToken.sol";
import "../../src/MockSwapRouter.sol";
import "../../src/Distributor.sol";

contract DistributorScenarioTest is Test {
    MockToken public distributionToken;
    MockToken public rewardToken;
    ISwapRouter public swapRouter;
    IDistributor public distributor;
    address[] public users;

    function setUp() public {
        distributionToken = new MockToken(address(this), "USD Tether", "Token", 6);
        rewardToken = new MockToken(address(this), "GOMBLAST", "$GBLST", 18);

        swapRouter = new MockSwapRouter(address(this), 1e19);

        distributor = new Distributor(address(this), rewardToken, swapRouter);

        distributionToken.mint(address(swapRouter), 100 * 1e6);
        distributionToken.mint(address(this), 100 * 1e6);
        rewardToken.mint(address(swapRouter), 100 ether);
        rewardToken.mint(address(this), 100 ether);

        for (uint256 i; i < 5; ++i) {
            address user = address(uint160(1000 + i));
            distributor.register(user);
            users.push(user);
        }
        distributionToken.approve(address(distributor), type(uint256).max);
    }

    function testScenario() public {
        uint256[] memory beforeUserBalances = new uint256[](users.length);
        for (uint256 i; i < beforeUserBalances.length; ++i) {
            beforeUserBalances[i] = rewardToken.balanceOf(users[i]);
        }

        distributor.distribute(address(distributionToken), 1 * 1e6, 0);

        for (uint256 i; i < beforeUserBalances.length; ++i) {
            assertEq(rewardToken.balanceOf(users[i]), beforeUserBalances[i], "AFTER_DISTRIBUTE_BALANCE_0");
            assertEq(distributor.claimable(users[i]), 10 ether / users.length, "CLAIMABLE_AMOUNT_0");
            distributor.claim(users[i]);
            assertEq(
                rewardToken.balanceOf(users[i]),
                beforeUserBalances[i] + 10 ether / users.length,
                "AFTER_DISTRIBUTE_BALANCE_1"
            );
            assertEq(distributor.claimable(users[i]), 0, "CLAIMABLE_AMOUNT_1");
        }
    }
}
