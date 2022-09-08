//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TWAPOracleBase } from "../base/TWAPOracleBase.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";
import { TWAPLib } from "../libraries/TWAPLib.sol";
import { FixedPoint } from "../libraries/FixedPoint.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract OnePoolTWAPOracle is TWAPOracleBase, IPriceOracle {
    PoolInfo public pool;

    constructor(address pair_, uint32 priceUpdateInterval_) {
        pool.priceUpdateInterval = priceUpdateInterval_;

        pool.pair = IUniswapV2Pair(pair_);
        pool.token0 = pool.pair.token0();
        pool.token1 = pool.pair.token1();

        pool.price0CumulativeLast = pool.pair.price0CumulativeLast();
        pool.price1CumulativeLast = pool.pair.price1CumulativeLast();

        (uint256 reserve0, uint256 reserve1, uint32 lastUpdateTimestamp_) = pool
            .pair
            .getReserves();
        pool.lastUpdateTimestamp = lastUpdateTimestamp_;

        if (reserve0 == 0 || reserve1 == 0) {
            revert PairIsEmpty();
        }
    }

    function updatePrice() external {
        _updatePoolInfo(pool);
    }

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (token == pool.token0) {
            amountOut = TWAPLib.getAmountOut(amountIn, pool.price0Average);
        } else if (token == pool.token1) {
            amountOut = TWAPLib.getAmountOut(amountIn, pool.price1Average);
        } else {
            revert UnknownToken();
        }
    }
}
