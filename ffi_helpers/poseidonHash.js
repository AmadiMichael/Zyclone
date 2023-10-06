const { hash } = require('./lib/poseidonHash')

hash(process.argv[2], process.argv[3])
  .then((res) => {
    console.log(res)
    process.exit(0)
  });
