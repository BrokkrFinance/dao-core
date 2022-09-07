//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UQ112x112 } from "../libraries/UQ112x112.sol";
import { FixedPoint } from "../libraries/FixedPoint.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

interface IPriceOracle {
    error PairIsEmpty();
    error UnknownToken();

    struct PoolInfo {
        IUniswapV2Pair pair;
        address token0;
        address token1;
        uint32 priceUpdateInterval;
        uint32 lastUpdateTimestamp;
        uint256 price0CumulativeLast;
        uint256 price1CumulativeLast;
        FixedPoint.UQ112x112 price0Average;
        FixedPoint.UQ112x112 price1Average;
    }

    function updatePrice() external;

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut);
}
