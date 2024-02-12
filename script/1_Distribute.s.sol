// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/MockSwapRouter.sol";
import "../src/MockRandomOracle.sol";
import "../src/Distributor.sol";
import "../src/Gamble.sol";

contract DistributeScript is Script {
    function setUp() public {}

    function run() public {
        uint256 pk = vm.envUint("PRIVATE_KEY");

        Distributor distributor = Distributor(vm.envAddress("DISTRIBUTOR"));
        MockToken usdt = MockToken(vm.envAddress("USDT"));

        vm.startBroadcast(pk);
        uint256 amount = 100 * 1e6;
        usdt.approve(address(distributor), amount);
        distributor.distribute(address(usdt), amount, 0);
        vm.stopBroadcast();
    }
}
