// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.13;

import {ReentrancyGuard} from "../Shared/ReentrancyGuard.sol";
import {IZyclone, IWithdrawVerifier, IDepositVerifier, Proof} from "../Shared/Interfaces.sol";

abstract contract Zyclone is IZyclone, ReentrancyGuard {
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant ROOT_HISTORY_SIZE = 30;
    bytes32 constant initialRootZero = 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb;

    uint256 public immutable denomination;
    uint256 immutable levels;
    IWithdrawVerifier immutable withdrawVerifier;
    IDepositVerifier immutable depositVerifier;

    uint256 public currentRootIndex;
    uint256 public nextIndex;

    bytes32[ROOT_HISTORY_SIZE] public roots;
    mapping(bytes32 => bool) public nullifierHashes;
    mapping(address => bytes32) public pendingCommit;

    event Deposit(bytes32 indexed commitment, uint256 leafIndex, uint256 timestamp);
    event Withdrawal(address to, bytes32 nullifierHash, address indexed relayer, uint256 fee);

    /**
     * @param _depositVerifier the address of deposit SNARK verifier for this contract
     * @param _withdrawVerifier the address of withdraw SNARK verifier for this contract
     * @param _denomination transfer amount for each deposit
     * @param _merkleTreeHeight the height of deposits' Merkle Tree
     */
    constructor(
        IDepositVerifier _depositVerifier,
        IWithdrawVerifier _withdrawVerifier,
        uint256 _denomination,
        uint256 _merkleTreeHeight
    ) {
        require(_merkleTreeHeight > 0, "_treeLevels should be greater than zero");
        require(_merkleTreeHeight < 32, "_treeLevels should be less than 32");
        require(_denomination > 0, "denomination should be greater than 0");

        levels = _merkleTreeHeight;
        roots[0] = initialRootZero;
        depositVerifier = _depositVerifier;
        withdrawVerifier = _withdrawVerifier;
        denomination = _denomination;
    }

    /**
     * @dev Let users delete a previously committed commitment hash and withdraw 1 ether they deposited alongside it
     */
    function clear() external nonReentrant {
        require(pendingCommit[msg.sender] != bytes32(0), "not committed");
        delete pendingCommit[msg.sender];
        _processWithdraw(payable(msg.sender), payable(address(0)), 0);
    }

    /**
     * @dev lets users commit with 1 ether and a commitment hash which they can add into the tree whenever they want
     * @param _commitment commitment hash of user's deposit
     */
    function commit(bytes32 _commitment) external payable nonReentrant {
        require(pendingCommit[msg.sender] == bytes32(0), "Pending commitment hash");
        require(uint256(_commitment) < FIELD_SIZE, "_commitment not in field");
        _processDeposit();
        pendingCommit[msg.sender] = _commitment;
    }

    /**
     * @dev lets users add their committed commitmentHash to the current merkle root
     * @param _proof proof of correct of chain addition of pendingCommit[msg.sender] to the current merkle root
     * @param newRoot new root after adding pendingCommit[msg.sender] into current merkle root
     */
    function deposit(Proof calldata _proof, bytes32 newRoot) external nonReentrant {
        bytes32 _commitment = pendingCommit[msg.sender];
        require(_commitment != bytes32(0), "not commited");

        uint256 _currentRootIndex = currentRootIndex;

        require(
            depositVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [uint256(roots[_currentRootIndex]), uint256(_commitment), uint256(newRoot)]
            ),
            "Invalid deposit proof"
        );

        // set pending commit to 0 bytes
        pendingCommit[msg.sender] = bytes32(0);

        uint128 newCurrentRootIndex = uint128((_currentRootIndex + 1) % ROOT_HISTORY_SIZE);

        // update currentRootIndex
        currentRootIndex = newCurrentRootIndex;

        // update root
        roots[newCurrentRootIndex] = newRoot;

        uint256 _nextIndex = nextIndex;

        // update next index
        nextIndex += 1;

        emit Deposit(_commitment, _nextIndex, block.timestamp);
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processDeposit() internal virtual;

    /**
     * @dev Withdraw a deposit from the contract. `proof` is a zkSNARK proof data, and input is an array of circuit public inputs
     * `input` array consists of:
     *   - merkle root of all deposits in the contract
     *   - hash of unique deposit nullifier to prevent double spends
     *   - the recipient of funds
     *   - optional fee that goes to the transaction sender (usually a relay)
     */
    function withdraw(
        Proof calldata _proof,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee
    ) external nonReentrant {
        require(_fee <= denomination, "Fee exceeds transfer value");
        require(!nullifierHashes[_nullifierHash], "The note has been already spent");
        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        require(
            withdrawVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [
                    uint256(_root),
                    uint256(_nullifierHash),
                    uint256(uint160(address(_recipient))),
                    uint256(uint160(address(_relayer))),
                    _fee
                ]
            ),
            "Invalid withdraw proof"
        );

        nullifierHashes[_nullifierHash] = true;
        _processWithdraw(_recipient, _relayer, _fee);
        emit Withdrawal(_recipient, _nullifierHash, _relayer, _fee);
    }

    /**
     * @dev this function is defined in a child contract
     */
    function _processWithdraw(address payable _recipient, address payable _relayer, uint256 _fee) internal virtual;

    /**
     * @dev Whether the root is present in the root history
     */
    function isKnownRoot(bytes32 _root) private view returns (bool) {
        if (_root == 0) return false;

        uint256 i = currentRootIndex;
        do {
            if (_root == roots[i]) return true;
            if (i == 0) i = ROOT_HISTORY_SIZE;
            i--;
        } while (i != currentRootIndex);
        return false;
    }
}
