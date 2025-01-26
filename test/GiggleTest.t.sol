// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Test} from "../lib/forge-std/src/Test.sol";
import {Giggle} from "../src/Giggle.sol";
import {GiggleScript} from "../script/GiggleScript.s.sol";

contract GiggleTest is Test {
    // 
    Giggle private giggle;

    function setUp() public {
        GiggleScript giggleScript = new GiggleScript();
        giggle = giggleScript.run();
    }

    function testRegisterWallet() public {
        
    }
    //
}