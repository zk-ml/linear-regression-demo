## zkml core

Truly private machine learning.

![fig](protocol_overview.jpg)

### Running

* `cd circuits && yarn prod` to build the circuits
* `cd eth && yarn compile && yarn deploy-{NETWORK}` to deploy the contracts
* `export PRIVATE_KEY=... && export URL=...` to export private key and RPC URL
* for jupyter, run `jupyter kernelspec list` to find `kernel.json` and add an `"env": {"PRIVATE_KEY":"...", "URL":"..."}` entry
* `./zkml` to interact with cli

### Check it out on-chain

https://blockscout.com/xdai/mainnet/address/0x5B54f06991871cd7EAE76a3D270D9EFFBdC01207/contracts

### Special Thanks

* ETH Summer
* zk-dungeon
