const { tree } = require('./lib/tree')

tree(parseInt(process.argv[2]), process.argv[3], process.argv[4])
  .then((res) => {
    console.log(res)
    process.exit(0)
  });
