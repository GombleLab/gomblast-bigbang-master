// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/MockToken.sol";
import "../src/MockSwapRouter.sol";
import "../src/MockRandomOracle.sol";
import "../src/Distributor.sol";
import "../src/Gamble.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer: ", deployer);

        console.log("Deploying Mock tokens...");
        MockToken gblast = new MockToken(deployer, "GOMBLAST", "$GBLST", 18);
        console.log("gblast", address(gblast));
        MockToken usdt = new MockToken(deployer, "USD Tether", "USDT", 6);
        console.log("usdt", address(usdt));

        console.log("Deploying MockSwapRouter...");
        MockSwapRouter swapRouter = new MockSwapRouter(deployer);
        console.log("swapRouter", address(swapRouter));

        console.log("Setting swap rate...");
        swapRouter.setSwapRate(address(usdt), address(gblast), 1e19);
        swapRouter.setSwapRate(address(gblast), address(usdt), 1e17);

        console.log("Deploying MockRandomOracle...");
        MockRandomOracle randomOracle = new MockRandomOracle(deployer);
        console.log("randomOracle", address(randomOracle));

        console.log("Deploying Distributor...");
        Distributor distributor = new Distributor(deployer, gblast, swapRouter);
        console.log("distributor", address(distributor));

        console.log("Deploying Gamble...");
        Gamble gamble = new Gamble(deployer, gblast, usdt, swapRouter, randomOracle, 20 * 10000, 2 ether, 10 ether);
        console.log("gamble", address(gamble));

        address[] memory users = new address[](5);
        users[0] = vm.addr(vm.envUint("USER0"));
        users[1] = vm.addr(vm.envUint("USER1"));
        users[2] = vm.addr(vm.envUint("USER2"));
        users[3] = vm.addr(vm.envUint("USER3"));
        users[4] = vm.addr(vm.envUint("USER4"));

        console.log("Registering Users...");
        for (uint256 i; i < users.length; ++i) {
            distributor.register(users[i]);
        }

        console.log("Mint Tokens...");
        usdt.mint(address(swapRouter), 100000 * 1e6);
        gblast.mint(address(swapRouter), 100000 ether);
        usdt.mint(deployer, 1000 * 1e6);
        gblast.mint(deployer, 1000 ether);
        for (uint256 i; i < users.length; ++i) {
            usdt.mint(users[i], 1000 * 1e6);
            gblast.mint(users[i], 1000 ether);
        }

        vm.stopBroadcast();
    }
}
