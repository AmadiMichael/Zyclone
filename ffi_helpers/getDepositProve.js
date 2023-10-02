const { MerkleTree } = require("./merkleTree.js");
const { ethers } = require("ethers");
const {
  Contract,
  ContractFactory,
  BigNumber,
  BigNumberish,
} = require("ethers");
const { poseidonContract, buildPoseidon } = require("circomlibjs");
const path = require("path");
const { groth16 } = require("snarkjs");

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

class PoseidonHasher {
  poseidon;

  constructor(poseidon) {
    this.poseidon = poseidon;
  }

  hash(left, right) {
    return poseidonHash(this.poseidon, [left, right]);
  }
}

async function prove(witness) {
  const wasmPath = path.join(__dirname, "../build/deposit_js/deposit.wasm");
  const zkeyPath = path.join(__dirname, "../build/deposit_circuit_final.zkey");

  const { proof } = await groth16.fullProve(witness, wasmPath, zkeyPath);

  const solProof = {
    a: [proof.pi_a[0], proof.pi_a[1]],
    b: [
      [proof.pi_b[0][1], proof.pi_b[0][0]],
      [proof.pi_b[1][1], proof.pi_b[1][0]],
    ],
    c: [proof.pi_c[0], proof.pi_c[1]],
  };
  return solProof;
}

async function getDepositProve(
  height,
  leafIndex,
  oldRoot,
  commitmentHash,
  _pushedCommitments
) {
  let poseidon = await buildPoseidon();

  const tree = new MerkleTree(height, "test", new PoseidonHasher(poseidon));

  const pushedCommitments = ethers.utils.defaultAbiCoder.decode(
    ["bytes32[]"],
    _pushedCommitments
  )[0];

  for (let i = 0; i < pushedCommitments.length; i++) {
    await tree.insert(pushedCommitments[i]);
  }

  const { _, path_elements, path_index } = await tree.path(leafIndex);
  const topNodes = await tree.getTopTwoElements();

  await tree.insert(commitmentHash);
  const root = await tree.root();

  const witness = {
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

  console.log(
    ethers.utils.defaultAbiCoder.encode(
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
      ]
    )
  );

  // it doesn't return so use this to return
  process.exit(0);
}

getDepositProve(
  parseInt(process.argv[2]),
  parseInt(process.argv[3]),
  process.argv[4],
  process.argv[5],
  process.argv[6]
);
