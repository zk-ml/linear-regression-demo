pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "./LibVerifier.sol";

contract BountyManager is Verifier {

  event SetPurpose(address sender, string purpose);

  mapping(uint256 => mapping(uint256 => uint256)) public bounties;

  uint256 public queryResult;

  constructor() public payable {
  }

  function query(uint256 dataset_hash, uint256 mse_cap) public {
    queryResult = bounties[dataset_hash][mse_cap];
  }

  function addBounty(uint256 dataset_hash, uint256 mse_cap) public payable {
    bounties[dataset_hash][mse_cap] += msg.value;
  }

  function collectBounty(
          address payable to,
          uint[2] memory a,
          uint[2][2] memory b,
          uint[2] memory c,
          uint[54] memory input
      ) public {
      require(verifyProof(a, b, c, input), "Invalid Proof");
      uint256 topay = bounties[input[1]][input[0]];
      bounties[input[1]][input[0]] = 0;
      to.transfer(topay);
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
