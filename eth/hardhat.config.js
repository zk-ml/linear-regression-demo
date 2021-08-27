require("dotenv").config();
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-web3");
require("maci-domainobjs");
require("maci-crypto");


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

task("list_bounties", "List bounties given dataset")
  .addParam("hash", "Dataset hash", "14797455496207951391356508759149962584765968173479481191220882411966396840571")
  .setAction(async (taskArgs) => {
    const fs = require("fs");
    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);
    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);
    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const write_contract = contract.connect(wallet);

    console.log("Available bounties on dataset: " + taskArgs.hash);
    hashes = await write_contract.queryDatasetBounties(taskArgs.hash);
    const bounties = await Promise.all(hashes.map(async function (hash) { 
      x = await write_contract.queryBountyHash(hash);
      return {"PubKey1": x[1].toString(),
              "PubKey2": x[2].toString(),
              "MSEcap":  x[3].toString(),
              "Bounty": ethers.utils.formatEther(x[4]).toString(),
              "Issuer": x[5].toString(),
              "IPFS": x[6].toString(),
             }; 
    }));
    console.log(bounties);  
  });

task("list_datasets", "List of datasets with alias")
  .setAction(async (taskArgs) => {
    const fs = require("fs");
    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);
    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);

    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const write_contract = contract.connect(wallet);
    tx = await write_contract.getDatasets();
    const hashes = tx.map(function (x) { return x.toString() });
    
    console.log("Available datasets:");
    console.log(hashes);
  });

task("remove_bounty", "Remove bounty without claiming") 
  .addParam("hash", "Dataset hash", "14797455496207951391356508759149962584765968173479481191220882411966396840571")
  .addParam("publickey", "bounty issuer's publilckey", "./keys/out_public.json")
  .addParam("mse", "mse cap, quantized", "12888")
  .setAction(async (taskArgs) => {
    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);
    const fs = require("fs");
    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);

    const pubKey = JSON.parse(fs.readFileSync(taskArgs.publickey));
    pubKey[0] = BigInt(pubKey[0]);
    pubKey[1] = BigInt(pubKey[1]);

    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const write_contract = contract.connect(wallet);
    const mse_cap = taskArgs.mse;

    balance = await provider.getBalance(wallet.address);
    console.log("Paying " + wallet.address);
    console.log(ethers.utils.formatEther(balance));

    const bounty = await write_contract.queryBounty(taskArgs.hash, pubKey, mse_cap);
    const alias = bounty.ipfs;

    console.log("Removing bounty on dataset at: " + alias);
    tx = await write_contract.removeBounty(taskArgs.hash, pubKey, mse_cap);
  });

