require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-web3");
require("maci-domainobjs");
require("maci-crypto");

const CONTRACT_ADDRESS = "0x0165878A594ca255338adfa4d48449f69242Eb8F";

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

task("list_bounties", "List bounties")
  .addParam("datasetHash", "Dataset hash", "15681440893605958136105542719628389980032562080249509287477198087707031153419")
  .setAction(async (taskArgs) => {
    const fs = require("fs");
    const provider = new hre.ethers.providers.JsonRpcProvider();
    const BountyManager = await hre.ethers.getContractFactory('BountyManager');
    const contract = await BountyManager.attach(CONTRACT_ADDRESS);

    wallet = await hre.ethers.getSigner();

    const write_contract = contract.connect(wallet);

    var alias = await write_contract.get_alias(taskArgs.datasetHash);

    console.log("Available bounties on dataset: " + alias);
    tx = await write_contract.query_bounties(taskArgs.datasetHash);
    const bounties = tx.map(function (x) { 
      return {"PublicKey-1": x[0].toString(16), "PublicKey-2": x[1].toString(16), "MSE-Cap":  x[2].toString(16)}; 
    });
    console.log(bounties);  
  });

  task("list_datasets", "List of datasets with alias")
  .setAction(async (taskArgs) => {
    const fs = require("fs");
    const provider = new hre.ethers.providers.JsonRpcProvider();
    const BountyManager = await hre.ethers.getContractFactory('BountyManager');
    const contract = await BountyManager.attach(CONTRACT_ADDRESS);

    wallet = await hre.ethers.getSigner();

    const write_contract = contract.connect(wallet);

    tx = await write_contract.query_datasets();
    
    const hashes = tx.map(function (x) { return x.toString(16) });
    const aliases = await Promise.all(tx.map(async function (hash) {
      var alias = await write_contract.get_alias(hash);
      return alias;
    }));
    
    const zip = (a, b) => a.map((k, i) => [k, b[i]]);

    console.log("Available datasets:");
    console.log(zip(aliases, hashes));
  });

task("claim_bounty", "Claim bounty")
  .addParam("paymentAddr", "payment address", "0x2546BcD3c84621e976D8185a91A922aE77ECEc30")
  .addParam("publicKey", "bounty issuer's publilckey", "./keys/out_public.json")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");
    const snarkjs = require("snarkjs");

    execSync("python3 scripts/quantize_model.py", {
      stdio: "inherit",
    });

    const { Keypair } = require('maci-domainobjs');
    const mimc7 = require('./node_modules/circomlib/src/mimc7.js');
    console.log(Keypair);

    const key = new Keypair();
    const pubKey = JSON.parse(fs.readFileSync(taskArgs.publicKey));
    console.log(pubKey);
    pubKey[0] = BigInt(pubKey[0]);
    pubKey[1] = BigInt(pubKey[1]);

    
    /*
    [
      BigInt("12394963504092133463590298742771255746910402294421902681602275178368694525156"),
      BigInt("2810009863761268199375234926728016029541833696552145042968279544829897552560"),
    ];
    */

    const key2 = new Keypair();
    key2.pubKey.rawPubKey = pubKey;

    const sharedKey = Keypair.genEcdhSharedKey(key.privKey, key2.pubKey);

    const rawdata = fs.readFileSync('./artifacts/quantization/inputs_ml.json');
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

    const _input = {
      hash_input: hash_input,
      private_key: key.privKey.asCircuitInputs(),
      public_key: key2.pubKey.asCircuitInputs(),
      W_q_enc : W_q_enc,
      b_q_enc : b_q_enc,
    };

    const input = Object.assign({}, data, _input);

    BigInt.prototype.toJSON = function() { return this.toString(16)  }

    fs.writeFileSync(
      './artifacts/quantization/inputs.json',
      JSON.stringify(input, null, 2),
      () => {},
    );

    const final_zkey = fs.readFileSync("../circuits/artifacts/lr.zkey");
    const wasm = fs.readFileSync("../circuits/artifacts/lr.wasm");
    const wtns = { type: "mem" };

    const logger = {
        debug: () => { },
        info: console.log,
        warn: console.log,
        error: console.log,
    };

    const verification_key = await snarkjs.zKey.exportVerificationKey(final_zkey);
    await snarkjs.wtns.calculate(input, wasm, wtns, logger);
    const start = Date.now();
    const { proof, publicSignals } = await snarkjs.groth16.prove(final_zkey, wtns, logger);
    console.log("Proof took " + (Date.now() - start) / 1000 + " s");

    const verified = await snarkjs.groth16.verify(verification_key, publicSignals, proof, logger);
    if (!verified) throw new Error("Could not verify the proof");

    function convert(x) {return '0x'+BigInt(x).toString(16);}

    arg0 = [proof.pi_a[0], proof.pi_a[1]];
    arg1 = [[proof.pi_b[0][1], proof.pi_b[0][0]], [proof.pi_b[1][1], proof.pi_b[1][0]]]
    arg2 = [proof.pi_c[0], proof.pi_c[1]];
    arg3 = publicSignals;

    const provider = new hre.ethers.providers.JsonRpcProvider();
    const BountyManager = await hre.ethers.getContractFactory('BountyManager');
    const contract = await BountyManager.attach(CONTRACT_ADDRESS);

    wallet = await hre.ethers.getSigner();

    const write_contract = contract.connect(wallet);

    console.log([arg0, arg1, arg2]);
    console.log("Paying " + taskArgs.paymentAddr);
    
    //arg3[0] = "133";

    // Receive an event when ANY transfer occurs
    write_contract.on("BountyCollected", (x) => {
      console.log("Collected Bounty: " + (x.toString()));
    });
    //console.log(arg3);

    //console.log(arg0, arg1, arg2, arg3);

    tx = await write_contract.collectBounty(taskArgs.paymentAddr, arg0, arg1, arg2, arg3);

    console.log(tx);

    console.log("Your Public Key: ");
    console.log(key.pubKey.rawPubKey);
    console.log("Your Private Key: ");
    console.log(key.privKey.rawPrivKey);
    console.log("Success!");
  });

