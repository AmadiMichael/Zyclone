import { poseidonContract } from 'circomlibjs'

export const poseidon = (nInputs: number) => poseidonContract.createCode(nInputs)
