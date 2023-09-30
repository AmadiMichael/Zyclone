# Zyclone

Zyclone is a a Mixer similar to Tornado Cash but with some extra modifications to it's approach in order to achieve the significant gas savings listed below.

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

- Different and more efficient hash function and hash generation patterns: Tornado cash uses `pedersonHash(secret, nullifier)` and `pedersonHash(nullifier)` for generation of valid commitment and nullifer hashes respectively. Zyclone on the order hand uses `poseidonHash(nullifier, 0)` and `poseidonHash(nullifier, 1, leafIndex)` instead. An advantage of this approach is that it supports nonce reuse as no leafIndex can be owned by 2 commitmentHashes in the tree (even if it's the same commitmentHash, the tree is append-only), their nullifierHash would never be the same. Current version of tornado cash does not stop you from using the same nullifier, but if done, the user won't be able to withdraw their tokens the second time. This approach greatly reduces chance of loss of money.

- Depositing with reduced onchain computation: To deposit into Tornado cash, the user's parsed in commitment hash is added to the tree onchain and MiMCSponge is used to hash nodes, this can be very expensive as it involves a lot of loops and 20 external calls to the MIMCSponge contract, then it also updates more than 22 storage variables. This can be very expensive to use. Zyclone uses a different approach, rather than performing all these computation onchain, why not let the user do it themselves and prove to the contract that they did it correctly using zkSNARKs. Basically, the user would reconstruct the current state of the merkle tree, add their commitment hash to it, then parse in the necessary signals to generate a proof which can be verified onchain, if this verification checks out, the root is updated to be the new root they parsed in. This way they only data needed to eb stored onchain and updated is 1 storage slot per deposit.
