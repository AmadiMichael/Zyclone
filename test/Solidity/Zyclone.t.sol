// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ETHZyclone} from "../../src/Solidity/ETHZyclone.sol";
import {ZycloneTest} from "../Zyclone.t.sol";

contract ZycloneSolidityTest is ZycloneTest {
    function setUp() public override {
        super.setUp();
        zyclone = new ETHZyclone(depositVerifier, withdrawVerifier, 1 ether, 20);
    }
}
