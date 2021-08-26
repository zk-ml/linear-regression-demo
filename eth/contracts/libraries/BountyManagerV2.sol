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
    uint256 bounty;
    address payable owner;
    string note;
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

  mapping(uint256 => bytes32[]) dataset_to_bounties;
  mapping(uint256 => mapping(bytes32 => uint256)) dataset_to_bounties_idx;
  
  uint256[] public datasets;
  mapping(uint256 => uint256) dataset_idx;
  mapping(uint256 => string) public dataset_descriptions;

  address deployer;

  constructor(uint mi, uint pi, uint ni) public payable {
    m = mi;
    p = pi;
    n = ni;
    deployer = msg.sender;
  }

  function changeDatasetDescription(uint256 dataset_hash, string memory description) public {
      require(msg.sender == deployer, "only the deployer can change dataset descriptions");
      dataset_descriptions[dataset_hash] = description;
  }

  function getDatasetDescription(uint256 dataset_hash) public view returns (string memory) {
      return dataset_descriptions[dataset_hash];
  }

  function add_bounty_to_datasets(uint256 dataset_hash, bytes32 h) private {
    if (dataset_to_bounties_idx[dataset_hash][h] == 0) {
        dataset_to_bounties[dataset_hash].push(h);
        dataset_to_bounties_idx[dataset_hash][h] = dataset_to_bounties[dataset_hash].length;
    }
  }

  function remove_bounty_from_datasets(uint256 dataset_hash, bytes32 h) private {
    uint256 idx = dataset_to_bounties_idx[dataset_hash][h];
    require(idx > 0, "dataset not found");
    uint256 len = dataset_to_bounties[dataset_hash].length;
    dataset_to_bounties[dataset_hash][idx - 1] = dataset_to_bounties[dataset_hash][len - 1];
    dataset_to_bounties[dataset_hash].pop();
    dataset_to_bounties_idx[dataset_hash][h] = 0;
  }

  function add_to_datasets(uint256 dataset_hash) private {
    if (dataset_idx[dataset_hash] == 0) {
        datasets.push(dataset_hash);
        dataset_idx[dataset_hash] = datasets.length;
    }
  }

  function remove_from_datasets(uint256 dataset_hash) private {
    uint256 idx = dataset_idx[dataset_hash];
    require(idx > 0, "dataset not found");
    datasets[idx - 1] = datasets[datasets.length - 1];
    datasets.pop();
    dataset_idx[dataset_hash] = 0;
  }

  function getDatasets() public view returns (uint256[] memory) {
    return datasets;
  }

  function queryDatasetBounties(uint256 dataset_hash) public view returns (bytes32[] memory) {
    return dataset_to_bounties[dataset_hash];
  }

  function queryBountyHash(bytes32 h) public view returns (Bounty memory) {
    return bounties[h];
  }

  function queryBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public view returns (Bounty memory) {
    return bounties[hashBounty(dataset_hash, public_key, mse_cap)];
  }

  function hashBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) private pure returns (bytes32) {
    return keccak256(abi.encodePacked(dataset_hash, public_key[0], public_key[1], mse_cap));
  }

  function addBounty(uint256 dataset_hash, string memory note, uint256[2] memory public_key, uint256 mse_cap) public payable {
    bytes32 h = hashBounty(dataset_hash, public_key, mse_cap);
    Bounty memory b = Bounty(dataset_hash, public_key[0], public_key[1], mse_cap, msg.value, msg.sender, note);
    require(bounties_status[h] == false, "bounty already exists");
    bounties[h] = b;
    bounties_status[h] = true;
    emit BountyDeposited(msg.value);
    add_to_datasets(dataset_hash);
    add_bounty_to_datasets(dataset_hash, h);
  }

  function removeBounty(uint256 dataset_hash, uint256[2] memory public_key, uint256 mse_cap) public {
    bytes32 h = hashBounty(dataset_hash, public_key, mse_cap);
    require(bounties_status[h] != false, "bounty does not exist");
    Bounty memory b = bounties[h];
    require(msg.sender == b.owner, "you are not the owner of the bounty");
    bounties_status[h] = false;
    uint toremove = b.bounty;
    b.owner.transfer(toremove);
    emit BountyRemoved(toremove);
    remove_bounty_from_datasets(dataset_hash, h);
    if (dataset_to_bounties[dataset_hash].length == 0) {
        remove_from_datasets(dataset_hash);
    }
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
    uint256[2] memory public_key;
    public_key[0] = input[index_offset + 2];
    public_key[1] = input[index_offset + 3];
    uint256 dataset_hash = input[1];
    uint256 mse_cap = input[0];
      
    bytes32 h = hashBounty(dataset_hash, public_key, mse_cap);
    require(bounties_status[h] != false, "bounty does not exist");
    Bounty memory bt = bounties[h];
    bounties_status[h] = false;
    uint topay = bt.bounty;
    to.transfer(topay);
    emit BountyCollected(topay);
    
    remove_bounty_from_datasets(dataset_hash, h);
    if (dataset_to_bounties[dataset_hash].length == 0) {
        remove_from_datasets(dataset_hash);
    }
  }

  // Function to receive Ether. msg.data must be empty
  receive() external payable {}

  // Fallback function is called when msg.data is not empty
  fallback() external payable {}

}