task("add_bounty", "Deposit bounty") 
  .addParam("amount", "amount to add to bounty", "499")
  .addParam("outFile", "file prefix to export private and public key", "out")
  .addParam("privKey", "private key", "0x47c99abed3324a2707c28affff1267e45918ec8c3f20b8aa892e8b065d2942dd")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");

    execSync("python3 scripts/quantize_dataset.py", {
      stdio: "inherit",
    });

    const { Keypair } = require('maci-domainobjs');
    const mimc7 = require('./node_modules/circomlib/src/mimc7.js');
    //console.log(mimc7)

    const key = new Keypair();

    const rawdata = fs.readFileSync('./artifacts/quantization/inputs_dataset.json');
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

    console.log("Hashed inputs: ");
    console.log(hash_input);
    console.log("Your Public Key: ");
    console.log(key.pubKey.rawPubKey);
    console.log("Your Private Key: ");
    console.log(key.privKey.rawPrivKey);

    BigInt.prototype.toJSON = function() { return this.toString()  }

    fs.writeFileSync(
      './keys/'+taskArgs.outFile + '_public.json',
      JSON.stringify(key.pubKey.rawPubKey, null, 2),
      () => {},
    );

    fs.writeFileSync(
      './keys/'+taskArgs.outFile + '_private.json',
      JSON.stringify(key.privKey.rawPrivKey, null, 2),
      () => {},
    );

    const provider = new hre.ethers.providers.JsonRpcProvider();

    const BountyManager = await hre.ethers.getContractFactory('BountyManager');
    const contract = await BountyManager.attach(CONTRACT_ADDRESS);

    const wallet_raw = new hre.ethers.Wallet(taskArgs.privKey);
    
    const wallet = wallet_raw.connect(provider);

    let overrides = {
      // To convert Ether to Wei:
      value: ethers.utils.parseEther("1.0")     // ether in this case MUST be a string
    };

    const write_contract = contract.connect(wallet);

    tx = await write_contract.addBounty(hash_input, "dataset", key.pubKey.rawPubKey, data.out, overrides);
   
    console.log(tx)

    console.log(hash_input);
    console.log("Success!");



    balance = await provider.getBalance(wallet.address);
    console.log("Current Balance");
    console.log(ethers.utils.formatEther(balance));
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
