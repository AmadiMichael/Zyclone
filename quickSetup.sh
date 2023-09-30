# Use existing public phase 1 setup
PHASE1=build/phase1_final.ptau
PHASE2=build/phase2_final.ptau
WITHDRAW_CIRCUIT_ZKEY=build/withdraw_circuit_final.zkey
DEPOSIT_CIRCUIT_ZKEY=build/deposit_circuit_final.zkey

# Phase 1
if [ -f "$PHASE1" ]; then
    echo "Phase 1 file exists, no action"
else
    echo "Phase 1 file does not exist, downloading ..."
    curl -o $PHASE1 https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_14.ptau
fi

# Untrusted phase 2
npx snarkjs powersoftau prepare phase2 $PHASE1 $PHASE2 -v


npx snarkjs zkey new build/withdraw.r1cs $PHASE2 $WITHDRAW_CIRCUIT_ZKEY
npx snarkjs zkey new build/deposit.r1cs $PHASE2 $DEPOSIT_CIRCUIT_ZKEY


npx snarkjs zkey export verificationkey $WITHDRAW_CIRCUIT_ZKEY build/withdraw_verification_key.json
npx snarkjs zkey export verificationkey $DEPOSIT_CIRCUIT_ZKEY build/deposit_verification_key.json


npx snarkjs zkey export solidityverifier $WITHDRAW_CIRCUIT_ZKEY build/WithdrawVerifier.sol
npx snarkjs zkey export solidityverifier $DEPOSIT_CIRCUIT_ZKEY build/DepositVerifier.sol