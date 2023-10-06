import { BigNumberish, BytesLike, ethers } from "ethers";
import { buildPoseidon } from "circomlibjs"

export type Poseidon = Awaited<ReturnType<typeof buildPoseidon>>

export type HashInputs = [BigNumberish, BigNumberish] | [BigNumberish, BigNumberish, BigNumberish]

export const poseidonHash = (poseidon: Poseidon, inputs: HashInputs) =>  {
  const hash = poseidon(inputs.map((x: BigNumberish) => ethers.BigNumber.from(x).toBigInt()));
  // Make the number within the field size
  const hashStr = poseidon.F.toString(hash);
  // Make it a valid hex string
  const hashHex = ethers.BigNumber.from(hashStr).toHexString();
  // pad zero to make it 32 bytes, so that the output can be taken as a bytes32 contract argument
  const bytes32 = ethers.utils.hexZeroPad(hashHex, 32);
  return bytes32;
}

export class PoseidonHasher {
  poseidon!: Poseidon;

  constructor(poseidon: Poseidon) {
    this.poseidon = poseidon;
  }

  hash(left: BytesLike, right: BytesLike) {
    return poseidonHash(this.poseidon, [left, right]);
  }
}
