//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEpochManager } from "./interfaces/IEpochManager.sol";
import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";
import { IDistributionHandler } from "./interfaces/IDistributionHandler.sol";
import { IStakingV1 } from "./interfaces/IStakingV1.sol";
import { DistributionHandlerBaseUpgradeable } from "./base/DistributionHandlerBaseUpgradeable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/// @title Staking V1 contract
/// @notice The Staking Contract contains the logic for BRO Token staking and reward distribution
contract StakingV1 is
    OwnableUpgradeable,
    PausableUpgradeable,
    UUPSUpgradeable,
    IDistributionHandler,
    IStakingV1,
    DistributionHandlerBaseUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeERC20Upgradeable for IERC20Mintable;

    // amount of token decimals
    uint256 public constant PRECISION = 1e18;

    // epoch manager contract
    IEpochManager public epochManager;
    // $BRO token contract
    IERC20Upgradeable public broToken;
    // $bBRO token contract
    IERC20Mintable public bBroToken;
    // community bonding contract
    address public communityBonding;

    // min amount of BRO that can be staked per tx
    uint256 public minBroStakeAmount;

    // min amount of epochs for unstaking period
    uint256 public minUnstakingPeriod;
    // max amount of epochs for unstaking period
    uint256 public maxUnstakingPeriod;

    // max amount of unstaking periods the staker can have
    // this check is omitted when staking via community bonding
    uint8 public maxUnstakingPeriodsPerStaker;
    // max amount of withdrawals per unstaking period the staker can have
    // 5 unstaking periods = 25 withdrawals max
    uint8 public maxWithdrawalsPerUnstakingPeriod;

    // variable for calculating rewards generating amount
    // that will generate $BRO staking rewards
    uint256 public rewardGeneratingAmountBaseIndex; // .0000 number
    // percentage that is used to decrease
    // withdrawal rewards generating $BRO amount
    uint256 public withdrawalAmountReducePerc; // .00 number
    // percentage that is used to decrease
    // $bBRO rewards for unstaked amounts
    uint256 public withdrawnBBroRewardReducePerc; // .00 number

    // variable for calculating $bBRO rewards
    uint256 public bBroRewardsBaseIndex; // .0000 number
    // variable for calculating $bBRO rewards
    uint16 public bBroRewardsXtraMultiplier;

    // global reward index
    uint256 public globalBroRewardIndex;
    // total amount of $BRO tokens locked inside staking contract
    uint256 public totalBroStaked;

    // staker info
    mapping(address => Staker) private stakers;

    /// @notice allows only community bonding contract to access
    modifier onlyCommunityBonding() {
        require(
            _msgSender() == communityBonding,
            "Caller is not the community bonding contract"
        );
        _;
    }

    function initialize(InitializeParams calldata initParams_)
        public
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __UUPSUpgradeable_init();
        __DistributionHandlerBaseUpgradeable_init(initParams_.distributor_);

        epochManager = IEpochManager(initParams_.epochManager_);
        broToken = IERC20Upgradeable(initParams_.broToken_);
        bBroToken = IERC20Mintable(initParams_.bBroToken_);
        communityBonding = initParams_.communityBonding_;

        minBroStakeAmount = initParams_.minBroStakeAmount_;

        minUnstakingPeriod = initParams_.minUnstakingPeriod_;
        maxUnstakingPeriod = initParams_.maxUnstakingPeriod_;

        maxUnstakingPeriodsPerStaker = initParams_
            .maxUnstakingPeriodsPerStaker_;
        maxWithdrawalsPerUnstakingPeriod = initParams_
            .maxWithdrawalsPerUnstakingPeriod_;

        require(
            initParams_.rewardGeneratingAmountBaseIndex_ > 0 &&
                initParams_.rewardGeneratingAmountBaseIndex_ <= 10000,
            "Invalid decimals"
        );
        rewardGeneratingAmountBaseIndex =
            (initParams_.rewardGeneratingAmountBaseIndex_ * PRECISION) /
            10_000;
        withdrawalAmountReducePerc = initParams_.withdrawalAmountReducePerc_;
        withdrawnBBroRewardReducePerc = initParams_
            .withdrawnBBroRewardReducePerc_;

        require(
            initParams_.bBroRewardsBaseIndex_ > 0 &&
                initParams_.bBroRewardsBaseIndex_ <= 10000,
            "Invalid decimals"
        );
        bBroRewardsBaseIndex =
            (initParams_.bBroRewardsBaseIndex_ * PRECISION) /
            10_000;
        bBroRewardsXtraMultiplier = initParams_.bBroRewardsXtraMultiplier_;
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override onlyOwner {}

    /// @inheritdoc IDistributionHandler
    function handleDistribution(uint256 _amount) external onlyDistributor {
        if (totalBroStaked == 0) {
            broToken.safeTransfer(distributor, _amount);
            return;
        }

        globalBroRewardIndex += (_amount * PRECISION) / totalBroStaked;
        emit DistributionHandled(_amount);
    }

    /// @inheritdoc IStakingV1
    function stake(uint256 _amount, uint256 _unstakingPeriod)
        external
        whenNotPaused
    {
        _assertProperStakeAmount(_amount);
        broToken.safeTransferFrom(_msgSender(), address(this), _amount);

        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        _adjustOrCreateUnstakingPeriod(
            staker,
            _amount,
            _unstakingPeriod,
            false
        );
        emit Staked(_msgSender(), _amount, _unstakingPeriod);
    }

    /// @inheritdoc IStakingV1
    function communityBondStake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external onlyCommunityBonding whenNotPaused {
        _assertProperStakeAmount(_amount);
        broToken.safeTransferFrom(_msgSender(), address(this), _amount);

        Staker storage staker = _updateStaker(
            _stakerAddress,
            _getStakerWithRecalculatedRewards(_stakerAddress)
        );

        _adjustOrCreateUnstakingPeriod(staker, _amount, _unstakingPeriod, true);
        emit CommunityBondStaked(_msgSender(), _amount, _unstakingPeriod);
    }

    /// @inheritdoc IStakingV1
    function compound(uint256 _unstakingPeriod) external whenNotPaused {
        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        if (staker.pendingBroReward == 0) {
            revert NothingToCompound();
        }

        uint256 broReward = staker.pendingBroReward;
        staker.pendingBroReward = 0;

        _adjustOrCreateUnstakingPeriod(
            staker,
            broReward,
            _unstakingPeriod,
            false
        );
        emit Compounded(_msgSender(), broReward, _unstakingPeriod);
    }

    /// @inheritdoc IStakingV1
    function increaseUnstakingPeriod(
        uint256 _currentUnstakingPeriod,
        uint256 _increasedUnstakingPeriod
    ) external whenNotPaused {
        require(
            _currentUnstakingPeriod < _increasedUnstakingPeriod,
            "Unstaking period can only be increased"
        );
        _assertProperUnstakingPeriod(_increasedUnstakingPeriod);

        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        (
            uint256 currentUnstakingPeriodPos,
            bool currentExists
        ) = _findUnstakingPeriod(staker, _currentUnstakingPeriod);
        if (!currentExists) {
            revert UnstakingPeriodNotFound(_currentUnstakingPeriod);
        }

        UnstakingPeriod storage currentUnstakingPeriod = staker
            .unstakingPeriods[currentUnstakingPeriodPos];
        totalBroStaked -= currentUnstakingPeriod.rewardsGeneratingAmount;

        (, bool increasedExists) = _findUnstakingPeriod(
            staker,
            _increasedUnstakingPeriod
        );
        if (increasedExists) {
            uint256 totalStakedPerCurrentUnstakingPeriod = currentUnstakingPeriod
                    .rewardsGeneratingAmount +
                    currentUnstakingPeriod.lockedAmount;

            // existing unstaking period will be adjusted
            _adjustOrCreateUnstakingPeriod(
                staker,
                totalStakedPerCurrentUnstakingPeriod,
                _increasedUnstakingPeriod,
                false
            );

            staker.unstakingPeriods[currentUnstakingPeriodPos] = staker
                .unstakingPeriods[staker.unstakingPeriods.length - 1];
            staker.unstakingPeriods.pop();
        } else {
            uint256 totalStakedPerUnstakingPeriod = currentUnstakingPeriod
                .rewardsGeneratingAmount + currentUnstakingPeriod.lockedAmount;

            uint256 newRewardsGeneratingAmount = _computeRewardsGeneratingBro(
                totalStakedPerUnstakingPeriod,
                _increasedUnstakingPeriod
            );

            totalBroStaked += newRewardsGeneratingAmount;
            currentUnstakingPeriod
                .rewardsGeneratingAmount = newRewardsGeneratingAmount;
            currentUnstakingPeriod.lockedAmount =
                totalStakedPerUnstakingPeriod -
                newRewardsGeneratingAmount;
            currentUnstakingPeriod.unstakingPeriod = _increasedUnstakingPeriod;
        }
    }

    /// @inheritdoc IStakingV1
    function unstake(uint256 _amount, uint256 _unstakingPeriod)
        external
        whenNotPaused
    {
        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        (uint256 unstakingPeriodPos, bool exists) = _findUnstakingPeriod(
            staker,
            _unstakingPeriod
        );
        if (!exists) {
            revert UnstakingPeriodNotFound(_unstakingPeriod);
        }

        UnstakingPeriod storage unstakingPeriod = staker.unstakingPeriods[
            unstakingPeriodPos
        ];
        uint256 totalStakedPerUnstakingPeriod = unstakingPeriod
            .rewardsGeneratingAmount + unstakingPeriod.lockedAmount;
        uint256 withdrawalsByUnstakingPeriodCount = _countWithdrawalsByUnstakingPeriod(
                staker,
                _unstakingPeriod
            );

        require(
            totalStakedPerUnstakingPeriod > 0 &&
                _amount <= totalStakedPerUnstakingPeriod,
            "Unstake amount must be less then total staked amount per unstake"
        );
        require(
            withdrawalsByUnstakingPeriodCount <
                maxWithdrawalsPerUnstakingPeriod,
            "Withdrawals limit reached. Wait until one of them will be released"
        );

        if (
            withdrawalsByUnstakingPeriodCount ==
            maxWithdrawalsPerUnstakingPeriod - 1 &&
            _amount != totalStakedPerUnstakingPeriod
        ) {
            revert WithdrawalsLimitWasReached();
        }

        // 1. Take withdrawalAmountReducePerc cut from unstake amount
        // 2. Calculate rewards generating amount based on unstaking period
        uint256 reducedRewardsGeneratingWithdrawalAmount = _computeRewardsGeneratingBro(
                (_amount * withdrawalAmountReducePerc) / 100,
                unstakingPeriod.unstakingPeriod
            );
        Withdrawal memory withdrawal = Withdrawal(
            reducedRewardsGeneratingWithdrawalAmount,
            _amount - reducedRewardsGeneratingWithdrawalAmount,
            staker.lastRewardsClaimTimestamp,
            unstakingPeriod.unstakingPeriod
        );

        totalBroStaked -= unstakingPeriod.rewardsGeneratingAmount;

        uint256 reducedTotalStakedPerUnstakingPeriod = totalStakedPerUnstakingPeriod -
                _amount;
        unstakingPeriod.rewardsGeneratingAmount = _computeRewardsGeneratingBro(
            reducedTotalStakedPerUnstakingPeriod,
            unstakingPeriod.unstakingPeriod
        );
        unstakingPeriod.lockedAmount =
            reducedTotalStakedPerUnstakingPeriod -
            unstakingPeriod.rewardsGeneratingAmount;
        staker.withdrawals.push(withdrawal);

        totalBroStaked +=
            unstakingPeriod.rewardsGeneratingAmount +
            withdrawal.rewardsGeneratingAmount;

        emit Unstaked(_msgSender(), _amount, unstakingPeriod.unstakingPeriod);
    }

    /// @inheritdoc IStakingV1
    function withdraw() external whenNotPaused {
        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        uint256 epoch = epochManager.getEpoch();

        uint256 withdrawAmount = 0;
        uint256 i = 0;
        while (i < staker.withdrawals.length) {
            Withdrawal memory withdrawal = staker.withdrawals[i];

            uint256 withdrawalExpiresAt = withdrawal.withdrewAt +
                (withdrawal.unstakingPeriod * epoch);

            // solhint-disable-next-line not-rely-on-time
            if (withdrawalExpiresAt <= block.timestamp) {
                withdrawAmount +=
                    withdrawal.rewardsGeneratingAmount +
                    withdrawal.lockedAmount;

                staker.withdrawals[i] = staker.withdrawals[
                    staker.withdrawals.length - 1
                ];
                staker.withdrawals.pop();
            } else {
                i++;
            }
        }

        if (withdrawAmount == 0) {
            revert NothingToWithdraw();
        }

        // remove empty unstaking periods
        uint256 k = 0;
        while (k < staker.unstakingPeriods.length) {
            uint256 withdrawalsByUnstakingPeriodLeft = _countWithdrawalsByUnstakingPeriod(
                    staker,
                    staker.unstakingPeriods[k].unstakingPeriod
                );

            bool canBeRemoved = staker
                .unstakingPeriods[k]
                .rewardsGeneratingAmount ==
                0 &&
                staker.unstakingPeriods[k].lockedAmount == 0 &&
                withdrawalsByUnstakingPeriodLeft == 0;

            if (canBeRemoved) {
                staker.unstakingPeriods[k] = staker.unstakingPeriods[
                    staker.unstakingPeriods.length - 1
                ];
                staker.unstakingPeriods.pop();
            } else {
                k++;
            }
        }

        broToken.safeTransfer(_msgSender(), withdrawAmount);
        emit Withdrawn(_msgSender(), withdrawAmount);
    }

    /// @inheritdoc IStakingV1
    function cancelUnstaking(uint256 _amount, uint256 _unstakingPeriod)
        external
        whenNotPaused
    {
        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        for (uint256 i = 0; i < staker.withdrawals.length; i++) {
            uint256 totalWithdrewAmount = staker
                .withdrawals[i]
                .rewardsGeneratingAmount + staker.withdrawals[i].lockedAmount;
            if (
                totalWithdrewAmount != _amount ||
                staker.withdrawals[i].unstakingPeriod != _unstakingPeriod
            ) {
                continue;
            }

            totalBroStaked -= staker.withdrawals[i].rewardsGeneratingAmount;

            staker.withdrawals[i] = staker.withdrawals[
                staker.withdrawals.length - 1
            ];
            staker.withdrawals.pop();

            _adjustOrCreateUnstakingPeriod(
                staker,
                totalWithdrewAmount,
                _unstakingPeriod,
                false
            );

            emit WithdrawalCanceled(_msgSender(), _amount, _unstakingPeriod);
            return;
        }

        revert WithdrawalNotFound(_amount, _unstakingPeriod);
    }

    /// @inheritdoc IStakingV1
    function claimRewards(bool _claimBro, bool _claimBBro)
        external
        whenNotPaused
        returns (uint256, uint256)
    {
        require(
            _claimBro || _claimBBro,
            "Must claim at least one token reward"
        );

        Staker storage staker = _updateStaker(
            _msgSender(),
            _getStakerWithRecalculatedRewards(_msgSender())
        );

        uint256 claimedBro = 0;
        uint256 claimedBBro = 0;

        if (_claimBro) {
            claimedBro = staker.pendingBroReward;
            if (claimedBro == 0) {
                revert NothingToClaim();
            }

            staker.pendingBroReward = 0;

            broToken.safeTransfer(_msgSender(), claimedBro);
            emit BroRewardsClaimed(_msgSender(), claimedBro);
        }

        if (_claimBBro) {
            claimedBBro = staker.pendingBBroReward;
            if (claimedBBro == 0) {
                revert NothingToClaim();
            }

            staker.pendingBBroReward = 0;

            bBroToken.mint(_msgSender(), claimedBBro);
            emit BBroRewardsClaimed(_msgSender(), claimedBBro);
        }

        return (claimedBro, claimedBBro);
    }

    /// @notice Updates storage staker info
    /// @param _staker staker's address
    /// @param _updated updated memory staker info struct
    /// @return storage staker struct
    function _updateStaker(address _staker, Staker memory _updated)
        private
        returns (Staker storage)
    {
        Staker storage staker = stakers[_staker];
        staker.broRewardIndex = _updated.broRewardIndex;
        staker.pendingBroReward = _updated.pendingBroReward;
        staker.pendingBBroReward = _updated.pendingBBroReward;
        staker.lastRewardsClaimTimestamp = _updated.lastRewardsClaimTimestamp;

        return staker;
    }

    /// @notice Returns staker info by specified address
    /// @dev If staker info is empty sets last rewards claim timestamp to the current date
    /// for proper rewards calculation
    /// @param _stakerAddress staker's address
    /// @return memory staker struct
    function _getStakerWithRecalculatedRewards(address _stakerAddress)
        private
        view
        returns (Staker memory)
    {
        Staker memory staker = stakers[_stakerAddress];
        if (staker.lastRewardsClaimTimestamp == 0) {
            // solhint-disable-next-line not-rely-on-time
            staker.lastRewardsClaimTimestamp = block.timestamp;
        }

        return _computeStakerRewards(staker);
    }

    /// @notice Computes rewards generating amount of $BRO
    /// that will be used to receive staking rewards
    /// @dev Formula: base + (1 - base) * unstaking_period / max_unstaking_period
    /// @param _amount $BRO amount
    /// @param _unstakingPeriod that is used for calculation
    /// @return computed rewards generating amount
    function _computeRewardsGeneratingBro(
        uint256 _amount,
        uint256 _unstakingPeriod
    ) private view returns (uint256) {
        uint256 periodIndex = (_unstakingPeriod * PRECISION) /
            maxUnstakingPeriod;
        uint256 xtraRewardGeneratingAmountIndex = 1 *
            PRECISION -
            rewardGeneratingAmountBaseIndex;

        uint256 rewardsGeneratingPerBro = rewardGeneratingAmountBaseIndex +
            ((xtraRewardGeneratingAmountIndex * periodIndex) / PRECISION);

        return (_amount * rewardsGeneratingPerBro) / PRECISION;
    }

    /// @notice Computes $BRO and $bBRO staker rewards for each unstaking period
    /// and withdrawals
    /// @dev If withdrawal already expired the staker will still receive his $BRO staking rewards
    /// but $bBRO rewards won't be generated anymore
    /// @param _staker staker info
    /// @return memory staker with recalculated rewards
    function _computeStakerRewards(Staker memory _staker)
        private
        view
        returns (Staker memory)
    {
        uint256 epoch = epochManager.getEpoch();
        // solhint-disable-next-line not-rely-on-time
        uint256 unclaimedEpochs = (block.timestamp -
            _staker.lastRewardsClaimTimestamp) / epoch;

        for (uint256 i = 0; i < _staker.unstakingPeriods.length; i++) {
            UnstakingPeriod memory unstaking = _staker.unstakingPeriods[i];

            _staker.pendingBroReward += _computeBroReward(
                unstaking.rewardsGeneratingAmount,
                _staker.broRewardIndex
            );

            // can claim some rewards
            if (unclaimedEpochs != 0) {
                _staker.pendingBBroReward += _computeBBroReward(
                    unstaking.rewardsGeneratingAmount + unstaking.lockedAmount,
                    unstaking.unstakingPeriod,
                    unclaimedEpochs
                );
            }
        }

        // compute rewards for the tokens that are stored inside withdrawals
        for (uint256 j = 0; j < _staker.withdrawals.length; j++) {
            Withdrawal memory withdrawal = _staker.withdrawals[j];

            _staker.pendingBroReward += _computeBroReward(
                withdrawal.rewardsGeneratingAmount,
                _staker.broRewardIndex
            );

            if (unclaimedEpochs != 0) {
                uint256 withdrawalExpireTimestamp = withdrawal.withdrewAt +
                    (withdrawal.unstakingPeriod * epoch);

                if (
                    _staker.lastRewardsClaimTimestamp >=
                    withdrawalExpireTimestamp
                ) {
                    // withdrawal already expired
                    continue;
                }

                uint256 withdrawalUnclaimedEpochs = (withdrawalExpireTimestamp -
                    _staker.lastRewardsClaimTimestamp) / epoch;
                if (withdrawalUnclaimedEpochs > unclaimedEpochs) {
                    // withdrawal is not expired yet
                    withdrawalUnclaimedEpochs = unclaimedEpochs;
                }

                // can claim some rewards
                if (withdrawalUnclaimedEpochs != 0) {
                    _staker.pendingBBroReward +=
                        (_computeBBroReward(
                            withdrawal.rewardsGeneratingAmount +
                                withdrawal.lockedAmount,
                            withdrawal.unstakingPeriod,
                            withdrawalUnclaimedEpochs
                        ) * withdrawnBBroRewardReducePerc) /
                        100;
                }
            }
        }

        _staker.broRewardIndex = globalBroRewardIndex;
        _staker.lastRewardsClaimTimestamp += unclaimedEpochs * epoch;

        return _staker;
    }

    /// @notice Computes stakers $BRO rewards
    /// @dev Formula: staked_bro * (global_index - staker_reward_index)
    /// @param _rewardsGeneratingBroAmount amount of $BRO for reward calculation
    /// @param _stakerRewardIndex stakers share index
    /// @return computed $BRO reward
    function _computeBroReward(
        uint256 _rewardsGeneratingBroAmount,
        uint256 _stakerRewardIndex
    ) private view returns (uint256) {
        return
            (_rewardsGeneratingBroAmount *
                (globalBroRewardIndex - _stakerRewardIndex)) / PRECISION;
    }

    /// @notice Computes stakers $bBRO rewards
    /// @dev Formula: (((base + xtra_mult * unstaking_period^2 * 10^(-6)) * staked_bro) / 365) * unclaimed_epochs
    /// @param _totalBroStakedAmount total $BRO staked inside unstaking period or withdrawal for $bBRO rewards
    /// @param _unstakingPeriod unstaking period for the rewards calculation
    /// @param _unclaimedEpochs amount of epochs when rewards wasn't claimed
    /// @return computed $bBRO reward
    function _computeBBroReward(
        uint256 _totalBroStakedAmount,
        uint256 _unstakingPeriod,
        uint256 _unclaimedEpochs
    ) private view returns (uint256) {
        uint256 bBroEmissionRate = bBroRewardsBaseIndex +
            bBroRewardsXtraMultiplier *
            (((_unstakingPeriod * _unstakingPeriod) * PRECISION) / 1000000);
        uint256 bBroPerEpochReward = ((bBroEmissionRate *
            _totalBroStakedAmount) / 365) / PRECISION;

        return bBroPerEpochReward * _unclaimedEpochs;
    }

    /// @notice Creates or adjusts existing unstaking period
    /// @dev If unstaking period exists then rewards generating amount will be recalculated
    /// but if not then new unstaking period will be created
    /// @param _staker staker info
    /// @param _amount staked amount
    /// @param _unstakingPeriod specified unstaking period
    /// @param _fromCommunityBonding if stake was performed from community bonding contract we omit checks
    function _adjustOrCreateUnstakingPeriod(
        Staker storage _staker,
        uint256 _amount,
        uint256 _unstakingPeriod,
        bool _fromCommunityBonding
    ) private {
        for (uint256 i = 0; i < _staker.unstakingPeriods.length; i++) {
            if (_staker.unstakingPeriods[i].unstakingPeriod != _unstakingPeriod)
                continue;

            totalBroStaked -= _staker
                .unstakingPeriods[i]
                .rewardsGeneratingAmount;

            uint256 totalStakedPerUnstakingPeriod = _amount +
                _staker.unstakingPeriods[i].rewardsGeneratingAmount +
                _staker.unstakingPeriods[i].lockedAmount;

            uint256 newRewardsGeneratingAmount = _computeRewardsGeneratingBro(
                totalStakedPerUnstakingPeriod,
                _unstakingPeriod
            );

            _staker
                .unstakingPeriods[i]
                .rewardsGeneratingAmount = newRewardsGeneratingAmount;
            _staker.unstakingPeriods[i].lockedAmount =
                totalStakedPerUnstakingPeriod -
                newRewardsGeneratingAmount;
            totalBroStaked += newRewardsGeneratingAmount;

            return;
        }

        // unstake with specified period doesn't exists
        _assertProperUnstakingPeriod(_unstakingPeriod);

        if (
            !_fromCommunityBonding &&
            _staker.unstakingPeriods.length >= maxUnstakingPeriodsPerStaker
        ) {
            // we are allowed to exceed unstaking periods limit only when we stake via community bonding
            revert UnstakingPeriodsLimitWasReached();
        }

        uint256 rewardsGeneratingBro = _computeRewardsGeneratingBro(
            _amount,
            _unstakingPeriod
        );

        _staker.unstakingPeriods.push(
            UnstakingPeriod(
                rewardsGeneratingBro,
                _amount - rewardsGeneratingBro,
                _unstakingPeriod
            )
        );

        totalBroStaked += rewardsGeneratingBro;
    }

    /// @notice Returns unstaking period index if found otherwise returns false
    /// @param _staker staker info
    /// @param _unstakingPeriod unstaking period to search for
    /// @return index unstaking period index
    /// @return exists boolen that states either if was found or not
    function _findUnstakingPeriod(
        Staker storage _staker,
        uint256 _unstakingPeriod
    ) private view returns (uint256 index, bool exists) {
        for (uint256 i = 0; i < _staker.unstakingPeriods.length; i++) {
            if (
                _staker.unstakingPeriods[i].unstakingPeriod == _unstakingPeriod
            ) {
                index = i;
                exists = true;
                return (index, exists);
            }
        }

        return (0, false);
    }

    /// @notice Counts withdrawals with the same unstaking period
    /// @param _staker staker info
    /// @param _unstakingPeriod unstaking period to search for
    /// @return amount of the same unstaking periods
    function _countWithdrawalsByUnstakingPeriod(
        Staker storage _staker,
        uint256 _unstakingPeriod
    ) private view returns (uint256) {
        uint256 count = 0;
        for (uint256 i = 0; i < _staker.withdrawals.length; i++) {
            if (_staker.withdrawals[i].unstakingPeriod == _unstakingPeriod) {
                count++;
            }
        }

        return count;
    }

    /// @notice Validates staked amount
    /// @param _amount staked amount
    function _assertProperStakeAmount(uint256 _amount) private view {
        require(
            _amount >= minBroStakeAmount,
            "Staking amount must be higher than min amount"
        );
    }

    /// @notice Validates unstaking period
    /// @param _unstakingPeriod specified unstaking period
    function _assertProperUnstakingPeriod(uint256 _unstakingPeriod)
        private
        view
    {
        require(
            _unstakingPeriod >= minUnstakingPeriod &&
                _unstakingPeriod <= maxUnstakingPeriod,
            "Invalid unstaking period"
        );
    }

    /// @notice Pauses the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Sets new distributor address
    /// @param _newDistributor new distributor
    function setDistributor(address _newDistributor) external onlyOwner {
        _setDistributor(_newDistributor);
    }

    /// @notice Sets new community bonding address
    /// @param _newCommunityBonding new community bonding address
    function setCommunityBonding(address _newCommunityBonding)
        external
        onlyOwner
    {
        communityBonding = _newCommunityBonding;
    }

    /// @notice Sets new min $BRO stake amount
    /// @param _newMinBroStakeAmount new min stake amount
    function setMinBroStakeAmount(uint256 _newMinBroStakeAmount)
        external
        onlyOwner
    {
        minBroStakeAmount = _newMinBroStakeAmount;
    }

    /// @notice Sets min unstaking period
    /// @param _newMinUnstakingPeriod new min unstaking period
    function setMinUnstakingPeriod(uint256 _newMinUnstakingPeriod)
        external
        onlyOwner
    {
        minUnstakingPeriod = _newMinUnstakingPeriod;
    }

    /// @notice Sets max unstaking period
    /// @param _newMaxUnstakingPeriod new max unstaking period
    function setMaxUnstakingPeriod(uint256 _newMaxUnstakingPeriod)
        external
        onlyOwner
    {
        maxUnstakingPeriod = _newMaxUnstakingPeriod;
    }

    /// @notice Sets max amount of unstaking periods per staker
    /// @param _newMaxUnstakingPeriodsPerStaker new max amount of unstaking periods per staker
    function setMaxUnstakingPeriodsPerStaker(
        uint8 _newMaxUnstakingPeriodsPerStaker
    ) external onlyOwner {
        maxUnstakingPeriodsPerStaker = _newMaxUnstakingPeriodsPerStaker;
    }

    /// @notice Sets new max withdrawals per unstaking period per staker
    /// @param _newMaxWithdrawalsPerUnstakingPeriod new max withdrawals per unstaking period per staker
    function setMaxWithdrawalsPerUnstakingPeriod(
        uint8 _newMaxWithdrawalsPerUnstakingPeriod
    ) external onlyOwner {
        maxWithdrawalsPerUnstakingPeriod = _newMaxWithdrawalsPerUnstakingPeriod;
    }

    /// @notice Sets new rewards generating amount base index
    /// @param _newRewardGeneratingAmountBaseIndex new rewards generating amount base index
    function setRewardGeneratingAmountBaseIndex(
        uint256 _newRewardGeneratingAmountBaseIndex
    ) external onlyOwner {
        require(
            _newRewardGeneratingAmountBaseIndex > 0 &&
                _newRewardGeneratingAmountBaseIndex <= 10000,
            "Invalid decimals"
        );
        rewardGeneratingAmountBaseIndex =
            (_newRewardGeneratingAmountBaseIndex * PRECISION) /
            10_000;
    }

    /// @notice Sets new withdrawal amount redice perc
    /// @param _newWithdrawalAmountReducePerc new withdrawal amount redice perc
    function setWithdrawalAmountReducePerc(
        uint256 _newWithdrawalAmountReducePerc
    ) external onlyOwner {
        require(
            _newWithdrawalAmountReducePerc > 0 &&
                _newWithdrawalAmountReducePerc <= 100,
            "Invalid decimals"
        );
        withdrawalAmountReducePerc = _newWithdrawalAmountReducePerc;
    }

    /// @notice Sets new withdrawan $bBRO reward rediced percent
    /// @param _newWithdrawnBBroRewardReducePerc new withdrawan $bBRO reward rediced percent
    function setWithdrawnBBroRewardReducePerc(
        uint256 _newWithdrawnBBroRewardReducePerc
    ) external onlyOwner {
        require(
            _newWithdrawnBBroRewardReducePerc > 0 &&
                _newWithdrawnBBroRewardReducePerc <= 100,
            "Invalid decimals"
        );
        withdrawnBBroRewardReducePerc = _newWithdrawnBBroRewardReducePerc;
    }

    /// @notice Sets new $bBRO rewards base index
    /// @param _newBBroRewardsBaseIndex new $bBRO rewards base index
    function setBBroRewardsBaseIndex(uint256 _newBBroRewardsBaseIndex)
        external
        onlyOwner
    {
        require(
            _newBBroRewardsBaseIndex > 0 && _newBBroRewardsBaseIndex <= 10000,
            "Invalid decimals"
        );
        bBroRewardsBaseIndex = (_newBBroRewardsBaseIndex * PRECISION) / 10_000;
    }

    /// @notice Sets new $bBRO rewards extra multiplier
    /// @param _newBBroRewardsXtraMultiplier new $bBRO rewards extra multiplier
    function setBBroRewardsXtraMultiplier(uint16 _newBBroRewardsXtraMultiplier)
        external
        onlyOwner
    {
        bBroRewardsXtraMultiplier = _newBBroRewardsXtraMultiplier;
    }

    /// @inheritdoc IStakingV1
    function getStakerInfo(address _stakerAddress)
        public
        view
        returns (Staker memory)
    {
        return _getStakerWithRecalculatedRewards(_stakerAddress);
    }

    /// @inheritdoc IDistributionHandler
    function supportsDistributions() public pure returns (bool) {
        return true;
    }
}
