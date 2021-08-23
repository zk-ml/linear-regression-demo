snarkjs wtns calculate encrypt.wasm input.json witness.wtns
snarkjs groth16 prove encrypt_final.zkey witness.wtns proof.json public.json
snarkjs groth16 verify verification_key.json public.json proof.json
