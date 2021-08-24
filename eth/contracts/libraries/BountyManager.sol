pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;
//SPDX-License-Identifier: MIT

import "./LibVerifier.sol";
import "hardhat/console.sol";

contract BountyManager is Verifier {

  struct KeysPerf {
    uint256 k1;
    uint256 k2;
    uint256 mse;
  }

  event SetPurpose(address sender, string purpose);

  mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) public bounties;

  uint256[3] public queryResult;

  mapping(uint256 => KeysPerf[]) public public_keys;
  // 1-based indexing into the array. 0 represents non-existence.
  mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) indexOf;

  function add(uint256 dataset_hash, uint256[3] memory value) public {
      if (indexOf[value[0]][value[1]][value[2]] == 0) {
          public_keys[dataset_hash].push(KeysPerf(value[0], value[1], value[2]));
          indexOf[value[0]][value[1]][value[2]] = public_keys[dataset_hash].length;
      }
  }

  function remove(uint256 dataset_hash, uint256[3] memory value) public {
      uint256 index = indexOf[value[0]][value[1]][value[2]];

      require(index > 0);

      // move the last item into the index being vacated
      KeysPerf memory lastValue = public_keys[dataset_hash][public_keys[dataset_hash].length - 1];
      public_keys[dataset_hash][index - 1] = lastValue;  // adjust for 1-based indexing
      indexOf[lastValue.k1][lastValue.k2][lastValue.mse] = index;

      public_keys[dataset_hash].length -= 1;
      indexOf[value[0]][value[1]][value[2]] = 0;
  }

  event AvailableBounties(uint256[] perf_constraints, uint256[][2] public_keys);

  constructor() public payable {
  }

  function query(uint256 dataset_hash) public {
    queryResult = public_keys[dataset_hash][0];
  }

  function addBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public payable {
    bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] += msg.value;
    
    add([public_key[0], public_key[1], mse_cap], dataset_hash);
  }

  function collectBounty(
          address payable to,
          uint[2] memory a,
          uint[2][2] memory b,
          uint[2] memory c,
          uint[54] memory input
      ) public {
      require(verifyProof(a, b, c, input), "Invalid Proof");
      uint256 public_key_0 = input[33];
      uint256 public_key_1 = input[34];
      uint256 dataset_hash = input[1];
      uint256 mse_cap = input[0];
      uint256 topay = bounties[dataset_hash][public_key_0][public_key_1][mse_cap];
      remove([public_key_0, public_key_1, mse_cap], dataset_hash);
      bounties[dataset_hash][public_key_0][public_key_1][mse_cap] = 0;
      to.transfer(topay);
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
