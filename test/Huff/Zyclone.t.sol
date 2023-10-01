// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Vm, console2} from "forge-std/Test.sol";
import {HuffDeployer} from "foundry-huff/HuffDeployer.sol";
import {ETHZyclone} from "../../src/Solidity/ETHZyclone.sol";
import {ZycloneTest} from "../Zyclone.t.sol";

contract ZycloneHuffTest is ZycloneTest {
    function setUp() public override {
        super.setUp();

        string memory wrapper = string.concat(
            "#define constant __WITHDRAW_VERIFIER = ",
            vm.toString(address(withdrawVerifier)),
            "\n",
            "  #define constant __DEPOSIT_VERIFIER = ",
            vm.toString(address(depositVerifier)),
            "\n",
            "  #define constant __DENOMINATION = ",
            vm.toString(bytes32(uint256(1 ether))),
            "\n",
            "  #define constant __LEVELS = ",
            vm.toString(bytes32(uint256(20)))
        );

        console2.logString(wrapper);

        console2.logBytes(HuffDeployer.config().with_code(wrapper).deploy("Huff/ETHZyclone").code);

        zyclone = new ETHZyclone(depositVerifier, withdrawVerifier, 1e18, 20);
    }

    function testDummy() external {}
}
