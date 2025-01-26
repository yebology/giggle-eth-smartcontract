// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "../lib/forge-std/src/Script.sol";
import {Giggle} from "../src/Giggle.sol";

contract GiggleScript is Script {
    // 
    
    function run() external returns (Giggle) {
        vm.startBroadcast();
        Giggle giggle = new Giggle();
        vm.stopBroadcast();
        return giggle;
    }
    //
}