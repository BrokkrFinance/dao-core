//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Dummy {
    uint256 public variable;

    constructor() {
        variable = 0;
    }

    receive() external payable {}

    function increment() external {
        variable++;
    }

    function getVariable() public view returns (uint256) {
        return variable;
    }
}
