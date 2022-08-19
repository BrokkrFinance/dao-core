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

    uint256 public constant PRECISION = 1e18;

    IEpochManager public epochManager;
    IERC20Upgradeable public broToken;
    IERC20Mintable public bBroToken;
    address public communityBonding;

    uint256 public minBroStakeAmount;

    uint256 public minUnstakingPeriod;
    uint256 public maxUnstakingPeriod;

    uint8 public maxUnstakingPeriodsPerStaker;
    uint8 public maxWithdrawalsPerUnstakingPeriod;

    uint256 public rewardGeneratingAmountBaseIndex; // .0000 number
    uint256 public withdrawalAmountReducePerc; // .00 number
    uint256 public withdrawnBBroRewardReducePerc; // .00 number

    uint256 public bBroRewardsBaseIndex; // .0000 number
    uint16 public bBroRewardsXtraMultiplier;

    uint256 public globalBroRewardIndex;
    uint256 public totalBroStaked;

    mapping(address => Staker) private stakers;

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

    function handleDistribution(uint256 _amount) external onlyDistributor {
        if (totalBroStaked == 0) {
            broToken.safeTransfer(distributor, _amount);
            return;
        }

        globalBroRewardIndex += (_amount * PRECISION) / totalBroStaked;
        emit DistributionHandled(_amount);
    }

    function stake(uint256 _amount, uint256 _unstakingPeriod)
        external
        whenNotPaused
    {
        require(
            _amount >= minBroStakeAmount,
            "Staking amount must be higher than min amount"
        );
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

    function communityBondStake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external onlyCommunityBonding whenNotPaused {
        require(
            _amount >= minBroStakeAmount,
            "Staking amount must be higher than min amount"
        );
        broToken.safeTransferFrom(_msgSender(), address(this), _amount);

        Staker storage staker = _updateStaker(
            _stakerAddress,
            _getStakerWithRecalculatedRewards(_stakerAddress)
        );

        _adjustOrCreateUnstakingPeriod(staker, _amount, _unstakingPeriod, true);
        emit CommunityBondStaked(_msgSender(), _amount, _unstakingPeriod);
    }

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

    function increaseUnstakingPeriod(
        uint256 _currentUnstakingPeriod,
        uint256 _increasedUnstakingPeriod
    ) external whenNotPaused {
        require(
            _currentUnstakingPeriod < _increasedUnstakingPeriod,
            "Unstaking period can only be increased"
        );
        require(
            _increasedUnstakingPeriod >= minUnstakingPeriod &&
                _increasedUnstakingPeriod <= maxUnstakingPeriod,
            "Invalid unstaking period"
        );

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

            uint256 newRewardsGeneratingAmount = _calculateRewardsGeneratingBro(
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

        uint256 reducedRewardsGeneratingWithdrawalAmount = (_amount *
            withdrawalAmountReducePerc) / 100;
        Withdrawal memory withdrawal = Withdrawal(
            reducedRewardsGeneratingWithdrawalAmount,
            _amount - reducedRewardsGeneratingWithdrawalAmount,
            staker.lastRewardsClaimTimestamp,
            unstakingPeriod.unstakingPeriod
        );

        totalBroStaked -= unstakingPeriod.rewardsGeneratingAmount;

        uint256 reducedTotalStakedPerUnstakingPeriod = totalStakedPerUnstakingPeriod -
                _amount;
        unstakingPeriod
            .rewardsGeneratingAmount = _calculateRewardsGeneratingBro(
            reducedTotalStakedPerUnstakingPeriod,
            _unstakingPeriod
        );
        unstakingPeriod.lockedAmount =
            reducedTotalStakedPerUnstakingPeriod -
            unstakingPeriod.rewardsGeneratingAmount;
        staker.withdrawals.push(withdrawal);

        totalBroStaked +=
            unstakingPeriod.rewardsGeneratingAmount +
            withdrawal.rewardsGeneratingAmount;

        emit Unstaked(_msgSender(), _amount, _unstakingPeriod);
    }

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

        revert WithdrawalNotFound(_amount);
    }

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

        return _calculateStakerRewards(staker);
    }

    // bro rewards generating amount calculation
    // formula:
    // base + (1 - base) * unstaking_period / max_unstaking_period
    function _calculateRewardsGeneratingBro(
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

    // bro and bbro rewards calculations
    function _calculateStakerRewards(Staker memory _staker)
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

        // compute rewards for the tokens held inside withdrawals
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

    // bro rewards formula: staked_bro * (global_index - staker_reward_index)
    function _computeBroReward(
        uint256 _rewardsGeneratingBroAmount,
        uint256 _stakerRewardIndex
    ) private view returns (uint256) {
        return
            (_rewardsGeneratingBroAmount *
                (globalBroRewardIndex - _stakerRewardIndex)) / PRECISION;
    }

    // bbro  rewards formula:
    // (((base + xtra_mult * unstaking_period^2 * 10^(-6)) * staked_bro) / 365) * unclaimed_epochs
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

            uint256 newRewardsGeneratingAmount = _calculateRewardsGeneratingBro(
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
        require(
            _unstakingPeriod >= minUnstakingPeriod &&
                _unstakingPeriod <= maxUnstakingPeriod,
            "Invalid unstaking period"
        );

        if (
            !_fromCommunityBonding &&
            _staker.unstakingPeriods.length >= maxUnstakingPeriodsPerStaker
        ) {
            revert UnstakingPeriodsLimitWasReached();
        }

        uint256 rewardsGeneratingBro = _calculateRewardsGeneratingBro(
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

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setDistributor(address _newDistributor) external onlyOwner {
        _setDistributor(_newDistributor);
    }

    function setCommunityBonding(address _newCommunityBonding)
        external
        onlyOwner
    {
        communityBonding = _newCommunityBonding;
    }

    function setMinBroStakeAmount(uint256 _newMinBroStakeAmount)
        external
        onlyOwner
    {
        minBroStakeAmount = _newMinBroStakeAmount;
    }

    function setMinUnstakingPeriod(uint256 _newMinUnstakingPeriod)
        external
        onlyOwner
    {
        minUnstakingPeriod = _newMinUnstakingPeriod;
    }

    function setMaxUnstakingPeriod(uint256 _newMaxUnstakingPeriod)
        external
        onlyOwner
    {
        maxUnstakingPeriod = _newMaxUnstakingPeriod;
    }

    function setMaxUnstakingPeriodsPerStaker(
        uint8 _newMaxUnstakingPeriodsPerStaker
    ) external onlyOwner {
        maxUnstakingPeriodsPerStaker = _newMaxUnstakingPeriodsPerStaker;
    }

    function setMaxWithdrawalsPerUnstakingPeriod(
        uint8 _newMaxWithdrawalsPerUnstakingPeriod
    ) external onlyOwner {
        maxWithdrawalsPerUnstakingPeriod = _newMaxWithdrawalsPerUnstakingPeriod;
    }

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

    function setBBroRewardsXtraMultiplier(uint16 _newBBroRewardsXtraMultiplier)
        external
        onlyOwner
    {
        bBroRewardsXtraMultiplier = _newBBroRewardsXtraMultiplier;
    }

    function getStakerInfo(address _stakerAddress)
        public
        view
        returns (Staker memory)
    {
        return _getStakerWithRecalculatedRewards(_stakerAddress);
    }

    function supportsDistributions() public pure returns (bool) {
        return true;
    }
}
