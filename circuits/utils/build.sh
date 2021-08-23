snarkjs zkey new encrypt.r1cs pot12_final.ptau encrypt_0000.zkey
snarkjs zkey contribute encrypt_0000.zkey encrypt_final.zkey --name="1st Contributor Name" -v
snarkjs zkey export verificationkey encrypt_final.zkey verification_key.json
