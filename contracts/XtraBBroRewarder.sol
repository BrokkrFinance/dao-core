//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";
import { IStakingV1 } from "./interfaces/IStakingV1.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract XtraBBroRewarder is Ownable {
    IERC20Mintable public bBroToken;
    IStakingV1 public staking;

    uint256 public couldBeClaimedUntil;
    uint256 public minUnstakingPeriodForXtraReward;

    uint256 public bBroRewardsBaseIndex; // .0000 number
    uint16 public bBroRewardsXtraMultiplier;
    uint256 public amountOfEpochsForXtraReward;

    uint256 public terraMigratorExtraPerc; // .00 number

    mapping(address => bool) private claims;
    mapping(address => bool) private terraMigratorsWhitelist;

    constructor(
        address bBroToken_,
        address staking_,
        uint256 couldBeClaimedUntil_,
        uint256 minUnstakingPeriodForXtraReward_,
        uint256 bBroRewardsBaseIndex_,
        uint16 bBroRewardsXtraMultiplier_,
        uint256 amountOfEpochsForXtraReward_,
        uint256 terraMigratorExtraPerc_
    ) {
        bBroToken = IERC20Mintable(bBroToken_);
        staking = IStakingV1(staking_);
        couldBeClaimedUntil = couldBeClaimedUntil_;
        minUnstakingPeriodForXtraReward = minUnstakingPeriodForXtraReward_;
        bBroRewardsBaseIndex = bBroRewardsBaseIndex_;
        bBroRewardsXtraMultiplier = bBroRewardsXtraMultiplier_;
        amountOfEpochsForXtraReward = amountOfEpochsForXtraReward_;
        terraMigratorExtraPerc = 100 + terraMigratorExtraPerc_;
    }

    modifier onlyWhenEventIsNotOver() {
        require(
            // solhint-disable-next-line not-rely-on-time
            block.timestamp <= couldBeClaimedUntil,
            "Xtra rewards event is over"
        );
        _;
    }

    modifier onlyWhenNotClaimed() {
        require(!claims[_msgSender()], "Xtra reward already claimed");
        _;
    }

    function claim() external onlyWhenEventIsNotOver onlyWhenNotClaimed {
        uint256 xtraBBroReward = _calculateXtraBBroReward(_msgSender());
        require(xtraBBroReward > 0, "Nothing to claim");

        claims[_msgSender()] = true;
        bBroToken.mint(_msgSender(), xtraBBroReward);
    }

    function batchWhitelistTerraMigrators(address[] calldata _accounts)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < _accounts.length; i++) {
            terraMigratorsWhitelist[_accounts[i]] = true;
        }
    }

    function _calculateXtraBBroReward(address _staker)
        private
        view
        returns (uint256)
    {
        IStakingV1.Staker memory staker = staking.getStakerInfo(_staker);

        uint256 bbroXtraReward = 0;
        for (uint256 i = 0; i < staker.unstakingPeriods.length; i++) {
            if (
                staker.unstakingPeriods[i].unstakingPeriod >=
                minUnstakingPeriodForXtraReward
            ) {
                bbroXtraReward += _computeBBroReward(
                    staker.unstakingPeriods[i].rewardsGeneratingAmount +
                        staker.unstakingPeriods[i].lockedAmount,
                    staker.unstakingPeriods[i].unstakingPeriod
                );
            }
        }

        for (uint256 i = 0; i < staker.withdrawals.length; i++) {
            if (
                staker.withdrawals[i].unstakingPeriod >=
                minUnstakingPeriodForXtraReward
            ) {
                bbroXtraReward += _computeBBroReward(
                    staker.withdrawals[i].rewardsGeneratingAmount +
                        staker.withdrawals[i].lockedAmount,
                    staker.withdrawals[i].unstakingPeriod
                );
            }
        }

        if (terraMigratorsWhitelist[_staker]) {
            bbroXtraReward = (bbroXtraReward * terraMigratorExtraPerc) / 100;
        }

        return bbroXtraReward;
    }

    function _computeBBroReward(uint256 _amount, uint256 _unstakingPeriod)
        private
        view
        returns (uint256)
    {
        uint256 bBroEmissionRate = bBroRewardsBaseIndex +
            bBroRewardsXtraMultiplier *
            (((_unstakingPeriod * _unstakingPeriod) * 1e18) / 1000000);
        uint256 bBroPerEpochReward = ((bBroEmissionRate * _amount) / 365) /
            1e18;

        return bBroPerEpochReward * amountOfEpochsForXtraReward;
    }

    function availableBBroAmountToClaim(address _account)
        public
        view
        returns (uint256)
    {
        return _calculateXtraBBroReward(_account);
    }

    function isClaimed(address _account) public view returns (bool) {
        return claims[_account];
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return terraMigratorsWhitelist[_account];
    }
}
