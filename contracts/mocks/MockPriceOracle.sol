//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IPriceOracle.sol";

contract MockPriceOracle is IPriceOracle {
    constructor() {}

    function updatePrice() external {}

    function consult(address, uint256 amountIn)
        external
        pure
        returns (uint256 amountOut)
    {
        amountOut = amountIn * 2;
    }
}
