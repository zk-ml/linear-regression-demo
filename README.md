## zkml core

_Truly private machine learning._

This is a demo of the zkml protocol, which implements a zk-SNARK circuit where the proof verifies that a private model has a certain accuracy under a public dataset, as well as the public encrypted model is exactly the private model encrypted using the shared key. 

### Running

* download `powersOfTau28_hez_final_18.ptau` from circom and move to `circuits`
* `mkdir artifacts` to store artifacts
* `cd circuits && yarn prod` to build the circuits
* `cd eth && yarn compile && yarn deploy-{NETWORK}` to deploy the contracts
* set up Infura IPFS with `keys/ipfs.json` containing `{"id": ..., "secret": ...}`
* `export PRIVATE_KEY=... && export URL=...` to export private key and RPC URL
* for the jupyter demo, run `jupyter kernelspec list` to find `kernel.json` and add an `"env": {"PRIVATE_KEY": ..., "URL": ...}` entry
* `./zkml` to interact with cli (xDai)

### Check it out on-chain

https://blockscout.com/xdai/mainnet/address/0x5B54f06991871cd7EAE76a3D270D9EFFBdC01207/contracts

### Protocol Overview

![fig](protocol_overview.jpg)

### Special Thanks

* ETH Summer
* zk-dungeon
