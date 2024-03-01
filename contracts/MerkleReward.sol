// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import "hardhat/console.sol";

struct UserReward {
    address to;
    uint256 amount;
}

// Manages role memberships for all roles including the ADMIN_ROLE.
bytes32 constant ADMIN_ROLE = 0x0;

// Manages merkle root updates
// keccak256("MERKLE_ROOT_UPDATER_ROLE")
bytes32 constant MERKLE_ROOT_UPDATER_ROLE = 0x1e0e935a4b597d14b19412d1d1383dc2a6d2dce1de544677c1ef3f24ff294f05;

// Manages smart contract pausability.
// keccak256("PAUSE_ROLE")
bytes32 constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;

contract MerkleReward is Context, Pausable, AccessControlEnumerable {
    using SafeERC20 for IERC20;

    error AlreadyClaimed();
    error IncorrectClaimProof();

    event RewardClaimed(address indexed to, address initiator, uint256 amount);
    event MerkleRootChanged(bytes32 oldRool, bytes32 newRoot);

    bytes32 public root;
    IERC20 public immutable rewardToken;
    mapping(bytes32 => bool) private claimed;

    constructor(
        IERC20 rewardTokenParam,
        address admin,
        address merkleRootUpdater,
        address pauser
    ) {
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(MERKLE_ROOT_UPDATER_ROLE, merkleRootUpdater);
        _grantRole(PAUSE_ROLE, pauser);
        rewardToken = rewardTokenParam;
    }

    function claim(
        bytes32[] calldata proof,
        address to,
        uint256 amount
    ) external whenNotPaused {
        bytes32 claimId = keccak256(abi.encodePacked(root, to));
        if (claimed[claimId]) revert AlreadyClaimed();

        if (
            MerkleProof.verifyCalldata(
                proof,
                root,
                keccak256(bytes.concat(keccak256(abi.encode(to, amount))))
            )
        ) {
            rewardToken.safeTransfer(to, amount);
            claimed[claimId] = true;
            emit RewardClaimed(to, _msgSender(), amount);
        } else {
            revert IncorrectClaimProof();
        }
    }

    function canClaim(address to) external view returns (bool) {
        return claimed[keccak256(abi.encodePacked(root, to))];
    }

    function registerMerkleRoot(bytes32 rootParam)
        external
        onlyRole(MERKLE_ROOT_UPDATER_ROLE)
    {
        emit MerkleRootChanged(root, rootParam);
        root = rootParam;
    }

    function recoverRewardTokens(address to) external onlyRole(ADMIN_ROLE) {
        rewardToken.safeTransfer(to, rewardToken.balanceOf(address(this)));
    }

    function pause() external onlyRole(PAUSE_ROLE) {
        super._pause();
    }

    function unpause() external onlyRole(PAUSE_ROLE) {
        super._unpause();
    }
}
