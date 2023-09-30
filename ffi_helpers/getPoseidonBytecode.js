const { poseidonContract } = require("circomlibjs");

async function poseidon(nInputs) {
  console.log(poseidonContract.createCode(nInputs));
}

poseidon(parseInt(process.argv[2]));
