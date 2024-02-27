//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IEpochManager } from "./interfaces/IEpochManager.sol";

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract EpochManager is IEpochManager, Ownable {
    uint256 private epoch;

    event EpochChanged(uint256 newEpoch);

    constructor() Ownable(msg.sender) {
        epoch = 1 days;
    }

    function setEpoch(uint256 _newEpoch) external onlyOwner {
        epoch = _newEpoch;
        emit EpochChanged(_newEpoch);
    }

    function getEpoch() public view returns (uint256) {
        return epoch;
    }
}
