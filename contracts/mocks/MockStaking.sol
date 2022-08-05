//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IStakingV1 } from "../interfaces/IStakingV1.sol";

contract MockStakingV1 is IStakingV1 {
    constructor() {}

    function stake(uint256, uint256) external pure {}

    function communityBondStake(
        address,
        uint256,
        uint256
    ) external pure {}

    function compound(uint256) external pure {}

    function unstake(uint256, uint256) external pure {}

    function withdraw() external pure {}

    function cancelUnstaking(uint256, uint256) external pure {}

    function claimRewards(bool, bool) external pure returns (uint256, uint256) {
        return (1, 1);
    }

    function getStakerInfo(address) external view returns (Staker memory) {}
}
