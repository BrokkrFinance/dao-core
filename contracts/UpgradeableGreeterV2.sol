//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract UpgradeableGreeterV2 is OwnableUpgradeable, UUPSUpgradeable {
    string private greeting;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory _greeting) public reinitializer(2) {
        console.log("UpgradeableGreeterV2: Initializer called");
        setGreeting(_greeting);
    }

    function greet() public view returns (string memory) {
        return greeting;
    }

    function setGreeting(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }

    function _authorizeUpgrade(
        address /* newImplementation */
    ) internal virtual override {
        require(owner() == msg.sender, "Upgrade is not authorized");
    }
}
