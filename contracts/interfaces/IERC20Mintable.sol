//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20Mintable {
    function mint(address _account, uint256 _amount) external;

    function isWhitelisted(address _account) external view returns (bool);
}
