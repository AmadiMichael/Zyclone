# Original TC

- commitmentHash = pederson(secret, nullifier)
- nullifierHash = pederson(nullifier)

e.g

### deposit into a

nullifier = 11

commitmentHash = pederson(10000, 11)

nullifierHash = pederson(11) // will be cancelled out

### deposit into b

nullifier = 11

commitmentHash = pederson(10000, 11)

nullifierHash = pederson(11) // Won't work

// deposit

- User A -> Deposit{value: 1 ether}(commitmentHash);
  - It adds commitmentHash to the merkle tree, onchain
    - keeps track of the pathElements, currentRoot onchain
    - to add your commitmentHash to the tree, it does MiMC hash on chain for each level

// withdraw

### Create a proof

Public inputs: root, nullifierHash, recipient, relayer, fee, refund

private inputs: secret, nullifier, pathElements, pathIndices

Prove that you know the `nullifier` and `secret` that

- proof === pederson(secret, nullifier) is inside the merkle tree at index `base10(pathIndices)`

- User B -> Withdraw(proof, [root, nullifierHash, recipient, relayer, fee, refund])

```rs
library Tree {
  function insert(leaf, index, pathElements) -> bytes32;
}

using Tree for bytes32;

function proof(expectedRoot, leaf, pathElements, index) -> bool {
  expectedRoot == leaf.insert(index, pathElements);
}

proof(root, a, [b, cd, efgh], 0);

                                                               root

                                                abcd                           efgh                 // 2

                                        ab               cd             ef               gh         // 1

                                    a       b        c       d       e       f        g       h     // 0

MiMCSponge(a, b)

levels = logN base arity
3 = log8 base2

c = log b base a
a ** c == b


currentValue = h
index = 7 // index of currentValue at a given level, default level is level 0
pathElements = [g, ef, abcd]
pathIndices = [1, 1, 1]
111 = 7


for (uint256 i = 0; i < levels; ++i) {
 if (index % 2 == 0) {
  currentValue = hash(currentVal, zeros(i))
  pathElements[i] = currentVal;
 } else {
  currentValue = hash(pathElements[i], currentVal);
 }
 index /= 2;
}

```

# Zyclone 🌀

- commitmentHash = poseidon(nullifier, 0)
- "nullifierHash" = poseidon(nullifier, 1, leafIndex)

e.g

### deposit into a

nullifier = 11

commitmentHash = poseidon(11, 0)

nullifierHash = poseidon(11, 1, 0)

### deposit into b

nullifier = 11

commitmentHash = poseidon(11, 0)

nullifierHash = poseidon(11, 1, 1)

- Deposit: Let user add their commitment hash to the `current` merkle tree offchain and proof to the contract that they did this correctly
  - What we store onchain is only the `current` root

User A:
Public: oldRoot, commitmentHash, newRoot
Private: topNodes, pathElements, pathIndices

User proves

- That `pathElement` and `pathIndices` is the pathElement and pathIndices for the current root stored in the contract
  - The user provides the top two branches that hash up to the current root stored in the contract and the circuit asserts that either one of two is pathElements[levels - 1]
- That `root` === `oldRoot.insert(commitmentHash)` where insert() returns the new root.

```rs
                                                               root

                                                abcd                           efgh                 // 2

                                        ab               cd             ef               gh         // 1

                                    a       b        c       d       e       f        g       h     // 0


oldRoot = tornado.root();
commitmentHash = a (user A commitment hash)
newRoot = user A computed new root

topNodes = [abcd, efgh]
pathElements = [b, cd, efgh]
pathIndices = [0, 0, 0]
```

Users = [a, b]

user a deposit

- use default vals of root to hash up to root

user b deposit

- use user a commithash and rest of default vals of root to hash up to root
  - commit hash
  - root
  - path elements
  - path indices

deposit.circom

- takes in a oldRoot, pathElements and pathIndices, newRoot and a commitment hash
- adds commitment hash to oldRoot at index base10(pathIndices) using pathElement and pathIndices and asserts that == newRoot
