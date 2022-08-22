//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title The interface to define methods that are required for handling token distribution
interface IDistributionHandler {
    /// @notice Perform action that is required when token distribution happened
    /// @param _amount amount of received tokens via distribution
    function handleDistribution(uint256 _amount) external;

    /// @notice Returns either contract supports distributions or not
    function supportsDistributions() external returns (bool);
}
