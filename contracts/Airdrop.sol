//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Airdrop is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable broToken;

    uint8 private stage = 0;
    mapping(uint8 => bytes32) private merkleRoots;
    mapping(address => mapping(uint8 => bool)) private claims;

    event MerkleRootRegistered(uint8 stage, bytes32 indexed merkleRoot);
    event AirdropClaimed(uint8 stage, address indexed account, uint256 amount);

    constructor(address token_) {
        broToken = IERC20(token_);
    }

    modifier onlyWhenNotClaimed(uint8 _stage) {
        require(_stage <= stage, "Specified stage does not exists.");
        require(!claims[msg.sender][_stage], "Reward already claimed.");
        _;
    }

    function registerMerkleRoot(
        uint256 _totalAirdropAmount,
        bytes32 _merkleRoot
    ) external onlyOwner {
        require(
            broToken.balanceOf(address(this)) >= _totalAirdropAmount,
            "Not enough tokens for the airdrop."
        );

        stage += 1;
        merkleRoots[stage] = _merkleRoot;

        emit MerkleRootRegistered(stage, _merkleRoot);
    }

    function claim(
        uint8 _stage,
        bytes32[] calldata _merkleProof,
        uint256 _claimAmount
    ) external onlyWhenNotClaimed(_stage) {
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, _claimAmount));
        require(
            MerkleProof.verify(_merkleProof, merkleRoots[_stage], leaf),
            "Invalid Merkle Proof."
        );

        claims[msg.sender][_stage] = true;
        broToken.safeTransfer(msg.sender, _claimAmount);

        emit AirdropClaimed(_stage, msg.sender, _claimAmount);
    }

    function latestStage() public view returns (uint8) {
        return stage;
    }

    function merkleRoot(uint8 _stage) public view returns (bytes32) {
        return merkleRoots[_stage];
    }

    function isClaimed(address _account, uint8 _stage)
        public
        view
        returns (bool)
    {
        return claims[_account][_stage];
    }
}
