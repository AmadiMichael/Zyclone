import { type CircuitSignals, groth16 } from "snarkjs";
import * as path from 'path'

const dirname = __dirname

export async function prove(witness: CircuitSignals) {
  // path is relative to destination
  const buildFolder = path.join(dirname, '..', '..', 'build')
  const wasmPath = path.join(buildFolder, 'deposit_js', 'deposit.wasm')
  const zkeyPath = path.join(buildFolder, 'deposit_circuit_final.zkey')

  const { proof } = await groth16.fullProve(witness, wasmPath, zkeyPath);

  const solProof = {
    a: [proof.pi_a[0], proof.pi_a[1]],
    b: [
      [proof.pi_b[0][1], proof.pi_b[0][0]],
      [proof.pi_b[1][1], proof.pi_b[1][0]],
    ],
    c: [proof.pi_c[0], proof.pi_c[1]],
  };
  return solProof
}
