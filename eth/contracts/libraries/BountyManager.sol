pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "./LibVerifier.sol";
import "hardhat/console.sol";

contract BountyManager is Verifier {

  event SetPurpose(address sender, string purpose);

  mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) public bounties;
  mapping(uint256 => mapping(uint256 => uint256[3])) public public_keys;
  mapping(uint256 => uint256) public dataset_bounty_counts;
  mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) public dataset_mapping;

  uint256[3] public queryResult;

  constructor() public payable {
  }

  function query(uint256 dataset_hash) public {
    queryResult = public_keys[dataset_hash][0];
  }

  function addBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public payable {
    bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] += msg.value;
    uint256 bounty_count = dataset_bounty_counts[dataset_hash];
    dataset_bounty_counts[dataset_hash] = bounty_count + 1;
    dataset_mapping[dataset_hash][public_key[0]][public_key[1]] = bounty_count+1;
    public_keys[dataset_hash][bounty_count+1] = [public_key[0], public_key[1], mse_cap];
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
      public_keys[dataset_hash][dataset_mapping[dataset_hash][public_key_0][public_key_1]] = [0,0,0];
      dataset_mapping[dataset_hash][public_key_0][public_key_1] = 0;
      bounties[dataset_hash][public_key_0][public_key_1][mse_cap] = 0;
      to.transfer(topay);
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
