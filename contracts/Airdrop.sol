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

    struct ClaimStage {
        bytes32 merkleRoot;
        uint256 claimableUntil;
    }

    IERC20 public immutable broToken;
    address public immutable withdrawTo;

    uint8 private currentStage = 0;
    mapping(uint8 => ClaimStage) private stages;
    mapping(address => mapping(uint8 => bool)) private claims;

    mapping(uint8 => uint256) private claimedBroPerStage;
    mapping(uint8 => Counters.Counter) private claimedAccountsPerStage;

    event MerkleRootRegistered(uint8 stage, bytes32 indexed merkleRoot);
    event AirdropClaimed(uint8 stage, address indexed account, uint256 amount);

    constructor(address token_, address _withdrawTo) {
        broToken = IERC20(token_);
        withdrawTo = _withdrawTo;
    }

    modifier onlyWhenNotClaimed(uint8 _stage) {
        require(_stage <= currentStage, "Specified stage does not exists.");
        require(!claims[_msgSender()][_stage], "Reward already claimed.");
        _;
    }

    function registerMerkleRoot(
        uint256 _totalAirdropAmount,
        bytes32 _merkleRoot,
        uint256 _claimableUntil
    ) external onlyOwner {
        // solhint-disable-next-line not-rely-on-time
        require(_claimableUntil > block.timestamp, "Invalid claim period");

        broToken.safeTransferFrom(
            _msgSender(),
            address(this),
            _totalAirdropAmount
        );

        currentStage += 1;
        stages[currentStage] = ClaimStage(_merkleRoot, _claimableUntil);

        emit MerkleRootRegistered(currentStage, _merkleRoot);
    }

    function claim(
        uint8 _stage,
        bytes32[] calldata _merkleProof,
        uint256 _claimAmount
    ) external onlyWhenNotClaimed(_stage) {
        require(
            // solhint-disable-next-line not-rely-on-time
            block.timestamp <= stages[_stage].claimableUntil,
            "Claimable period is over."
        );

        bytes32 leaf = keccak256(abi.encodePacked(_msgSender(), _claimAmount));
        require(
            MerkleProof.verify(_merkleProof, stages[_stage].merkleRoot, leaf),
            "Invalid Merkle Proof."
        );

        claims[_msgSender()][_stage] = true;
        claimedBroPerStage[_stage] += _claimAmount;
        claimedAccountsPerStage[_stage].increment();
        broToken.safeTransfer(_msgSender(), _claimAmount);

        emit AirdropClaimed(_stage, _msgSender(), _claimAmount);
    }

    function withdrawRemainings() external onlyOwner {
        broToken.safeTransfer(withdrawTo, broToken.balanceOf(address(this)));
    }

    function latestStage() public view returns (uint8) {
        return currentStage;
    }

    function claimStage(uint8 _stage) public view returns (ClaimStage memory) {
        return stages[_stage];
    }

    function canClaimStage(uint8 _stage) public view returns (bool) {
        // solhint-disable-next-line not-rely-on-time
        return block.timestamp <= stages[_stage].claimableUntil;
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
