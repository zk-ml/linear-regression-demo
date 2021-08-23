
require("dotenv").config();

const { execSync } = require("child_process");
const fs = require("fs");
const snarkjs = require("snarkjs");

const circuitsList = process.argv[2];
const wasmOutPath = process.argv[3];
const zkeyOutPath = process.argv[4];
const verifierOutPath = process.argv[5];
const deterministic = process.argv[6] === "true";

if (process.argv.length !== 3 && process.argv.length !== 7) {
  console.log("usage");
  console.log(
    "builder comma,seperated,list,of,circuits wasm_out_path zkey_out_path verifier_out_path [`true` if deterministic / `false` if not]"
  );
  process.exit(1);
}

const snakeToCamel = (str) =>
  str.replace(/([-_][a-z])/g, (group) => group.toUpperCase().replace("-", "").replace("_", ""));

async function run() {
  const logger = {
    debug: () => { },
    info: console.log,
    warn: console.log,
    error: console.log,
  };

  const cwd = process.cwd();

  for (circuitName of circuitsList.split(",")) {
    console.log("> Compiling " + circuitName);
    if (deterministic && !process.env[circuitName.toUpperCase() + "_BEACON"]) {
      console.log("ERROR! you probably dont have an .env file");
      process.exit(1);
    }

    process.chdir(cwd + "/" + circuitName);

    // fastfile in memory instead of temp files
    const newKey = { type: "mem" };
    const final_zkey = { type: "mem" };
    const wtns = { type: "mem" };

    const input = JSON.parse(fs.readFileSync("./input.json"));

    // TODO fastfile support for circom is iffy for wasm and sym generation
    execSync("npx circom circuit.circom --r1cs --wasm", {
      stdio: "inherit",
    });

    // read results back into memory
    const r1cs = fs.readFileSync("./circuit.r1cs");
    const wasm = fs.readFileSync("./circuit.wasm");
    const ptau = "../" + fs.readdirSync("../").filter((fn) => fn.endsWith(".ptau"))[0];
    console.log("Using ptau: " + ptau);

    const _cir = await snarkjs.r1cs.info(r1cs, logger);
    const _csHash = await snarkjs.zKey.newZKey(r1cs, ptau, newKey, logger);

    const _contributionHash = deterministic
      ? await snarkjs.zKey.beacon(
        newKey,
        final_zkey,
        undefined,
        process.env[circuitName.toUpperCase() + "_BEACON"],
        10,
        logger
      )
      : await snarkjs.zKey.contribute(newKey, final_zkey, undefined, `${Date.now()}`, logger);

    const verification_key = await snarkjs.zKey.exportVerificationKey(final_zkey);
    await snarkjs.wtns.calculate(input, wasm, wtns, logger);
    const start = Date.now();
    const { proof, publicSignals } = await snarkjs.groth16.prove(final_zkey, wtns, logger);
    console.log("Proof took " + (Date.now() - start) / 1000 + " s");

    const call_data = snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
    console.log(call_data);

    const verified = await snarkjs.groth16.verify(verification_key, publicSignals, proof, logger);
    if (!verified) throw new Error("Could not verify the proof");

    if (process.argv.length !== 3) {
      const templates = {};
      templates.groth16 = await fs.promises.readFile(cwd+"/templates/verifier_groth16.sol.ejs", "utf8");
      templates.plonk = await fs.promises.readFile(cwd+"/templates/verifier_plonk.sol.ejs", "utf8");  
      //const template = cwd+"/templates/verifier_groth16.sol.ejs";
      //console.log(templates);
      //console.log(final_zkey);
      const path = cwd + "/" + wasmOutPath + "/" + snakeToCamel(circuitName) 

      fs.writeFileSync(
        path + "/" + snakeToCamel(circuitName) + ".zkey",
        final_zkey.data
      );

      const zkey_path = path + "/" + snakeToCamel(circuitName) + ".zkey";

      const circuit_sol = await snarkjs.zKey.exportSolidityVerifier(zkey_path, templates, logger);
      //console.log(circuit_sol);
      fs.writeFileSync(
        path + "/" + snakeToCamel(circuitName) + ".wasm",
        wasm
      );
      fs.writeFileSync(
        cwd + "/artifacts/" + snakeToCamel(circuitName) + ".wasm",
        wasm
      );
      fs.writeFileSync(
        cwd + "/artifacts/" + snakeToCamel(circuitName) + ".zkey",
        final_zkey.data
      );
      
      fs.writeFileSync(cwd + "/" + verifierOutPath + "/LibVerifier.sol", circuit_sol);
    }
  }
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });