// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.13;

struct Proof {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

interface IWithdrawVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[5] calldata input
    ) external view returns (bool);
}

interface IDepositVerifier {
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata input
    ) external view returns (bool);
}

interface IZyclone {
    function clear() external;

    function commit(bytes32 _commitment) external payable;

    function deposit(Proof calldata _proof, bytes32 newRoot) external;

    function withdraw(
        Proof calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee
    ) external;

    function currentRootIndex() external view returns (uint256);

    function nextIndex() external view returns (uint256);

    function roots(uint256) external view returns (bytes32);
}
