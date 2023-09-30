// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {
    ETHZyclone, Zyclone, IWithdrawVerifier, IDepositVerifier, Proof
} from "../../src/InlineAssembly/ETHZyclone.sol";
import {Groth16Verifier as WithdrawGroth16Verifier} from "../../build/WithdrawVerifier.sol";
import {Groth16Verifier as DepositGroth16Verifier} from "../../build/DepositVerifier.sol";

contract ZycloneTest is Test {
    address payable sender = payable(address(0x0123456789abcdef));
    Zyclone zyclone;
    IDepositVerifier depositVerifier;
    IWithdrawVerifier withdrawVerifier;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    function setUp() public {
        withdrawVerifier = IWithdrawVerifier(address(new WithdrawGroth16Verifier()));
        depositVerifier = IDepositVerifier(address(new DepositGroth16Verifier()));

        zyclone = new ETHZyclone(depositVerifier, withdrawVerifier, 1e18, 20);
    }

    function getDepositCommitmentHash(uint256 leafIndex) private returns (bytes memory) {
        string[] memory inputs = new string[](3);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getCommitment.js";
        inputs[2] = vm.toString(leafIndex);

        return vm.ffi(inputs);
    }

    function getJsTreeAssertions(bytes32[] memory pushedCommitments, bytes32 newCommitment)
        private
        returns (bytes32 root_before_commitment, uint256 height, bytes32 root_after_commitment)
    {
        string[] memory inputs = new string[](5);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/tree.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(abi.encode(pushedCommitments));
        inputs[4] = vm.toString(newCommitment);

        bytes memory result = vm.ffi(inputs);
        (root_before_commitment, height, root_after_commitment) = abi.decode(result, (bytes32, uint256, bytes32));
    }

    function getWithdrawProve(
        uint256 leafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        address recipient,
        address relayer,
        uint256 fee,
        bytes32[] memory pushedCommitments
    ) private returns (bytes memory) {
        string[] memory inputs = new string[](10);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getWithdrawProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(nullifier);
        inputs[5] = vm.toString(nullifierHash);
        inputs[6] = vm.toString(recipient);
        inputs[7] = vm.toString(relayer);
        inputs[8] = vm.toString(fee);
        inputs[9] = vm.toString(abi.encode(pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function getDepositProve(
        uint256 leafIndex,
        bytes32 oldRoot,
        bytes32 commitmentHash,
        bytes32[] memory pushedCommitments
    ) private returns (bytes memory) {
        string[] memory inputs = new string[](7);
        inputs[0] = "node";
        inputs[1] = "ffi_helpers/getDepositProve.js";
        inputs[2] = "20";
        inputs[3] = vm.toString(leafIndex);
        inputs[4] = vm.toString(oldRoot);
        inputs[5] = vm.toString(commitmentHash);
        inputs[6] = vm.toString(abi.encode(pushedCommitments));

        bytes memory result = vm.ffi(inputs);
        return result;
    }

    function depositAndAssert(address user, uint256 newLeafIndex, bytes32[] memory pushedCommitments)
        internal
        returns (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier)
    {
        startHoax(user, 2 ether);

        (commitment, nullifierHash, nullifier) =
            abi.decode(getDepositCommitmentHash(newLeafIndex), (bytes32, bytes32, bytes32));

        uint256 userrBalBefore = user.balance;

        // deposit
        zyclone.commit{value: 1 ether}(commitment);

        /// get dep prove
        Proof memory depositProof;
        bytes32 newRoot;
        {
            (depositProof, newRoot) = abi.decode(
                getDepositProve(newLeafIndex, zyclone.roots(zyclone.currentRootIndex()), commitment, pushedCommitments),
                (Proof, bytes32)
            );
        }

        vm.expectEmit(true, false, false, true, address(zyclone));
        emit Deposit(commitment, newLeafIndex, block.timestamp);
        zyclone.deposit(depositProof, newRoot);
        assertTrue((userrBalBefore - user.balance) >= 1 ether, "Balance did not go down by at least 1 ether");

        {
            // assert tree root and elements are correct
            (bytes32 preDepositRoot, uint256 elements, bytes32 postDepositRoot) =
                getJsTreeAssertions(pushedCommitments, commitment);
            assertEq(preDepositRoot, zyclone.roots(newLeafIndex));
            assertEq(elements, zyclone.nextIndex());
            assertEq(postDepositRoot, zyclone.roots(newLeafIndex + 1));
        }

        vm.stopPrank();
    }

    function withdrawAndAssert(
        address user,
        address relayer,
        uint256 fee,
        uint256 leafIndex,
        bytes32 nullifier,
        bytes32 nullifierHash,
        bytes32[] memory pushedCommitments,
        bytes memory errorIfAny
    ) internal returns (Proof memory proof, bytes32 root) {
        startHoax(relayer);

        /// get prove
        {
            (proof, root) = abi.decode(
                getWithdrawProve(leafIndex, nullifier, nullifierHash, user, relayer, fee, pushedCommitments),
                (Proof, bytes32)
            );
        }

        // withdraw

        if (keccak256(errorIfAny) == keccak256(bytes(""))) {
            uint256 userBalBefore = user.balance;

            vm.expectEmit(true, false, false, true, address(zyclone));
            emit Withdrawal(user, nullifierHash, relayer, fee);
            zyclone.withdraw(proof, root, nullifierHash, payable(user), payable(relayer), fee);
            assertEq((user.balance - userBalBefore), 1 ether, "Balance did not go up by 1 ether");
        } else {
            vm.expectRevert(errorIfAny);
            zyclone.withdraw(proof, root, nullifierHash, payable(user), payable(relayer), fee);
        }

        vm.stopPrank();
    }

    function test_deposit_and_withdraw() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0));

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        withdrawAndAssert(userOldSigner, relayerSigner, 0, 0, nullifier, nullifierHash, pushedCommitments, bytes(""));
    }

    function test_prevent_double_spend() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0));

        // withdraw
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        withdrawAndAssert(userOldSigner, relayerSigner, 0, 0, nullifier, nullifierHash, pushedCommitments, bytes(""));

        // try again but expect error
        withdrawAndAssert(
            userOldSigner,
            relayerSigner,
            0,
            0,
            nullifier,
            nullifierHash,
            pushedCommitments,
            bytes("The note has been already spent")
        );
    }

    function test_prevent_withdraw_from_non_existent_root() external {
        address honestUser = address(bytes20(keccak256("honestUser")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));
        address attacker = address(bytes20(keccak256("attacker")));

        (bytes32 honest_commitment,,) = depositAndAssert(honestUser, 0, new bytes32[](0));

        // generate proof but don't commit or deposit
        (bytes32 attacker_commitment, bytes32 attacker_nullifierHash, bytes32 attacker_nullifier) =
            abi.decode(getDepositCommitmentHash(1), (bytes32, bytes32, bytes32));

        // withdraw but expect error
        bytes32[] memory pushedCommitments = new bytes32[](2);
        pushedCommitments[0] = honest_commitment;
        pushedCommitments[1] = attacker_commitment;
        withdrawAndAssert(
            attacker,
            relayerSigner,
            0,
            1,
            attacker_nullifier,
            attacker_nullifierHash,
            pushedCommitments,
            bytes("Cannot find your merkle root")
        );
    }

    function test_deposit_twice_then_withdraw() external {
        address userOldSigner = address(bytes20(keccak256("userOldSigner")));
        address userNewSigner = address(bytes20(keccak256("userNewSigner")));
        address relayerSigner = address(bytes20(keccak256("relayerSigner")));

        // first deposit
        (bytes32 commitment, bytes32 nullifierHash, bytes32 nullifier) =
            depositAndAssert(userOldSigner, 0, new bytes32[](0));

        // second deposit
        bytes32[] memory pushedCommitments = new bytes32[](1);
        pushedCommitments[0] = commitment;
        (bytes32 new_commitment,,) = depositAndAssert(userNewSigner, 1, pushedCommitments);

        // withdraw first deposit via second deposit's root
        bytes32[] memory updated_pushedCommitments = new bytes32[](2);
        updated_pushedCommitments[0] = commitment;
        updated_pushedCommitments[1] = new_commitment;
        withdrawAndAssert(
            userOldSigner, relayerSigner, 0, 0, nullifier, nullifierHash, updated_pushedCommitments, bytes("")
        );
    }
}
