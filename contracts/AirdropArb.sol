//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AirdropArb is Ownable {
    using SafeERC20 for IERC20;

    IERC20 tokenToDrop;

    struct User {
        address user;
        uint256 amount;
    }

    constructor(IERC20 tokenToDrop_, address owner_) Ownable(owner_) {
        tokenToDrop = tokenToDrop_;
    }

    function airdropBatch(User[] calldata users) external {
        for (uint256 i; i < users.length; ++i) {
            tokenToDrop.safeTransfer(users[i].user, users[i].amount);
        }
    }
}
