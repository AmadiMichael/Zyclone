import { MerkleTree } from "./merkleTree.js";
import { ethers } from "ethers";
import { buildPoseidon } from "circomlibjs";
import { PoseidonHasher } from './utils'
import { prove } from './witness'
import { type CircuitSignals } from "snarkjs";

export async function getWithdrawProve(
  height: number,
  leafIndex: number,
  nullifier: string,
  nullifierHash: string,
  recipient: string,
  relayer: string,
  fee: number,
  _pushedCommitments: string,
) {
  let poseidon = await buildPoseidon();

  const tree = new MerkleTree(height, "test", new PoseidonHasher(poseidon));

  const pushedCommitments = ethers.utils.defaultAbiCoder.decode(
    ["bytes32[]"],
    _pushedCommitments,
  )[0];

  for (let i = 0; i < pushedCommitments.length; i++) {
    await tree.insert(pushedCommitments[i]);
  }

  const { root, path_elements, path_index } = await tree.path(leafIndex);

  const witness: CircuitSignals = {
    // Public
    root,
    nullifierHash,
    recipient,
    relayer,
    fee,
    // Private
    nullifier: ethers.BigNumber.from(nullifier).toBigInt(),
    pathElements: path_elements,
    pathIndices: path_index,
  };

  const solProof = await prove(witness);

  return ethers.utils.defaultAbiCoder.encode(
    [
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "uint256",
      "bytes32",
    ],
    [
      solProof.a[0],
      solProof.a[1],
      solProof.b[0][0],
      solProof.b[0][1],
      solProof.b[1][0],
      solProof.b[1][1],
      solProof.c[0],
      solProof.c[1],
      root,
    ],
  )
}
