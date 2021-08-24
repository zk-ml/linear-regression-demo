
require("dotenv").config();

const { execSync } = require("child_process");
const fs = require("fs");
const snarkjs = require("snarkjs");

const finalZkeyPath = process.argv[2];
const wasmPath = process.argv[3];
const inputPath = process.argv[4];

async function run() {
    const final_zkey = fs.readFileSync(finalZkeyPath);
    const wasm = fs.readFileSync(wasmPath);
    const wtns = { type: "mem" };
    const input = JSON.parse(fs.readFileSync(inputPath));

    const logger = {
        debug: () => { },
        info: console.log,
        warn: console.log,
        error: console.log,
    };

    const cwd = process.cwd();

    const verification_key = await snarkjs.zKey.exportVerificationKey(final_zkey);
    await snarkjs.wtns.calculate(input, wasm, wtns, logger);
    const start = Date.now();
    const { proof, publicSignals } = await snarkjs.groth16.prove(final_zkey, wtns, logger);
    console.log("Proof took " + (Date.now() - start) / 1000 + " s");

    const verified = await snarkjs.groth16.verify(verification_key, publicSignals, proof, logger);
    if (!verified) throw new Error("Could not verify the proof");

    const call_data = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    fs.writeFileSync(
        cwd + "/sample_calldata.json",
        call_data
      );
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });