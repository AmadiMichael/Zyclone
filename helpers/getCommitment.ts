import * as ethers from 'ethers'
import { type Poseidon, poseidonHash } from './utils'
import { buildPoseidon } from "circomlibjs"

export class Deposit {
  poseidon!: Poseidon
  nullifier!: Uint8Array
  leafIndex!: number
  constructor(poseidon: Poseidon, leafIndex: number) {
    this.poseidon = poseidon
    this.nullifier = ethers.utils.randomBytes(15)
    this.leafIndex = leafIndex
  }

  get commitment() {
    return poseidonHash(this.poseidon, [this.nullifier, 0])
  }

  get nullifierHash() {
    if (!this.leafIndex && this.leafIndex !== 0)
      throw Error("leafIndex is unset yet")
    return poseidonHash(this.poseidon, [this.nullifier, 1, this.leafIndex])
  }
}

export async function getCommitment(leafIndex: number) {
  let poseidon = await buildPoseidon()
  let deposit = new Deposit(poseidon, leafIndex)
  return ethers.utils.defaultAbiCoder.encode(
    ["bytes32", "bytes32", "bytes32"],
    [
      deposit.commitment,
      deposit.nullifierHash,
      ethers.utils.hexZeroPad(deposit.nullifier, 32),
    ],
  )
}
