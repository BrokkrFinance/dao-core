//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDistributionHandler {
    function handleDistribution(uint256 _amount) external;

    function supportsDistributions() external returns (bool);
}
