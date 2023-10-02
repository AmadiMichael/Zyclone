# Quick setup and test

After cloning locally, run `forge install` and `npm install` to install dependencies. Be sure to already have [circom](https://docs.circom.io/getting-started/installation/#installing-dependencies) installed.

To quickly run tests:

- `npm run build`: which compiles the circuits, downloads phase 1 and 2 of the trusted setup, generate the r1cs and zkey files and generates the solidity verifier contracts.
- `npm run test`: Same as `forge test -vvv --gas-report`.
- `forge test -vvv --gas-report`: Runs all tests (Solidity, Inline assembly and Huff implementation tests).
  - `--mc ZycloneSolidityTest`: Test solidity implementation.
  - `--mc ZycloneInlineAssemblyTest`: Test Inline assembly implementataion.
  - `--mc ZycloneHuffTest`: Test the Huff implementation.

Each of the implementation's test inherit a base test `Zyclone.t.sol` which holds all the tests. The individual test files for each implementation only updates the zyclone instance to be used for testing.

# Zyclone 🌀

Zyclone is a Mixer similar to Tornado Cash but with some extra modifications to its approach in order to achieve the significant gas savings listed below.

### General Benchmarks

| Version      | Creation code size | Creation gas cost | Runtime code size | Runtime gas cost |
| ------------ | ------------------ | ----------------- | ----------------- | ---------------- |
| Tornado Cash | -                  | -                 | -                 | -                |
| Zyclone      | -                  | -                 | -                 | -                |

### Function call benchmarks

| Version      | Deposit | Withdraw |
| ------------ | ------- | -------- |
| Tornado Cash | 1088354 | 301233   |
| Zyclone      | 232131  | 252289   |

## Differences

- Different and more efficient hash function and hash generation patterns:

  Tornado cash uses `pedersonHash(secret, nullifier)` and `pedersonHash(nullifier)` for generation of valid commitment and nullifer hashes respectively. Zyclone on the other hand uses `poseidonHash(nullifier, 0)` and `poseidonHash(nullifier, 1, leafIndex)` instead.

  An advantage of this approach is that it supports nullifer reuse as no leafIndex can be owned by 2 commitmentHashes in the tree (even if it's the same commitmentHash, the tree is append-only), their nullifierHash would never be the same. The current version of Tornado Cash does not stop you from using the same nullifier, but if done, the user won't be able to withdraw their tokens the second time. This approach greatly reduces chance of loss of money. Though current Tornado cash stops you from reusing the same commitment hash, if the user changes the secret but forget to change the nullifier, this still holds.

- Depositing with reduced onchain computation:

  To deposit into Tornado cash, the user's commitment hash is added to the tree onchain and MiMCSponge is used to hash nodes, this can be very expensive as it involves a lot of loops and 20 external calls to the MiMCSponge contract, then it also updates more than 22 storage variables. This can be very expensive to use.

  Zyclone uses a different approach, rather than performing all these computation onchain, why not let the user do it themselves and prove to the contract that they did it correctly using zkSNARKs. Basically, the user would reconstruct the current state of the merkle tree, add their commitment hash to it, then parse in the necessary signals to generate a proof which can be verified onchain, if this verification checks out, the root is updated to be the new root they parsed in. This way the only data needed to be stored onchain and updated is 1 storage slot per deposit.

# Code Methodology and Setup

This codebase was implemented from ground up starting with a solidity version, then an intermediate representation using inline assembly for complex functions before implementing in huff.
This also means there's a solidity and yul reference for quick scanning of the codebase.

In the huff folder, it is separated into 6 files

- `Utils.huff`: Which holds all the utilities (slot getters, internal and private functions) used across the rest of the huff codebase
- `Getters.huff`: Holds the macro implementation of the external getter functions for relevant storage and `immutable` variables
- `Deposit.huff`: Holds the macro implementation of `commit`, `clear` and `deposit` external functions
- `Withdraw.huff`: Holds the macro implementation of `withdraw` function.
- `Zyclone.huff`: Holds the interface definitions, events, constants and function dispatcher used by the rest of the huff codebase.
  - It imports the files listed above and acts as an abstract contract that can be used in a modular way for ETH mixers and ERC20 mixers alike
- `ETHZyclone.huff`: Inherits `Zyclone.huff` abstract huff file and implements `processDeposit` and `processWithdraw` to make it work as an ETH mixer. Also, it holds the constructor code.

Each relevant external function is heavily documented with a well defined calldata layout.
