const { ethers } = require("ethers");
const { BigNumber } = require("ethers");
const { buildPoseidon } = require("circomlibjs");

function poseidonHash(poseidon, inputs) {
  const hash = poseidon(inputs.map((x) => BigNumber.from(x).toBigInt()));
  // Make the number within the field size
  const hashStr = poseidon.F.toString(hash);
  // Make it a valid hex string
  const hashHex = BigNumber.from(hashStr).toHexString();
  // pad zero to make it 32 bytes, so that the output can be taken as a bytes32 contract argument
  const bytes32 = ethers.utils.hexZeroPad(hashHex, 32);
  return bytes32;
}

class Deposit {
  constructor(poseidon, leafIndex) {
    this.poseidon = poseidon;
    this.nullifier = ethers.utils.randomBytes(15);
    this.leafIndex = leafIndex;
  }

  get commitment() {
    return poseidonHash(this.poseidon, [this.nullifier, 0]);
  }

  get nullifierHash() {
    if (!this.leafIndex && this.leafIndex !== 0)
      throw Error("leafIndex is unset yet");
    return poseidonHash(this.poseidon, [this.nullifier, 1, this.leafIndex]);
  }
}

async function getCommitment(leafIndex) {
  let poseidon = await buildPoseidon();
  let deposit = new Deposit(poseidon, leafIndex);
  console.log(
    ethers.utils.defaultAbiCoder.encode(
      ["bytes32", "bytes32", "bytes32"],
      [
        deposit.commitment,
        deposit.nullifierHash,
        ethers.utils.hexZeroPad(deposit.nullifier, 32),
      ],
    ),
  );
}

getCommitment(parseInt(process.argv[2]));
