const { ethers } = require("ethers");
const {
  Contract,
  ContractFactory,
  BigNumber,
  BigNumberish,
} = require("ethers");
const { poseidonContract, buildPoseidon } = require("circomlibjs");

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

async function hash(left, right) {
  let poseidon = await buildPoseidon();
  let res = poseidonHash(poseidon, [left, right]);
  console.log(res);
}

hash(process.argv[2], process.argv[3]);
