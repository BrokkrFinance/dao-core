//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStakingV1 } from "../interfaces/IStakingV1.sol";

contract MockStakingV1 is IStakingV1 {
    mapping(address => Staker) private stakers;

    constructor() {}

    function stake(uint256, uint256) external pure {}

    function protocolMemberStake(
        address,
        uint256,
        uint256
    ) external pure {}

    function compound(uint256) external pure {}

    function increaseUnstakingPeriod(
        uint256 _currentUnstakingPeriod,
        uint256 _increasedUnstakingPeriod
    ) external pure {}

    function unstake(uint256, uint256) external pure {}

    function protocolMemberUnstake(
        address _stakerAddress,
        uint256 _amount,
        uint256 _unstakingPeriod
    ) external pure {}

    function withdraw() external pure {}

    function cancelUnstaking(uint256, uint256) external pure {}

    function claimRewards(bool, bool) external pure returns (uint256, uint256) {
        return (1, 1);
    }

    function getStakerInfo(address _account)
        external
        view
        returns (Staker memory)
    {
        return stakers[_account];
    }

    function totalStakerRewardsGeneratingBro(address)
        external
        pure
        returns (uint256)
    {
        return 1;
    }

    function feedMockStakers(address a, address b) external {
        Staker storage sa = stakers[a];
        sa.unstakingPeriods.push(UnstakingPeriod(100, 100, 365));
        sa.unstakingPeriods.push(UnstakingPeriod(200, 200, 365));
        sa.unstakingPeriods.push(UnstakingPeriod(300, 200, 364));
        sa.withdrawals.push(Withdrawal(300, 50, 1, 365));

        Staker storage sb = stakers[b];
        sb.unstakingPeriods.push(UnstakingPeriod(100, 100, 14));
        sb.unstakingPeriods.push(UnstakingPeriod(200, 200, 200));
    }
}
