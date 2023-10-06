import { MerkleTree } from "./merkleTree";
import { BytesLike, ethers } from "ethers";
import { buildPoseidon } from "circomlibjs";
import { PoseidonHasher } from "./utils";
import { prove } from "./witness";
import { type CircuitSignals } from 'snarkjs'

export async function getDepositProve(
  height: number,
  leafIndex: number,
  oldRoot: string,
  commitmentHash: string,
  _pushedCommitments: BytesLike,
) {
  let poseidon = await buildPoseidon();

  const tree = new MerkleTree(height, "test", new PoseidonHasher(poseidon));

  const pushedCommitments = ethers.utils.defaultAbiCoder.decode(
    ["bytes32[]"],
    _pushedCommitments,
  )[0] as string[];

  for (let i = 0; i < pushedCommitments.length; i++) {
    await tree.insert(pushedCommitments[i]);
  }

  const { path_elements, path_index } = await tree.path(leafIndex);
  const topNodes = await tree.getTopTwoElements();

  await tree.insert(commitmentHash);
  const root = await tree.root();

  const witness: CircuitSignals = {
    // Public
    oldRoot,
    commitmentHash,
    root,

    // Private
    topNodes,
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
