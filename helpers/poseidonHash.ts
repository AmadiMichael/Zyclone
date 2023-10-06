import { buildPoseidon } from "circomlibjs";
import { poseidonHash } from "./utils";
import { BytesLike } from "ethers";

export async function hash(left: BytesLike, right: BytesLike) {
  let poseidon = await buildPoseidon();
  return poseidonHash(poseidon, [left, right]);
}
