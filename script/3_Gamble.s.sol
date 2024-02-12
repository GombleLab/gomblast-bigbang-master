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
        privateKeys[0] = vm.envUint("USER1");
        privateKeys[1] = vm.envUint("USER2");
        privateKeys[2] = vm.envUint("USER3");
        privateKeys[3] = vm.envUint("USER4");
        privateKeys[4] = vm.envUint("USER5");

        uint256 amount = gamble.joinAmount();
        for (uint256 i; i < privateKeys.length; ++i) {
            vm.startBroadcast(privateKeys[0]);
            gblast.approve(address(gamble), amount);
            gamble.join(vm.addr(privateKeys[i]));
            vm.stopBroadcast();
        }

        console.log("pot", gamble.currentPot());

        uint256 pk = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(pk);
        oracle.setRandomNumber(round, privateKeys.length - 1);

        address winner = gamble.selectWinner(0);
        vm.stopBroadcast();

        console.log("winner", winner);
    }
}
