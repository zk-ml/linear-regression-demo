pragma solidity >=0.6.11 <0.9.0;
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

  mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(address => uint256))))) perAddressBounty;
  mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => address[])))) perAddressBounty_keys;

  event BountyCollected(uint256 amount);
  event BountyRemoved(uint256 amount);
  event BountyDeposited(uint256 amount);

  mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) public bounties;

  uint m;
  uint p;
  uint n;

  mapping(uint256 => KeysPerf[]) public public_keys;
  mapping(uint256 => uint256) length;
  mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) bountyIndexOf;

  mapping(uint256 => string) public dataset_alias;

  uint256[] list_bounties;
  uint256 length_list_bounties;
  mapping(uint256 => uint256) indexOf;

  function _add_to_dataset_list(uint256 value) public {
        if (indexOf[value] == 0) {
            list_bounties.push(value);
            length_list_bounties = length_list_bounties + 1;
            indexOf[value] = length_list_bounties;
        }
  }

  function _remove_from_dataset_list(uint256 value) public {
      uint256 index = indexOf[value];

      //if (index == 0) {
      //  return;
      //}
      require(index > 0, "index = 0, remove dataset");

      // move the last item into the index being vacated
      uint256 lastValue = list_bounties[length_list_bounties - 1];
      list_bounties[index - 1] = lastValue;  // adjust for 1-based indexing
      indexOf[lastValue] = index;

      length_list_bounties -= 1;
      indexOf[value] = 0;
  }

  function _add_to_bounty_list(uint256 dataset_hash, uint256[3] memory value) public {
      if (bountyIndexOf[value[0]][value[1]][value[2]] == 0) {
          public_keys[dataset_hash].push(KeysPerf(value[0], value[1], value[2]));
          length[dataset_hash] = length[dataset_hash] + 1;
          bountyIndexOf[value[0]][value[1]][value[2]] = length[dataset_hash];
      }
  }

  function _remove_from_bounty_list(uint256 dataset_hash, uint256[3] memory value) public {
      uint256 index = bountyIndexOf[value[0]][value[1]][value[2]];

      //if (index == 0) {
      //  return;
      //}
      require(index > 0, "index = 0, remove bounty");

      // move the last item into the index being vacated
      KeysPerf storage lastValue = public_keys[dataset_hash][length[dataset_hash] - 1];
      public_keys[dataset_hash][index - 1] = lastValue;  // adjust for 1-based indexing
      bountyIndexOf[lastValue.k1][lastValue.k2][lastValue.mse] = index;

      length[dataset_hash] = length[dataset_hash] - 1;
      bountyIndexOf[value[0]][value[1]][value[2]] = 0;
  }

  constructor(uint mi, uint pi, uint ni) public payable {
    m = mi;
    p = pi;
    n = ni;
  }

  function query_bounty_contribution(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap, address addr) public view returns (uint256) {
    return perAddressBounty[dataset_hash][public_key[0]][public_key[1]][mse_cap][addr];
  }

  function query_bounty_contributors(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public view returns (address[] memory) {
    return perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap];
  }

  function query_num_bounties(uint256 dataset_hash) public view returns (uint256) {
    return length[dataset_hash];
  }

  function query_bounties(uint256 dataset_hash) public view returns (KeysPerf[] memory) {
    return public_keys[dataset_hash];
  }

  function query_num_datasets() public view returns (uint256) {
    return length_list_bounties;
  }

  function query_datasets() public view returns (uint256[] memory) {
    return list_bounties;
  }

  function get_alias(uint256 dataset_hash) public view returns (string memory) {
    return dataset_alias[dataset_hash];
  }

  function addBounty(uint256 dataset_hash, string memory alias_dataset, uint256[2] memory public_key, uint256 mse_cap) public payable {
    if (length[dataset_hash] == 0) {
      _add_to_dataset_list(dataset_hash);
    }
    if (bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] == 0) {
      _add_to_bounty_list(dataset_hash, [public_key[0], public_key[1], mse_cap]);
    }
    perAddressBounty[dataset_hash][public_key[0]][public_key[1]][mse_cap][msg.sender] = msg.value;
    bool exists = false;
    uint256 len = perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap].length;
    for (uint256 i = 0; i < len; i++) {
      if (perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap][i] == msg.sender) {
        exists = true;
      }
    }
    if (!exists) {
      perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap].push(msg.sender);
    }
    dataset_alias[dataset_hash] = alias_dataset;
    bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] += msg.value;
    emit BountyDeposited(msg.value);
  }

  function removeBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public {
    uint256 toremove = perAddressBounty[dataset_hash][public_key[0]][public_key[1]][mse_cap][msg.sender];
    bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] -= toremove;
    perAddressBounty[dataset_hash][public_key[0]][public_key[1]][mse_cap][msg.sender] = 0;
    uint256 len = perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap].length;
    for (uint256 i = 0; i < len; i++) {
      if (perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap][i] == msg.sender) {
        perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap][i] = perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap][len-1];
        perAddressBounty_keys[dataset_hash][public_key[0]][public_key[1]][mse_cap].pop();
      }
    }
    if (bounties[dataset_hash][public_key[0]][public_key[1]][mse_cap] == 0) {
      _remove_from_bounty_list(dataset_hash, [public_key_0, public_key_1, mse_cap]);
    }
    if (length[dataset_hash] == 0) {
      _remove_from_dataset_list(dataset_hash);
    }

    address refund_account = msg.sender;
    refund_account.transfer(toremove);
    emit BountyRemoved(toremove);
    return toremove;
  }

  function collectBounty(
          address payable to,
          uint[2] memory a,
          uint[2][2] memory b,
          uint[2] memory c,
          uint[131] memory input
      ) public returns (uint256) {
      require(verifyProof(a, b, c, input), "Invalid Proof");
      
      uint index_offset = m * p + n * p * 2 + n * 2;
      uint256 public_key_0 = input[index_offset + 2];
      uint256 public_key_1 = input[index_offset + 3];
      uint256 dataset_hash = input[1];
      uint256 mse_cap = input[0];
      uint256 topay = bounties[dataset_hash][public_key_0][public_key_1][mse_cap];
      _remove_from_bounty_list(dataset_hash, [public_key_0, public_key_1, mse_cap]);
      if (length[dataset_hash] == 0) {
        _remove_from_dataset_list(dataset_hash);
      }
      bounties[dataset_hash][public_key_0][public_key_1][mse_cap] = 0;

      address[] storage addrs = perAddressBounty_keys[dataset_hash][public_key_0][public_key_1][mse_cap];
      uint256 len = addrs.length;
      for (uint256 i = 0; i < len; i++) {
        perAddressBounty[dataset_hash][public_key_0][public_key_1][mse_cap][msg.sender] = 0;
        perAddressBounty_keys[dataset_hash][public_key_0][public_key_1][mse_cap].pop();
      }
      to.transfer(topay);
      emit BountyCollected(topay);
      return topay;
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
