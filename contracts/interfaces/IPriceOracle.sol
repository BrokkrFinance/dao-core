//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPriceOracle {
    function updatePrice() external;

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
}
