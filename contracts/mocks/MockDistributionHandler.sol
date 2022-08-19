//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IDistributionHandler } from "../interfaces/IDistributionHandler.sol";

contract MockDistributionHandler is IDistributionHandler {
    bool private s;
    uint256 private counter;

    constructor(bool s_) {
        s = s_;
    }

    function handleDistribution(uint256) external {
        counter++;
    }

    function getCounter() public view returns (uint256) {
        return counter;
    }

    function supportsDistributions() public view returns (bool) {
        return s;
    }
}
