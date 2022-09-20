//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface for the Staking V1 contract
/// @notice The Staking Contract contains the logic for BRO Token staking and reward distribution
interface IStakingV1 {
    /// @notice Emitted when compound amount is zero
    error NothingToCompound();

    /// @notice Emitted when withdraw amount is zero
    error NothingToWithdraw();

    /// @notice Emitted when rewards claim amount($BRO or $bBRO) is zero
    error NothingToClaim();

    /// @notice Emitted when configured limit for unstaking periods per staker was reached
    error UnstakingPeriodsLimitWasReached();

    /// @notice Emitted when unstaking period was not found
    /// @param unstakingPeriod specified unstaking period to search for
    error UnstakingPeriodNotFound(uint256 unstakingPeriod);

    /// @notice Emitted when configured limit for withdrawals per unstaking period was reached
    error WithdrawalsLimitWasReached();

    /// @notice Emitted when withdrawal was not found
    /// @param amount specified withdrawal amount
    /// @param unstakingPeriod specified unstaking period
    error WithdrawalNotFound(uint256 amount, uint256 unstakingPeriod);

    /// @notice Emitted when staker staked some amount by specified unstaking period
    /// @param staker staker's address
    /// @param amount staked amount
    /// @param unstakingPeriod selected unstaking period
    event Staked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );

    /// @notice Emitted when stake was performed via one of the protocol members
    /// @param staker staker's address
    /// @param amount staked amount
    /// @param unstakingPeriod selected unstaking period
    event ProtocolMemberStaked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );
    /// @notice Emitted when staker compunded his $BRO rewards
    /// @param staker staker's address
    /// @param compoundAmount compounded amount
    /// @param unstakingPeriod selected unstaking period where to deposit compounded tokens
    event Compounded(
        address indexed staker,
        uint256 compoundAmount,
        uint256 unstakingPeriod
    );

    /// @notice Emitted when staker unstaked some amount of tokens from selected unstaking period
    /// @param staker staker's address
    /// @param amount unstaked amount
    /// @param unstakingPeriod selected unstaking period from where to deduct specified amount
    event Unstaked(
        address indexed staker,
        uint256 amount,
        uint256 unstakingPeriod
    );

    /// @notice Emitted when staker withdrew his token after unstaking period was expired
    /// @param staker staker's address
    /// @param amount withdrawn amount
    event Withdrawn(address indexed staker, uint256 amount);

    /// @notice Emitted when staker cancelled withdrawal
    /// @param staker staker's address
    /// @param compoundAmount amount that was moved from withdrawal to unstaking period
    /// @param unstakingPeriod specified unstaking period to find withdrawal
    event WithdrawalCanceled(
        address indexed staker,
        uint256 compoundAmount,
        uint256 unstakingPeriod
    );

    /// @notice Emitted when staker claimed his $BRO rewards
    /// @param staker staker's address
    /// @param amount claimed $BRO amount
    event BroRewardsClaimed(address indexed staker, uint256 amount);

    /// @notice Emitted when staked claimed his $bBRO rewards
    /// @param staker staker's address
    /// @param amount claimed $bBRO amount
    event BBroRewardsClaimed(address indexed staker, uint256 amount);

    struct InitializeParams {
        // distributor address
        address distributor_;
        // epoch manager address
        address epochManager_;
        // $BRO token address
        address broToken_;
        // $bBRO token address
        address bBroToken_;
        // list of protocol members
        address[] protocolMembers_;
        // min amount of BRO that can be staked per tx
        uint256 minBroStakeAmount_;
        // min amount of epochs for unstaking period
        uint256 minUnstakingPeriod_;
        // max amount of epochs for unstaking period
        uint256 maxUnstakingPeriod_;
        // max amount of unstaking periods the staker can have
        // this check is omitted when staking via community bonding
        uint8 maxUnstakingPeriodsPerStaker_;
        // max amount of withdrawals per unstaking period the staker can have
        // 5 unstaking periods = 25 withdrawals max
        uint8 maxWithdrawalsPerUnstakingPeriod_;
        // variable for calculating rewards generating amount
        // that will generate $BRO staking rewards
        uint256 rewardGeneratingAmountBaseIndex_;
        // percentage that is used to decrease
        // withdrawal rewards generating $BRO amount
        uint256 withdrawalAmountReducePerc_;
        // percentage that is used to decrease
        // $bBRO rewards for unstaked amounts
        uint256 withdrawnBBroRewardReducePerc_;
        // variable for calculating $bBRO rewards
        uint256 bBroRewardsBaseIndex_;
        // variable for calculating $bBRO rewards
        uint16 bBroRewardsXtraMultiplier_;
    }

    struct Withdrawal {
        // $BRO rewards generating amount
        uint256 rewardsGeneratingAmount;
        // locked amount that doesn't generate $BRO rewards
        uint256 lockedAmount;
        // timestamp when unstaking period started
        uint256 withdrewAt;
        // unstaking period in epochs to wait before token release
        uint256 unstakingPeriod;
    }

    struct UnstakingPeriod {
        // $BRO rewards generating amount
        uint256 rewardsGeneratingAmount;
        // locked amount that doesn't generate $BRO rewards
        uint256 lockedAmount;
        // unstaking period in epochs to wait before token release
        uint256 unstakingPeriod;
    }

    struct Staker {
        // $BRO rewards index that is used to compute staker share
        uint256 broRewardIndex;
        // unclaimed $BRO rewards
        uint256 pendingBroReward;
        // unclaimed $bBRO rewards
        uint256 pendingBBroReward;
        // last timestamp when rewards was claimed
        uint256 lastRewardsClaimTimestamp;
        // stakers unstaking periods
        UnstakingPeriod[] unstakingPeriods;
        // stakers withdrawals
        Withdrawal[] withdrawals;
    }

    /// @notice Stakes specified amount of $BRO tokens
    /// @param _amount amount of $BRO tokens to stake
    /// @param _unstakingPeriod specified unstaking period
    function stake(uint256 _amount, uint256 _unstakingPeriod) external;

    /// @notice Stake specified amount of $BRO tokens via one of the protocol members
    /// @param _stakerAddress staker's address
    /// @param _amount bonded amount that will be staked
    /// @param _unstakingPeriod specified unstaking period
    function protocolMemberStake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external;

    /// @notice Compounds staker pending $BRO rewards and deposits them to specified unstaking period
    /// @param _unstakingPeriod specified unstaking period
    function compound(uint256 _unstakingPeriod) external;

    /// @notice Increases selected unstaking period
    /// @dev If increase version of unstaking period already exists the contract will
    /// move all the funds there and remove the old one
    /// @param _currentUnstakingPeriod unstaking period to increase
    /// @param _increasedUnstakingPeriod increased unstaking period
    function increaseUnstakingPeriod(
        uint256 _currentUnstakingPeriod,
        uint256 _increasedUnstakingPeriod
    ) external;

    /// @notice Unstakes specified amount of $BRO tokens.
    /// Unstaking period starts at this moment of time.
    /// @param _amount specified amount to unstake
    /// @param _unstakingPeriod specified unstaking period
    function unstake(uint256 _amount, uint256 _unstakingPeriod) external;

    /// @notice Unstakes specified amount of $BRO tokens via one of the protocol members.
    /// Unstaking period starts at this moment of time.
    /// @param _stakerAddress staker's address
    /// @param _amount specified amount to unstake
    /// @param _unstakingPeriod specified unstaking period
    function protocolMemberUnstake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external;

    /// @notice Removes all expired withdrawals and transferes unstaked amount to the staker
    function withdraw() external;

    /// @notice Cancels withdrawal. Moves withdrawn funds back to the unstaking period
    /// @param _amount specified amount to find withdrawal
    /// @param _unstakingPeriod specified unstaking period to find withdrawal
    function cancelUnstaking(uint256 _amount, uint256 _unstakingPeriod)
        external;

    /// @notice Claimes staker rewards and transferes them to the staker wallet
    /// @param _claimBro defines either to claim $BRO rewards or not
    /// @param _claimBBro defines either to claim $bBRO rewards or not
    /// @return amount of claimed $BRO and $bBRO tokens
    function claimRewards(bool _claimBro, bool _claimBBro)
        external
        returns (uint256, uint256);

    /// @notice Returns staker info
    /// @param _stakerAddress staker's address to look for
    function getStakerInfo(address _stakerAddress)
        external
        view
        returns (Staker memory);

    /// @notice Returns total amount of rewards generating $BRO by staker address
    /// @param _stakerAddress staker's address to look for
    function totalStakerRewardsGeneratingBro(address _stakerAddress)
        external
        view
        returns (uint256);
}
