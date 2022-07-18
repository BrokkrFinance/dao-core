//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEpochManager {
    function getEpoch() external view returns (uint256);
}
