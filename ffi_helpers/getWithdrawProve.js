const { getWithdrawProve } = require('./lib/getWithdrawProve')

let r
getWithdrawProve(
  parseInt(process.argv[2]),
  parseInt(process.argv[3]),
  process.argv[4],
  process.argv[5],
  process.argv[6],
  process.argv[7],
  parseInt(process.argv[8]),
  process.argv[9],
).then((res) => {
  r = res
  console.log(res)
  process.exit(0)
});
