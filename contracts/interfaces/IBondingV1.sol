//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPriceOracle } from "./IPriceOracle.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IBondingV1 {
    error BondingOptionNotFound(IERC20Upgradeable token);

    event BondOptionAdded(
        address indexed token,
        address indexed oracle,
        uint8 discount
    );
    event BondOptionEnabled(address indexed token);
    event BondOptionDisabled(address indexed token);
    event BondOptionRemoved(address indexed token);
    event BondPerformed(address indexed token, uint256 amount);
    event BondClaimed(address indexed bonder, uint256 amount);

    enum BondingMode {
        Normal,
        Community
    }

    struct BondOption {
        bool enabled;
        IERC20Upgradeable token;
        IPriceOracle oracle;
        uint8 discount; // .00 number
        uint256 bondingBalance;
    }

    struct Claim {
        uint256 amount;
        uint256 bondedAt;
    }

    function bond(address _token, uint256 _amount) external;

    function claim() external;
}
