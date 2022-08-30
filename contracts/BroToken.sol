//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BroToken is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000e18;

    string private _name; // re-declare name prop to be able to change it
    string private _symbol; // re-declare symbol prop to be able to change it

    constructor(
        string memory name_,
        string memory symbol_,
        address initialHolder_
    ) ERC20("", "") {
        _mint(initialHolder_, TOTAL_SUPPLY);

        _name = name_;
        _symbol = symbol_;
    }

    function setName(string memory newName_) external onlyOwner {
        _name = newName_;
    }

    function setSymbol(string memory newSymbol_) external onlyOwner {
        _symbol = newSymbol_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