task("claim_bounty", "Claim bounty")
  .addParam("payment", "payment address", "0xd3162F2B88d05C882a1B26031E144753337ACDBF")
  .addParam("publickey", "bounty issuer's publilckey", "./keys/out_public.json")
  .addParam("model", "model path", "./model")
  .addParam("dataset", "dataset path", "./dataset")
  .addParam("settings", "settings", "settings.json")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");
    const snarkjs = require("snarkjs");

    execSync("python3 scripts/quantize.py --mode model --settings "+ taskArgs.settings + " --model " + taskArgs.model + " --dataset " + taskArgs.dataset, {
      stdio: "inherit",
    });

    const { Keypair } = require('maci-domainobjs');
    const mimc7 = require('./node_modules/circomlib/src/mimc7.js');
    //console.log(Keypair);

    const key = new Keypair();
    const pubKey = JSON.parse(fs.readFileSync(taskArgs.publickey));
    //console.log(pubKey);
    pubKey[0] = BigInt(pubKey[0]);
    pubKey[1] = BigInt(pubKey[1]);

    const key2 = new Keypair();
    //console.log('---------');
    key2.pubKey.rawPubKey = pubKey;
    //console.log(pubKey);
    //console.log(key2.pubKey.rawPubKey);

    const sharedKey = Keypair.genEcdhSharedKey(key.privKey, key2.pubKey);

    const rawdata = fs.readFileSync('./artifacts/quantization/inputs_ml.json');
    const data = JSON.parse(rawdata);
    //console.log(data);

    function tobigint(value) {
      return BigInt(value);
    }

    var to_hash = [];
    var m = 20;
    var p = 4;
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
    //console.log(b_q_enc);
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
        info: (x) => { console.log('INFO: ' + x) },
        warn: (x) => { console.log('WARN: ' + x) },
        error: (x) => { console.log('ERROR: ' + x) },
    };

    const verification_key = await snarkjs.zKey.exportVerificationKey(final_zkey);
    console.log('Circuit Outputs:');
    await snarkjs.wtns.calculate(input, wasm, wtns, logger);
    const start = Date.now();
    const { proof, publicSignals } = await snarkjs.groth16.prove(final_zkey, wtns, logger);
    console.log("Proof took " + (Date.now() - start) / 1000 + " s");

    const verified = await snarkjs.groth16.verify(verification_key, publicSignals, proof, logger);
    if (!verified) throw new Error("Could not verify the proof");

    arg0 = [proof.pi_a[0], proof.pi_a[1]];
    arg1 = [[proof.pi_b[0][1], proof.pi_b[0][0]], [proof.pi_b[1][1], proof.pi_b[1][0]]]
    arg2 = [proof.pi_c[0], proof.pi_c[1]];
    arg3 = publicSignals;

    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);
    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);

    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const write_contract = contract.connect(wallet);

    //console.log([arg0, arg1, arg2]);
    console.log("Paying " + taskArgs.payment);
    console.log("With balance");
    balance = await provider.getBalance(taskArgs.payment);
    console.log(ethers.utils.formatEther(balance));
    
    //arg3[0] = "133";

    //const index_offset = m * p + n * p * 2 + n * 2;
    //console.log(key2.pubKey);
    //console.log(arg3[index_offset+2]);
    //console.log(arg3[index_offset+3]);
    //console.log(arg3[index_offset+2]);
    //console.log(arg0, arg1, arg2, arg3);

    tx = await write_contract.collectBounty(taskArgs.payment, arg0, arg1, arg2, arg3);

    await write_contract.on("BountyCollected", (x) => {
      console.log("Collected Bounty: " + (x.toString()));
    });
    //console.log(tx);

    console.log("Your Public Key: ");
    console.log(key.pubKey.rawPubKey);
    console.log("Your Private Key: ");
    console.log(key.privKey.rawPrivKey);
    //console.log("Success!");

    balance = await provider.getBalance(taskArgs.payment);
    console.log("Current Balance");
    console.log(ethers.utils.formatEther(balance));
  });

task("download_dataset", "download dataset")
  .addParam("hash", "Dataset hash", "14797455496207951391356508759149962584765968173479481191220882411966396840571")
  .addParam("publickey", "bounty issuer's publilckey", "./keys/out_public.json")
  .addParam("mse", "mse cap, quantized", "12888")
  .addParam("path", "save path", "./ipfs_dataset")
  .setAction(async (taskArgs) => {
    console.log("Downloading from IPFS to " + taskArgs.path + " ...");

    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);
    const fs = require("fs");
    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);

    const pubKey = JSON.parse(fs.readFileSync(taskArgs.publickey));
    pubKey[0] = BigInt(pubKey[0]);
    pubKey[1] = BigInt(pubKey[1]);

    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const write_contract = contract.connect(wallet);
    const mse_cap = taskArgs.mse;

    const bounty = await write_contract.queryBounty(taskArgs.hash, pubKey, mse_cap);
    const cid = bounty.ipfs;

    const infura = JSON.parse(fs.readFileSync('./keys/ipfs.json'));
    const projectId = infura.id;
    const projectSecret = infura.secret;

    const axios = require('axios')
    
    var response = await axios.post("https://ipfs.infura.io:5001/api/v0/cat?arg=" + cid + "/X.npy", {}, {
      auth: {
        username: projectId,
        password: projectSecret
      }
    });
    
    fs.writeFileSync(
      taskArgs.path + "/X.npy",
      response.data,
      {encoding: 'base64'});
    
    response = await axios.post("https://ipfs.infura.io:5001/api/v0/cat?arg=" + cid + "/Y.npy", {}, {
      auth: {
        username: projectId,
        password: projectSecret
      }
    });

    fs.writeFileSync(
      taskArgs.path + "/Y.npy",
      response.data,
      {encoding: 'base64'});

  });

