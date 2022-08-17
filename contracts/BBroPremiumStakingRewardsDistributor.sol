//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";
import { IStakingV1 } from "./interfaces/IStakingV1.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract BBroPremiumStakingRewardsDistributor is Ownable {
    IERC20Mintable public bBroToken;
    IStakingV1 public staking;

    uint256 public couldBeClaimedUntil;
    uint256 public minUnstakingPeriodForXtraReward;

    uint256 public unstakingPeriodForXtraRewards;
    uint256 public bBroRewardsBaseIndex; // .0000 number
    uint16 public bBroRewardsXtraMultiplier;
    uint256 public amountOfEpochsForXtraReward;

    mapping(address => bool) private claims;

    constructor(
        address bBroToken_,
        address staking_,
        uint256 couldBeClaimedUntil_,
        uint256 minUnstakingPeriodForXtraReward_,
        uint256 unstakingPeriodForXtraRewards_,
        uint256 bBroRewardsBaseIndex_,
        uint16 bBroRewardsXtraMultiplier_,
        uint256 amountOfEpochsForXtraReward_
    ) {
        bBroToken = IERC20Mintable(bBroToken_);
        staking = IStakingV1(staking_);
        couldBeClaimedUntil = couldBeClaimedUntil_;
        minUnstakingPeriodForXtraReward = minUnstakingPeriodForXtraReward_;
        unstakingPeriodForXtraRewards = unstakingPeriodForXtraRewards_;
        bBroRewardsBaseIndex = bBroRewardsBaseIndex_;
        bBroRewardsXtraMultiplier = bBroRewardsXtraMultiplier_;
        amountOfEpochsForXtraReward = amountOfEpochsForXtraReward_;
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
        uint256 broAmountForReward = _getAmountForReward(_msgSender());
        require(broAmountForReward > 0, "Nothing to claim");

        uint256 xtraBBroReward = _calculateXtraBBroReward(broAmountForReward);

        claims[_msgSender()] = true;
        bBroToken.mint(_msgSender(), xtraBBroReward);
    }

    function _getAmountForReward(address _staker)
        private
        view
        returns (uint256)
    {
        uint256 amountForReward = 0;

        IStakingV1.Staker memory staker = staking.getStakerInfo(_staker);
        for (uint256 i = 0; i < staker.unstakingPeriods.length; i++) {
            if (
                staker.unstakingPeriods[i].unstakingPeriod >=
                minUnstakingPeriodForXtraReward
            ) {
                amountForReward +=
                    staker.unstakingPeriods[i].rewardsGeneratingAmount +
                    staker.unstakingPeriods[i].lockedAmount;
            }
        }

        return amountForReward;
    }

    function _calculateXtraBBroReward(uint256 _broRewardAmount)
        private
        view
        returns (uint256)
    {
        uint256 bBroEmissionRate = bBroRewardsBaseIndex +
            bBroRewardsXtraMultiplier *
            (((unstakingPeriodForXtraRewards * unstakingPeriodForXtraRewards) *
                1e18) / 1000000);
        uint256 bBroPerEpochReward = ((bBroEmissionRate * _broRewardAmount) /
            365) / 1e18;

        return bBroPerEpochReward * amountOfEpochsForXtraReward;
    }

    function availableBBroAmountToClaim(address _account)
        public
        view
        returns (uint256)
    {
        return _calculateXtraBBroReward(_getAmountForReward(_account));
    }

    function isClaimed(address _account) public view returns (bool) {
        return claims[_account];
    }
}
