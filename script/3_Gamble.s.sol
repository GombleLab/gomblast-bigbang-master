// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/MockSwapRouter.sol";
import "../src/MockRandomOracle.sol";
import "../src/Distributor.sol";
import "../src/Gamble.sol";

contract GambleScript is Script {
    function setUp() public {}

    function run() public {
        Gamble gamble = Gamble(vm.envAddress("GAMBLE"));
        MockRandomOracle oracle = MockRandomOracle(vm.envAddress("RANDOM_ORACLE"));
        MockToken gblast = MockToken(vm.envAddress("GBLAST"));

        uint256 round = gamble.currentRound();
        console.log("Current Round:", round);

        uint256[] memory privateKeys = new uint256[](5);
        privateKeys[0] = vm.envUint("USER0");
        privateKeys[1] = vm.envUint("USER1");
        privateKeys[2] = vm.envUint("USER2");
        privateKeys[3] = vm.envUint("USER3");
        privateKeys[4] = vm.envUint("USER4");

        uint256 amount = gamble.joinAmount();
        for (uint256 i; i < privateKeys.length; ++i) {
            address user = vm.addr(privateKeys[i]);
            if (gamble.getUserInfo(user).lastParticipatedRoundId == round) {
                console.log("User", user, "already participated in round", round);
                continue;
            }
            if (gblast.balanceOf(user) < amount) {
                console.log("User", user, "does not have enough GBLAST");
                vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
                gblast.mint(user, amount * 100);
                vm.stopBroadcast();
            }
            vm.startBroadcast(privateKeys[i]);
            gblast.approve(address(gamble), amount);
            gamble.join(user);
            vm.stopBroadcast();
        }

        console.log("pot", gamble.currentPot());

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        oracle.setRandomNumber(round, 2);

        address winner = gamble.selectWinner(0);
        vm.stopBroadcast();

        console.log("winner", winner);
    }
}
