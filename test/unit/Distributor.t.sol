// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import "../../src/interfaces/IDistributor.sol";
import "../../src/MockToken.sol";
import "../../src/MockSwapRouter.sol";
import "../../src/Distributor.sol";

contract DistributorTest is Test {
    MockToken public distributionToken;
    MockToken public rewardToken;
    MockSwapRouter public swapRouter;
    IDistributor public distributor;
    address[] public users;

    function setUp() public {
        distributionToken = new MockToken(address(this), "USD Tether", "Token", 6);
        rewardToken = new MockToken(address(this), "GOMBLAST", "$GBLST", 18);

        swapRouter = new MockSwapRouter(address(this));
        swapRouter.setSwapRate(address(distributionToken), address(rewardToken), 1e18);

        distributor = new Distributor(address(this), rewardToken, swapRouter);

        distributionToken.mint(address(swapRouter), 10000 * 1e6);
        distributionToken.mint(address(this), 10000 * 1e6);
        rewardToken.mint(address(swapRouter), 10000 ether);
        rewardToken.mint(address(this), 10000 ether);

        for (uint256 i; i < 5; ++i) {
            address user = address(uint160(1000 + i));
            distributor.register(user);
            users.push(user);
        }
        distributionToken.approve(address(distributor), type(uint256).max);
    }

    function testDistribute() public {
        uint256 beforeDistributorBalance = rewardToken.balanceOf(address(distributor));
        uint256[] memory beforeUserClaimable = new uint256[](users.length);
        uint256[] memory beforeUserSnapshot = new uint256[](users.length);
        for (uint256 i; i < users.length; ++i) {
            beforeUserSnapshot[i] = distributor.getUserSnapshot(users[i]);
        }

        vm.expectEmit(address(distributor));
        emit IDistributor.Distribute(address(distributionToken), 100 * 1e6, 100 ether);
        distributor.distribute(address(distributionToken), 100 * 1e6, 0);

        for (uint256 i; i < users.length; ++i) {
            uint256 claimable = distributor.claimable(users[i]);
            uint256 snapshot = distributor.getUserSnapshot(users[i]);
            assertEq(claimable, 100 ether / users.length, "CLAIMABLE_AMOUNT");
            assertEq(snapshot, beforeUserSnapshot[i], "SNAPSHOT");
            beforeUserClaimable[i] = claimable;
        }

        assertEq(
            rewardToken.balanceOf(address(distributor)), beforeDistributorBalance + 100 ether, "DISTRIBUTOR_BALANCE"
        );
        uint256 beforeRewardSnapshot = distributor.rewardSnapshot();
        assertEq(beforeRewardSnapshot, 1e24 + 1e24 * 100 ether / users.length, "REWARD_SNAPSHOT");

        vm.expectEmit(address(distributor));
        emit IDistributor.Distribute(address(distributionToken), 100 * 1e6, 100 ether);
        distributor.distribute(address(distributionToken), 100 * 1e6, 0);

        for (uint256 i; i < users.length; ++i) {
            uint256 claimable = distributor.claimable(users[i]);
            uint256 snapshot = distributor.getUserSnapshot(users[i]);
            assertEq(claimable, beforeUserClaimable[i] + 100 ether / users.length, "CLAIMABLE_AMOUNT");
            assertEq(snapshot, beforeUserSnapshot[i], "SNAPSHOT");
        }

        assertEq(
            distributor.rewardSnapshot(), beforeRewardSnapshot + 1e24 * 100 ether / users.length, "REWARD_SNAPSHOT"
        );
    }

    function testClaim() public {
        uint256 amount = 100 * 1e6;

        distributor.distribute(address(distributionToken), amount, 0);

        for (uint256 i; i < users.length; ++i) {
            uint256 claimable = distributor.claimable(users[i]);
            assertEq(claimable, 100 ether / users.length, "CLAIMABLE_AMOUNT");
            vm.expectEmit(address(distributor));
            emit IDistributor.Claim(users[i], claimable);
            distributor.claim(users[i]);
            assertEq(rewardToken.balanceOf(users[i]), 100 ether / users.length, "USER_BALANCE");
            assertEq(distributor.claimable(users[i]), 0, "CLAIMABLE_AMOUNT");
        }

        distributor.register(address(0xadf));
        users.push(address(0xadf));

        distributor.distribute(address(distributionToken), amount, 0);

        for (uint256 i; i < users.length; ++i) {
            uint256 claimable = distributor.claimable(users[i]);
            assertEq(claimable, 100 ether / users.length, "CLAIMABLE_AMOUNT");
            vm.expectEmit(address(distributor));
            emit IDistributor.Claim(users[i], claimable);
            distributor.claim(users[i]);
            assertEq(distributor.claimable(users[i]), 0, "CLAIMABLE_AMOUNT");
        }
    }

    function testRegister() public {
        uint256 beforeReceivers = distributor.totalReceivers();

        assertFalse(distributor.isRegistered(address(0x123)), "REGISTERED");

        vm.expectEmit(address(distributor));
        emit IDistributor.Register(address(0x123));
        distributor.register(address(0x123));

        assertTrue(distributor.isRegistered(address(0x123)), "REGISTERED");
        assertEq(distributor.totalReceivers(), beforeReceivers + 1, "TOTAL_RECEIVERS");
        assertEq(distributor.claimable(address(0x123)), 0, "CLAIMABLE_AMOUNT");
    }

    function testRegisterTwice() public {
        assertTrue(distributor.isRegistered(users[0]), "REGISTERED");

        vm.expectRevert(abi.encodeWithSelector(IDistributor.AlreadyRegistered.selector));
        distributor.register(users[0]);
    }

    function testUnregister() public {
        distributor.distribute(address(distributionToken), 10 * 1e6, 0);

        assertTrue(distributor.isRegistered(users[0]), "REGISTERED");
        uint256 beforeClaimable = distributor.claimable(users[0]);
        uint256 beforeReceivers = distributor.totalReceivers();

        vm.expectEmit(address(distributor));
        emit IDistributor.Claim(users[0], beforeClaimable);
        vm.expectEmit(address(distributor));
        emit IDistributor.Unregister(users[0]);
        distributor.unregister(users[0]);

        assertFalse(distributor.isRegistered(users[0]), "REGISTERED");
        assertEq(distributor.claimable(users[0]), 0, "CLAIMABLE_AMOUNT");
        assertEq(distributor.totalReceivers(), beforeReceivers - 1, "TOTAL_RECEIVERS");
    }

    function testUnregisterTwice() public {
        assertFalse(distributor.isRegistered(address(0x123)), "REGISTERED");

        vm.expectRevert(abi.encodeWithSelector(IDistributor.NotRegistered.selector));
        distributor.unregister(address(0x123));
    }
}
