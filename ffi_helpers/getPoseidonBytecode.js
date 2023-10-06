const { poseidon } = require('./lib/getPoseidonBytecode')

console.log(poseidon(parseInt(process.argv[2])));
