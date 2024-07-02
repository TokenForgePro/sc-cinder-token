// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {Cindr} from "src/Cindr.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Cindr token = new Cindr(
            "Cindr", // string: name of the token "ask the owner for the name"
            "CND", // string: symbol for the token "ask the owner for the symbol"
            1_000_000_000, // uint256: totalSupply will be sent to the deployer "ask the owner for the total supply"
            address(1), // address: UNISWAP_V2_ROUTER02 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD check => https://docs.uniswap.org/contracts/v3/reference/deployments/base-deployments
            address(1) // address: marketing wallet "ask the owner for the wallet"
        );

        console.log("Cindr token address: ", address(token));
        vm.stopBroadcast();
    }
}
