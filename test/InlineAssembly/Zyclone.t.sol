// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ETHZyclone} from "../../src/InlineAssembly/ETHZyclone.sol";
import {ZycloneTest} from "../Zyclone.t.sol";

contract ZycloneInlineAssemblyTest is ZycloneTest {
    function setUp() public override {
        super.setUp();
        zyclone = new ETHZyclone(depositVerifier, withdrawVerifier, 1e18, 20);
    }
}
