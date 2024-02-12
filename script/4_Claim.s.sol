// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/MockSwapRouter.sol";
import "../src/MockRandomOracle.sol";
import "../src/Distributor.sol";
import "../src/Gamble.sol";

contract ClaimScript is Script {
    function setUp() public {}

    function run() public {
        Gamble gamble = Gamble(vm.envAddress("GAMBLE"));
        MockToken usdt = MockToken(vm.envAddress("USDT"));

        uint256[] memory privateKeys = new uint256[](5);
        privateKeys[0] = vm.envUint("USER1");
        privateKeys[1] = vm.envUint("USER2");
        privateKeys[2] = vm.envUint("USER3");
        privateKeys[3] = vm.envUint("USER4");
        privateKeys[4] = vm.envUint("USER5");

        for (uint256 i; i < privateKeys.length; ++i) {
            address user = vm.addr(privateKeys[i]);
            uint256 claimable = gamble.getUserInfo(user).winAmount;
            if (claimable > 0) {
                console.log("user", user);
                console.log("claimable", claimable);
                console.log("balance", usdt.balanceOf(user));
                vm.startBroadcast(privateKeys[i]);
                gamble.claim(user);
                vm.stopBroadcast();
                console.log("balance", usdt.balanceOf(user));
            }
        }
    }
}
