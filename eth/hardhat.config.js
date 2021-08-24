require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-web3");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs) => {
    const account = web3.utils.toChecksumAddress(taskArgs.account);
    const balance = await web3.eth.getBalance(account);

    console.log(web3.utils.fromWei(balance, "ether"), "ETH");
  });

task("claim_bounty", "Claim bounty")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");
    const snarkjs = require("snarkjs");

    const { Keypair } = require('maci-domainobjs');
    const mimc7 = require('../circomlib/src/mimc7.js');
    //console.log(mimc7)

    const key1 = new Keypair();
    const key2 = new Keypair();
    const sharedKey = Keypair.genEcdhSharedKey(key1.privKey, key2.pubKey);

    const rawdata = fs.readFileSync('../inputs.json');
    const data = JSON.parse(rawdata);
    console.log(data);

    function tobigint(value) {
      return BigInt(value);
    }

    var to_hash = [];
    var m = 1;
    var p = 10;
    var n = 1;

    var idx = 0;
    for (var i = 0; i < m; i++) {
        for (var j = 0; j < p; j++) {
            to_hash.push(data.X_q[i][j]);
            idx = idx + 1;
            
        }
    }

    for (var i = 0; i < m; i++) {
        for (var j = 0; j < n; j++) {
            to_hash.push(data.Yt_q[i][j]);
            idx = idx + 1;
        }
    }

    to_hash.push(data.z_X);
    idx = idx + 1; 
    to_hash.push(data.z_W);
    idx = idx + 1;
    to_hash.push(data.z_b);
    idx = idx + 1;
    to_hash.push(data.z_Y);
    idx = idx + 1;
    to_hash.push(data.sbsY_numerator);
    idx = idx + 1;
    to_hash.push(data.sbsY_denominator);
    idx = idx + 1;
    to_hash.push(data.sXsWsY_numerator);
    idx = idx + 1;
    to_hash.push(data.sXsWsY_denominator);
    idx = idx + 1;

    to_hash.push(data.sYsR_numerator);
    idx = idx + 1;
    to_hash.push(data.sYsR_denominator);
    idx = idx + 1;
    to_hash.push(data.sYtsR_numerator);
    idx = idx + 1;
    to_hash.push(data.sYtsR_denominator);
    idx = idx + 1;
    to_hash.push(data.constant);
    idx = idx + 1;

    to_hash.push(data.z_R);
    idx = idx + 1;
    to_hash.push(data.z_Sq);
    idx = idx + 1;
    to_hash.push(data.sR2sSq_numerator);
    idx = idx + 1;
    to_hash.push(data.sR2sSq_denominator);
    idx = idx + 1;

    const hash_input = mimc7.multiHash(to_hash.map(tobigint), BigInt(0));

    const W_q_enc = data.W_q.map(function(arr) {
      return arr.slice().map(tobigint);
    });

    const b_q_enc = data.b_q.slice().map(tobigint);

    for (let i = 0; i < b_q_enc.length; i++) {
      var val1 = mimc7.multiHash([b_q_enc[i]], BigInt(0));
      var val2 = mimc7.hash(sharedKey, val1);
      b_q_enc[i] = [val1, b_q_enc[i]+val2];
    }

    //console.log(W_q_enc);

    for (let i = 0; i < W_q_enc.length; i++) {
      for (let j = 0; j < W_q_enc[0].length; j++) {
        var val1 = mimc7.multiHash([W_q_enc[i][j]], BigInt(0));
        var val2 = mimc7.hash(sharedKey, val1);
        W_q_enc[i][j] = [val1, W_q_enc[i][j]+val2];
      }
    }
    console.log(b_q_enc);
    //console.log(W_q_enc);

    const input_test = {
      shared_key: sharedKey.toString(),
      private_key: key1.privKey.asCircuitInputs(),
      public_key: key2.pubKey.asCircuitInputs(),
      message: 1234,
    };

    fs.writeFile(
      '../encrypt/test_input.json',
      JSON.stringify(input_test),
      () => {},
    );

    const _input = {
      hash_input: hash_input,
      private_key: key1.privKey.asCircuitInputs(),
      public_key: key2.pubKey.asCircuitInputs(),
      W_q_enc : W_q_enc,
      b_q_enc : b_q_enc,
    };

    const input = Object.assign({}, data, _input);

    BigInt.prototype.toJSON = function() { return this.toString()  }

    fs.writeFile(
      '../input.json',
      JSON.stringify(input, null, 2),
      () => {},
    );

    const final_zkey = fs.readFileSync("../circuits/artifacts/lr.zkey");
    const wasm = fs.readFileSync("../circuits/artifacts/lr.wasm");
    const wtns = { type: "mem" };
    const input = JSON.parse(fs.readFileSync("./artifacts/quantization/inputs.json"));

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

    console.log("Success!");
  });

task("deposit_bounty", "Deposit bounty")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");
    const snarkjs = require("snarkjs");

    execSync("python3 scripts/gemm.py", {
      stdio: "inherit",
    });

    console.log("Success!");
  });
// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.6.11",
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
    },
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
