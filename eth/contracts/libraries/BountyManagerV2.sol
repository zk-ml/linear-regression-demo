pragma solidity >=0.6.11 <0.9.0;
pragma experimental ABIEncoderV2;
//SPDX-License-Identifier: MIT

import "./LibVerifier.sol";
import "hardhat/console.sol";

contract BountyManagerV2 is Verifier {

  struct Bounty {
    uint256 dataset_hash;
    uint256 k1;
    uint256 k2;
    uint256 mse;
    uint256 amount;
    address owner; 
  }

  event BountyCollected(uint256 amount);
  event BountyRemoved(uint256 amount);
  event BountyDeposited(uint256 amount);

  uint m;
  uint p;
  uint n;

  mapping(bytes32 => Bounty) public bounties;
  mapping(bytes32 => bool) public bounties_status;
  bytes32[] bounty_hashes;

  uint256[] public datasets;
  mapping(uint256 => string) dataset_aliases;

  constructor(uint mi, uint pi, uint ni) public payable {
    m = mi;
    p = pi;
    n = ni;
  }

  function addBounty(uint256 dataset_hash, string memory alias_dataset, uint256[2] memory public_key, uint256 mse_cap) public payable {
    bytes32 h = keccak256(abi.encodePacked(dataset_hash, public_key[0], public_key[1], mse_cap));
    Bounty memory b = Bounty(dataset_hash, public_key[0], public_key[1], mse_cap, msg.value, msg.sender);
    bounties[h] = b;
    emit BountyDeposited(msg.value);
  }

  function removeBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public {
    uint toremove = 0;
    emit BountyRemoved(toremove);
  }

  function collectBounty(
          address payable to,
          uint[2] memory a,
          uint[2][2] memory b,
          uint[2] memory c,
          uint[131] memory input
      ) public {
      require(verifyProof(a, b, c, input), "Invalid Proof");
      
      uint index_offset = m * p + n * p * 2 + n * 2;
      uint256 public_key_0 = input[index_offset + 2];
      uint256 public_key_1 = input[index_offset + 3];
      uint256 dataset_hash = input[1];
      uint256 mse_cap = input[0];
      
      uint256 topay = 0;
      
      emit BountyCollected(topay);
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
