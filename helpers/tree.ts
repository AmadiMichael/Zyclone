import { MerkleTree } from "./merkleTree";
import { buildPoseidon } from "circomlibjs";
import { PoseidonHasher } from "./utils";
import * as ethers from 'ethers'

export async function tree(height: number, _pushedCommitments: ethers.BytesLike, newCommitment: string) {
  let poseidon = await buildPoseidon();

  const tree = new MerkleTree(height, "test", new PoseidonHasher(poseidon));

  const pushedCommitments = ethers.utils.defaultAbiCoder.decode(
    ["bytes32[]"],
    _pushedCommitments,
  )[0] as string[];

  for (let i = 0; i < pushedCommitments.length; i++) {
    await tree.insert(pushedCommitments[i]);
  }

  const before = await tree.root();

  await tree.insert(newCommitment);

  const elements = tree.totalElements;
  const after = await tree.root();
  return ethers.utils.defaultAbiCoder.encode(
    ["bytes32", "uint256", "bytes32"],
    [before, elements, after],
  )
}
