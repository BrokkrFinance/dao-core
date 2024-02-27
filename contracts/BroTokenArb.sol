//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract BroTokenArb is ERC20Votes, Ownable {
    string private _name; // re-declare name prop to be able to change it
    string private _symbol; // re-declare symbol prop to be able to change it

    constructor(
        string memory name_,
        string memory symbol_,
        address initialHolder_,
        uint256 initialSupply_,
        address owner
    ) ERC20("", "") EIP712("BrokkrFinance", "1") Ownable(owner) {
        _mint(initialHolder_, initialSupply_);

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

    function burn(uint256 value) public virtual {
        _burn(_msgSender(), value);
    }

    function burnFrom(address account, uint256 value) public virtual {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}
