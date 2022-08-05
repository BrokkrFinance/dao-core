//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Airdrop is Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    IERC20 public immutable broToken;

    uint8 private stage = 0;
    mapping(uint8 => bytes32) private merkleRoots;
    mapping(address => mapping(uint8 => bool)) private claims;

    mapping(uint8 => uint256) private claimedBroPerStage;
    mapping(uint8 => Counters.Counter) private claimedAccountsPerStage;

    event MerkleRootRegistered(uint8 stage, bytes32 indexed merkleRoot);
    event AirdropClaimed(uint8 stage, address indexed account, uint256 amount);

    constructor(address token_) {
        broToken = IERC20(token_);
    }

    modifier onlyWhenNotClaimed(uint8 _stage) {
        require(_stage <= stage, "Specified stage does not exists.");
        require(!claims[_msgSender()][_stage], "Reward already claimed.");
        _;
    }

    function registerMerkleRoot(
        uint256 _totalAirdropAmount,
        bytes32 _merkleRoot
    ) external onlyOwner {
        broToken.safeTransferFrom(
            _msgSender(),
            address(this),
            _totalAirdropAmount
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
        bytes32 leaf = keccak256(abi.encodePacked(_msgSender(), _claimAmount));
        require(
            MerkleProof.verify(_merkleProof, merkleRoots[_stage], leaf),
            "Invalid Merkle Proof."
        );

        claims[_msgSender()][_stage] = true;
        claimedBroPerStage[_stage] += _claimAmount;
        claimedAccountsPerStage[_stage].increment();
        broToken.safeTransfer(_msgSender(), _claimAmount);

        emit AirdropClaimed(_stage, _msgSender(), _claimAmount);
    }

    function latestStage() public view returns (uint8) {
        return stage;
    }

    function merkleRoot(uint8 _stage) public view returns (bytes32) {
        return merkleRoots[_stage];
    }

    function getClaimedBroPerStage(uint8 _stage) public view returns (uint256) {
        return claimedBroPerStage[_stage];
    }

    function getClaimedAccountsCountPerStage(uint8 _stage)
        public
        view
        returns (uint256)
    {
        return claimedAccountsPerStage[_stage].current();
    }

    function isClaimed(address _account, uint8 _stage)
        public
        view
        returns (bool)
    {
        return claims[_account][_stage];
    }
}
