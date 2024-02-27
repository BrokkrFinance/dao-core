//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IERC20Mintable } from "./interfaces/IERC20Mintable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract BBroTokenArb is
    OwnableUpgradeable,
    ERC20BurnableUpgradeable,
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

    function initialize(
        string memory name_,
        string memory symbol_,
        address initialHolder_,
        uint256 initialSupply_,
        address owner
    ) public initializer {
        __Ownable_init();
        __ERC20_init("", "");
        __UUPSUpgradeable_init();

        _mint(initialHolder_, initialSupply_);
        _name = name_;
        _symbol = symbol_;

        transferOwnership(owner);
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override onlyOwner {}

    function mint(address account_, uint256 amount_) external onlyWhitelisted {
        _mint(account_, amount_);
    }

    function burnFromAnyone(address account_, uint256 amount_)
        public
        virtual
        onlyWhitelisted
    {
        _burn(account_, amount_);
    }

    function whitelistAddress(address _account) external onlyOwner {
        whitelist[_account] = true;
        emit WhitelistAddition(_account);
    }

    function removeWhitelisted(address _account) external onlyOwner {
        delete whitelist[_account];
        emit WhitelistRemoval(_account);
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
