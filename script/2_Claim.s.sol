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
        Distributor distributor = Distributor(vm.envAddress("DISTRIBUTOR"));
        MockToken gblast = MockToken(vm.envAddress("GBLAST"));

        uint256 pk = vm.envUint("USER1");
        address executor = vm.addr(pk);
        vm.startBroadcast(pk);
        uint256 beforeClaimable = distributor.claimable(executor);
        uint256 userBalance = gblast.balanceOf(executor);
        console.log("claimable", beforeClaimable);
        console.log("user balance", userBalance);
        distributor.claim(executor);
        uint256 afterClaimable = distributor.claimable(executor);
        userBalance = gblast.balanceOf(executor);
        console.log("claimable", afterClaimable);
        console.log("user balance", userBalance);
        vm.stopBroadcast();
    }
}
