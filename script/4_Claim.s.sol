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

        uint256 winnerPK = vm.envUint("USER2");

        address user = vm.addr(winnerPK);
        uint256 claimable = gamble.getUserInfo(user).winAmount;
        if (claimable > 0) {
            console.log("user", user);
            console.log("claimable", claimable);
            console.log("balance", usdt.balanceOf(user));
            vm.startBroadcast(winnerPK);
            gamble.claim(user);
            vm.stopBroadcast();
            console.log("balance", usdt.balanceOf(user));
        }
    }
}
