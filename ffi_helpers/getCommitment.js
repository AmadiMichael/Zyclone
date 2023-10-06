const { getCommitment } = require('./lib/getCommitment')

getCommitment(parseInt(process.argv[2]))
  .then((res) => {
    console.log(res)
    process.exit(0)
  });
