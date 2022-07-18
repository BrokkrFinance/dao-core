//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BroToken is ERC20("Bro Token", "BRO") {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000e18;

    constructor(address initialHolder_) {
        _mint(initialHolder_, INITIAL_SUPPLY);
    }
}
