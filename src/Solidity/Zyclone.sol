// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.13;

import {ReentrancyGuard} from "../Shared/ReentrancyGuard.sol";
import {IZyclone, IWithdrawVerifier, IDepositVerifier, Proof} from "../Shared/Interfaces.sol";

abstract contract Zyclone is IZyclone, ReentrancyGuard {
    uint256 constant FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    uint256 constant ROOT_HISTORY_SIZE = 30;
    bytes32 constant initialRootZero = 0x2b0f6fc0179fa65b6f73627c0e1e84c7374d2eaec44c9a48f2571393ea77bcbb;
    uint256 constant internal ZERO = 0;
    uint256 constant internal ONE = 1;
    uint256 constant internal THIRTY_ONE = 31;
    bytes32 constant internal ZERO_BYTES = bytes32(ZERO);

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
        if (_merkleTreeHeight == ZERO) {
            revert TreeLevelsMissing();
        }
        if (_merkleTreeHeight > THIRTY_ONE) {
            revert TreeLevelsBounds();
        }
        if (_denomination == ZERO) {
            revert DenominationMissing();
        }

        levels = _merkleTreeHeight;
        roots[ZERO] = initialRootZero;
        depositVerifier = _depositVerifier;
        withdrawVerifier = _withdrawVerifier;
        denomination = _denomination;
    }

    /**
     * @dev Let users delete a previously committed commitment hash and withdraw 1 ether they deposited alongside it
     */
    function clear() external nonReentrant {
        if (pendingCommit[msg.sender] == ZERO_BYTES) {
            revert NotCommitted();
        }
        pendingCommit[msg.sender] = ZERO_BYTES;
        _processWithdraw(payable(msg.sender), payable(address(0)), ZERO);
    }

    /**
     * @dev lets users commit with 1 ether and a commitment hash which they can add into the tree whenever they want
     * @param _commitment commitment hash of user's deposit
     */
    function commit(bytes32 _commitment) external payable nonReentrant {
        if (pendingCommit[msg.sender] != ZERO_BYTES) {
            revert PendingCommitmentHash();
        }
        if (uint256(_commitment) >= FIELD_SIZE) {
            revert CommitmentNotInField();
        }
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
        if (_commitment == ZERO_BYTES) {
            revert NotCommitted();
        }

        uint256 _currentRootIndex = currentRootIndex;

        if (
            !depositVerifier.verifyProof(
                _proof.a,
                _proof.b,
                _proof.c,
                [uint256(roots[_currentRootIndex]), uint256(_commitment), uint256(newRoot)]
            )
        ) {
            revert InvalidProof();
        }

        // set pending commit to 0 bytes
        pendingCommit[msg.sender] = ZERO_BYTES;

        uint256 newCurrentRootIndex = uint128((_currentRootIndex + ONE) % ROOT_HISTORY_SIZE);

        // update currentRootIndex
        currentRootIndex = newCurrentRootIndex;

        // update root
        roots[newCurrentRootIndex] = newRoot;

        uint256 _nextIndex = nextIndex;

        // update next index
        unchecked {
            nextIndex = _nextIndex + ONE;
        }

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
        if (_fee > denomination) {
            revert FeeExceedsValue();
        }
        if (nullifierHashes[_nullifierHash]) {
            revert NoteSpent();
        }
        if (!isKnownRoot(_root)) {
            revert RootNotKnown();
        }

        if (
            !withdrawVerifier.verifyProof(
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
            )
        ) {
            revert InvalidProof();
        }

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
    function isKnownRoot(bytes32 _root) private view returns (bool known) {
        if (_root > ZERO_BYTES) {
            uint256 i = currentRootIndex;
            do {
                if (_root == roots[i]) return true;
                if (i == ZERO) i = ROOT_HISTORY_SIZE;
                i--;
            } while (i != currentRootIndex);
        }
    }
}
