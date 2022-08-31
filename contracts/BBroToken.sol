//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract BBroToken is
    ERC20BurnableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    IERC20Mintable
{
    string private _name; // re-declare name prop to be able to change it
    string private _symbol; // re-declare symbol prop to be able to change it

    mapping(address => bool) private whitelist;

    event WhitelistAddition(address indexed account);
    event WhitelistRemoval(address indexed account);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    modifier onlyWhitelisted() {
        require(whitelist[_msgSender()], "Address is not whitelisted.");
        _;
    }

    function initialize(string memory name_, string memory symbol_)
        public
        initializer
    {
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ERC20_init("", "");

        _name = name_;
        _symbol = symbol_;
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override onlyOwner {}

    function whitelistAddress(address _account) external onlyOwner {
        whitelist[_account] = true;
        emit WhitelistAddition(_account);
    }

    function removeWhitelisted(address _account) external onlyOwner {
        delete whitelist[_account];
        emit WhitelistRemoval(_account);
    }

    function mint(address _account, uint256 _amount) external onlyWhitelisted {
        _mint(_account, _amount);
    }

    function transfer(address, uint256) public pure override returns (bool) {
        revert("Transfer is disabled.");
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure override returns (bool) {
        revert("TransferFrom is disabled.");
    }

    function isWhitelisted(address _account) public view returns (bool) {
        return whitelist[_account];
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
