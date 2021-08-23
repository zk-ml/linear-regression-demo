
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

  let finalsol1 = fs.readFileSync("LibVerifier1.sol.template").toString();
  let finalsol2 = fs.readFileSync("LibVerifier2.sol.template").toString();
  let finalsol3 = fs.readFileSync("LibVerifier3.sol.template").toString();

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

    const verified = await snarkjs.groth16.verify(verification_key, publicSignals, proof, logger);
    if (!verified) throw new Error("Could not verify the proof");

    if (process.argv.length !== 3) {
      var enc = new TextEncoder();
      const theirTemplate = enc.encode(`
    vk.alfa1 = LibPairing.G1Point(<%vk_alpha1%>);
    vk.beta2 = LibPairing.G2Point(<%vk_beta2%>);
    vk.gamma2 = LibPairing.G2Point(<%vk_gamma2%>);
    vk.delta2 = LibPairing.G2Point(<%vk_delta2%>);
    vk.IC = new LibPairing.G1Point[](<%vk_ic_length%>);
    <%vk_ic_pts%>
    `);

      const circuit_sol = await snarkjs.zKey.exportSolidityVerifier(final_zkey, theirTemplate, logger);
      const path = cwd + "/" + wasmOutPath + "/" + snakeToCamel(circuitName) 
      fs.writeFileSync(
        path + "/" + snakeToCamel(circuitName) + ".wasm",
        wasm
      );
      fs.writeFileSync(
        path + "/" + snakeToCamel(circuitName) + ".zkey",
        final_zkey.data
      );
      fs.writeFileSync(
        cwd + "/artifacts/" + snakeToCamel(circuitName) + ".wasm",
        wasm
      );
      fs.writeFileSync(
        cwd + "/artifacts/" + snakeToCamel(circuitName) + ".zkey",
        final_zkey.data
      );
      require('child_process').execSync(`cd ${path} && split -b50m ${snakeToCamel(circuitName) + ".zkey"} ${snakeToCamel(circuitName) + ".zkey."}`)
      require('child_process').execSync(`cd ${path} && rm ${snakeToCamel(circuitName) + ".zkey"}`)
      // add new circuits to this array, we already too big for Verifier1
      if(["path"].includes(circuitName)){
        finalsol2 = finalsol2.replace("{{" + snakeToCamel(circuitName) + "VerifyingKey}}", circuit_sol)
        finalsol2 = finalsol2.replace(/= Pairing/g, "= LibPairing");
      } else if(["dfs"].includes(circuitName)) {
        finalsol3 = finalsol3.replace("{{" + snakeToCamel(circuitName) + "VerifyingKey}}", circuit_sol)
        finalsol3 = finalsol3.replace(/= Pairing/g, "= LibPairing");
      } else {
        finalsol1 = finalsol1.replace("{{" + snakeToCamel(circuitName) + "VerifyingKey}}", circuit_sol)
        finalsol1 = finalsol1.replace(/= Pairing/g, "= LibPairing");
      }
    }
  }

  if (process.argv.length !== 3) {
    fs.writeFileSync(cwd + "/" + verifierOutPath + "/LibVerifier1.sol", finalsol1);
    fs.writeFileSync(cwd + "/" + verifierOutPath + "/LibVerifier2.sol", finalsol2);
    fs.writeFileSync(cwd + "/" + verifierOutPath + "/LibVerifier3.sol", finalsol3);
  }
}

run()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });