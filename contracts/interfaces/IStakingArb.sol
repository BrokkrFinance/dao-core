// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

interface IStakingArb {
    function stakeOnBehalf(address onBehalf, uint256 amount) external;
}
