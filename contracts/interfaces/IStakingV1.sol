//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IStakingV1 {
    error NothingToCompound();
    error NothingToWithdraw();
    error NothingToClaim();
    error UnstakesLimitWasReached();
    error UnstakeNotFound(uint256 unstakingPeriod);
    error WithdrawalsLimitWasReached();
    error WithdrawalNotFound(uint256 amount);

    event Staked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );
    event CommunityBondStaked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );
    event Compounded(
        address indexed staker,
        uint256 compoundAmount,
        uint256 unstakingPeriod
    );
    event Unstaked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );
    event Withdrawn(address indexed staker, uint256 amount);
    event WithdrawalCanceled(
        address indexed staker,
        uint256 compoundAmount,
        uint256 unstakingPeriod
    );
    event BroRewardsClaimed(address indexed staker, uint256 amount);
    event BBroRewardsClaimed(address indexed staker, uint256 amount);

    struct InitializeParams {
        address distributor_;
        address epochManager_;
        address broToken_;
        address bBroToken_;
        address communityBonding_;
        uint256 minBroStakeAmount_;
        uint256 minUnstakingPeriod_;
        uint256 maxUnstakingPeriod_;
        uint8 maxUnstakesPerStaker_;
        uint8 maxWithdrawalsPerUnstake_;
        uint256 rewardGeneratingAmountBaseIndex_;
        uint256 withdrawalAmountReducePerc_;
        uint256 withdrawnBBroRewardReducePerc_;
        uint256 bBroRewardsBaseIndex_;
        uint16 bBroRewardsXtraMultiplier_;
    }

    struct Withdrawal {
        uint256 rewardsGeneratingAmount;
        uint256 lockedAmount;
        uint256 withdrewAt;
        uint256 unstakingPeriod;
    }

    struct Unstake {
        uint256 rewardsGeneratingAmount;
        uint256 lockedAmount;
        uint256 unstakingPeriod;
    }

    struct Staker {
        uint256 broRewardIndex;
        uint256 pendingBroReward;
        uint256 pendingBBroReward;
        uint256 lastRewardsClaimTimestamp;
        Unstake[] unstakingPeriods;
        Withdrawal[] withdrawals;
    }

    function stake(uint256 _amount, uint256 _unstakingPeriod) external;

    function communityBondStake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external;

    function compound(uint256 _unstakingPeriod) external;

    function unstake(uint256 _amount, uint256 _unstakingPeriod) external;

    function withdraw() external;

    function cancelUnstaking(uint256 _amount, uint256 _unstakingPeriod)
        external;

    function claimRewards(bool _claimBro, bool _claimBBro)
        external
        returns (uint256, uint256);

    function getStakerInfo(address _stakerAddress)
        external
        view
        returns (Staker memory);
}
