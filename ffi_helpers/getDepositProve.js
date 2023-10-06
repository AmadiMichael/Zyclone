const { getDepositProve } = require('./lib/getDepositProve')

getDepositProve(
  parseInt(process.argv[2]),
  parseInt(process.argv[3]),
  process.argv[4],
  process.argv[5],
  process.argv[6],
).then((res) => {
  console.log(res)
  process.exit(0)
});
