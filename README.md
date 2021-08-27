## zkml core

Truly private machine learning.

![fig](protocol_overview.jpg)

### Running

* download `powersOfTau28_hez_final_18.ptau` from circom and move to `circuits`
* `cd circuits && yarn prod` to build the circuits
* `cd eth && yarn compile && yarn deploy-{NETWORK}` to deploy the contracts
* set up Infura IPFS with `keys/ipfs.json` containing `{"id": ..., "secret": ...}`
* `export PRIVATE_KEY=... && export URL=...` to export private key and RPC URL
* for the jupyter demo, run `jupyter kernelspec list` to find `kernel.json` and add an `"env": {"PRIVATE_KEY": ..., "URL": ...}` entry
* `./zkml` to interact with cli (xDai)

### Check it out on-chain

https://blockscout.com/xdai/mainnet/address/0x5B54f06991871cd7EAE76a3D270D9EFFBdC01207/contracts

### Special Thanks

* ETH Summer
* zk-dungeon
