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
        delete pendingCommit[msg.sender];
        _processWithdraw(payable(msg.sender), payable(address(0)), 0);
    }

    /**
     * @dev lets users commit with 1 ether and a commitment hash which they can add into the tree whenever they want
     * @param _commitment commitment hash of user's deposit
     */
    function commit(bytes32 _commitment) external payable nonReentrant {
        require(pendingCommit[msg.sender] == bytes32(0), "Pending commitment hash");
        require(uint256(_commitment) < FIELD_SIZE, "_commitment should be inside the field");
        _processDeposit();
        pendingCommit[msg.sender] = _commitment;
    }

    /**
     * @dev lets users add their committed commitmentHash to the current merkle root
     * _proof proof of correct of chain addition of pendingCommit[msg.sender] to the current merkle root
     * @param newRoot new root after adding pendingCommit[msg.sender] into current merkle root
     */

    function deposit(Proof calldata, bytes32 newRoot) external nonReentrant {
        IDepositVerifier _depositVerifier = depositVerifier;
        assembly {
            mstore(0x00, caller())
            mstore(0x20, pendingCommit.slot)

            let pendingCommitSlot := keccak256(0x00, 0x40)
            let _commitment := sload(pendingCommitSlot)

            if iszero(_commitment) {
                mstore(0x00, 0x20)
                mstore(0x20, 0x0c)
                mstore(0x40, "not committed")
                revert(0x00, 0x60)
            }

            let _currentRootIndex := sload(currentRootIndex.slot)

            mstore(0x80, hex"11479fea")

            calldatacopy(0x84, 0x04, 0x100)

            mstore(0x184, sload(add(roots.slot, _currentRootIndex)))
            mstore(0x1a4, _commitment)
            mstore(0x1c4, newRoot)

            if iszero(call(gas(), _depositVerifier, 0x00, 0x80, 0x164, 0x00, 0x20)) { revert(0x00, 0x00) }

            if iszero(mload(0x00)) { revert(0x00, 0x00) }

            // set pending commit to 0 bytes
            sstore(pendingCommitSlot, 0x00)

            let newCurrentRootIndex := mod(add(_currentRootIndex, 0x01), ROOT_HISTORY_SIZE)

            // update currentRootIndex
            sstore(currentRootIndex.slot, newCurrentRootIndex)

            // update root
            sstore(add(roots.slot, newCurrentRootIndex), newRoot)

            let _nextIndex := sload(nextIndex.slot)

            // increment next index by 1
            sstore(nextIndex.slot, add(_nextIndex, 0x01))

            mstore(0x00, _nextIndex)
            mstore(0x20, timestamp())

            log2(0x00, 0x40, 0xe1f1096fd8bc7d572fb7ad7e4102736b6615500975c0252ea91ef1b765c49897, _commitment)
        }
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
        Proof calldata,
        bytes32 _root,
        bytes32 _nullifierHash,
        address payable _recipient,
        address payable _relayer,
        uint256 _fee
    ) external nonReentrant {
        IWithdrawVerifier _withdrawVerifier = withdrawVerifier;
        uint256 _denomination = denomination;
        bytes32 _nullifierHashesSlot;

        assembly {
            if gt(_fee, _denomination) { revert(0x00, 0x00) }

            mstore(0x00, _nullifierHash)
            mstore(0x20, nullifierHashes.slot)

            _nullifierHashesSlot := keccak256(0x00, 0x40)

            let nullifierHash_ := sload(_nullifierHashesSlot)

            if eq(nullifierHash_, 0x01) {
                mstore(0x80, hex"08c379a0")
                mstore(0x84, 0x20)
                mstore(0xa4, 0x1f)
                mstore(0xc4, "The note has been already spent")
                revert(0x80, 0x63)
            }
        }

        require(isKnownRoot(_root), "Cannot find your merkle root"); // Make sure to use a recent one

        assembly {
            mstore(0x80, hex"34baeab9")
            calldatacopy(0x84, 0x04, 0x1a0)

            if iszero(call(gas(), _withdrawVerifier, 0x00, 0x80, 0x1a4, 0x00, 0x20)) { revert(0x00, 0x00) }

            if iszero(mload(0x00)) {
                mstore(0x80, 0x20)
                mstore(0xa0, 0x16)
                mstore(0xc0, "Invalid withdraw proof")
                revert(0x80, 0x56)
            }

            sstore(_nullifierHashesSlot, 0x01)
        }

        _processWithdraw(_recipient, _relayer, _fee);

        assembly {
            mstore(0x00, _recipient)
            mstore(0x20, _nullifierHash)
            mstore(0x40, _fee)
            log2(0x00, 0x60, 0xe9e508bad6d4c3227e881ca19068f099da81b5164dd6d62b2eaf1e8bc6c34931, _relayer)
        }
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
