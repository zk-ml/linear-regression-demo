// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
require("@nomiclabs/hardhat-web3");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const BountyManager = await hre.ethers.getContractFactory("BountyManager");
  const bm = await BountyManager.deploy(1, 10, 1);

  await bm.deployed();

  // If you don't specify a //url//, Ethers connects to the default 
  // (i.e. ``http:/\/localhost:8545``)
  const provider = new hre.ethers.providers.JsonRpcProvider();

  tx = {
    to: bm.address,
    value: hre.ethers.utils.parseEther("1.0")
  }

  wallet = await hre.ethers.getSigner();

  // Querying the network
  console.log(await wallet.getBalance());

  res = await wallet.sendTransaction(tx);

  console.log(res)

  console.log("Greeter deployed to:", bm.address);

  console.log(await provider.getBalance(bm.address));
  console.log(await provider.getTransactionCount(bm.address));
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
