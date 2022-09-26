//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";
import { IStakingV1 } from "./interfaces/IStakingV1.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ProtocolMigrator is Ownable {
    using SafeERC20 for IERC20;

    struct UserMigration {
        address account;
        uint256 broInWalletBalance;
        uint256 bBroInWalletBalance;
        uint256 stakedBro;
    }

    IERC20 public broToken;
    IERC20Mintable public bBroToken;
    IStakingV1 public staking;

    uint256 public unstakingPeriod;

    constructor(
        address broToken_,
        address bBroToken_,
        address staking_,
        uint256 unstakingPeriod_
    ) {
        broToken = IERC20(broToken_);
        bBroToken = IERC20Mintable(bBroToken_);
        staking = IStakingV1(staking_);
        unstakingPeriod = unstakingPeriod_;
    }

    function migrate(UserMigration[] calldata _userMigrations)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _userMigrations.length; i++) {
            if (_userMigrations[i].broInWalletBalance != 0) {
                broToken.safeTransfer(
                    _userMigrations[i].account,
                    _userMigrations[i].broInWalletBalance
                );
            }

            if (_userMigrations[i].bBroInWalletBalance != 0) {
                bBroToken.mint(
                    _userMigrations[i].account,
                    _userMigrations[i].bBroInWalletBalance
                );
            }

            if (_userMigrations[i].stakedBro != 0) {
                broToken.safeApprove(
                    address(staking),
                    _userMigrations[i].stakedBro
                );
                staking.protocolMemberStake(
                    _userMigrations[i].account,
                    _userMigrations[i].stakedBro,
                    unstakingPeriod
                );
            }
        }
    }

    function withdrawRemainingBro() external onlyOwner {
        broToken.safeTransfer(super.owner(), broToken.balanceOf(address(this)));
    }
}