task("add_bounty", "Deposit bounty") 
  .addParam("amount", "amount to add to bounty", "0.001")
  .addParam("keyfile", "file prefix to export private and public key", "out")
  .addParam("dataset", "dataset path", "./dataset")
  .addParam("settings", "settings", "settings.json")
  .setAction(async (taskArgs) => {

    const { execSync } = require("child_process");
    const fs = require("fs");

    execSync("python3 scripts/quantize.py --mode dataset --settings "+ taskArgs.settings + " --dataset " + taskArgs.dataset, {
      stdio: "inherit",
    });

    const { Keypair } = require('maci-domainobjs');
    const mimc7 = require('./node_modules/circomlib/src/mimc7.js');
    //console.log(mimc7)

    const key = new Keypair();

    const rawdata = fs.readFileSync('./artifacts/quantization/inputs_dataset.json');
    const data = JSON.parse(rawdata);
    //console.log(data);

    function tobigint(value) {
      return BigInt(value);
    }

    var to_hash = [];
    var m = 20;
    var p = 4;
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
      './keys/'+taskArgs.keyfile + '_public.json',
      JSON.stringify(key.pubKey.rawPubKey, null, 2),
      () => {},
    );

    fs.writeFileSync(
      './keys/'+taskArgs.keyfile + '_private.json',
      JSON.stringify(key.privKey.rawPrivKey, null, 2),
      () => {},
    );

    const provider = new hre.ethers.providers.JsonRpcProvider(process.env.URL);

    const BountyManagerV2 = await hre.ethers.getContractFactory('BountyManagerV2');
    const CONTRACT_ADDRESS = fs.readFileSync('./artifacts/.env_contract', 'utf-8');
    const contract = await BountyManagerV2.attach(CONTRACT_ADDRESS);

    const wallet_raw = new hre.ethers.Wallet(process.env.PRIVATE_KEY);
    const wallet = wallet_raw.connect(provider);

    const ipfs = require('ipfs-http-client')

    const infura = JSON.parse(fs.readFileSync('./keys/ipfs.json'));
    const projectId = infura.id;
    const projectSecret = infura.secret;

    const auth =
      'Basic ' + Buffer.from(projectId + ':' + projectSecret).toString('base64')

    const client = ipfs.create({
      host: 'ipfs.infura.io',
      port: 5001,
      protocol: 'https',
      headers: {
        authorization: auth
      }
    })

    X = fs.readFileSync(taskArgs.dataset + "/X.npy", {encoding: 'base64'});
    Y = fs.readFileSync(taskArgs.dataset + "/Y.npy", {encoding: 'base64'});

    const files = [
      {
        path: "dataset/X.npy",
        content: X.toString()
      },
      {
        path: "dataset/Y.npy",
        content: Y.toString()
      }
    ]

    res = [];
    for await (const result of client.addAll(files)) {
      res.push(result);
    }

    //console.log(res);
    
    const cid = res[2].cid.toString();

    console.log("IPFS available at https://ipfs.io/ipfs/" + cid);

    let overrides = {
      // To convert Ether to Wei:
      value: ethers.utils.parseEther(taskArgs.amount)     // ether in this case MUST be a string
    };

    const write_contract = contract.connect(wallet);

    tx = await write_contract.addBounty(hash_input, cid, key.pubKey.rawPubKey, data.out, overrides);
   
    //console.log(tx)
    //console.log(hash_input);
    //console.log("Success!");

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
  solidity: {
    version: "0.6.11",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
    },
    xdai: {
      url: process.env.URL || "",
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
