//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { TWAPOracleBase } from "../base/TWAPOracleBase.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";
import { TWAPLib } from "../libraries/TWAPLib.sol";
import { FixedPoint } from "../libraries/FixedPoint.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract TwoPoolTWAPOracle is TWAPOracleBase, IPriceOracle {
    PoolInfo public poolA;
    PoolInfo public poolB;

    address public token0;
    address public token1;

    constructor(
        address pairA_,
        address pairB_,
        uint32 priceUpdateIntervalA_,
        uint32 priceUpdateIntervalB_
    ) {
        require(pairA_ != pairB_, "Same pair address specified.");

        poolA.priceUpdateInterval = priceUpdateIntervalA_;
        poolA.pair = IUniswapV2Pair(pairA_);
        poolA.token0 = poolA.pair.token0();
        poolA.token1 = poolA.pair.token1();

        poolB.priceUpdateInterval = priceUpdateIntervalB_;
        poolB.pair = IUniswapV2Pair(pairB_);
        poolB.token0 = poolB.pair.token0();
        poolB.token1 = poolB.pair.token1();

        // both pairs must have 1 same token and 1 different token
        // e.g. USDC-AVAX/AVAX-BRO
        // price oracle will calculate prices for USDC/BRO pair
        if (poolA.token0 == poolB.token0) {
            token0 = poolA.token1;
            token1 = poolB.token1;
        } else if (poolA.token0 == poolB.token1) {
            token0 = poolA.token1;
            token1 = poolB.token0;
        } else if (poolA.token1 == poolB.token0) {
            token0 = poolA.token0;
            token1 = poolB.token1;
        } else if (poolA.token1 == poolB.token1) {
            token0 = poolA.token0;
            token1 = poolB.token0;
        } else {
            revert("Invalid pairs.");
        }

        poolA.price0CumulativeLast = poolA.pair.price0CumulativeLast();
        poolA.price1CumulativeLast = poolA.pair.price1CumulativeLast();

        (
            uint256 reserveA0,
            uint256 reserveA1,
            uint32 lastUpdateTimestampA_
        ) = poolA.pair.getReserves();
        poolA.lastUpdateTimestamp = lastUpdateTimestampA_;

        if (reserveA0 == 0 || reserveA1 == 0) {
            revert PairIsEmpty();
        }

        poolB.price0CumulativeLast = poolB.pair.price0CumulativeLast();
        poolB.price1CumulativeLast = poolB.pair.price1CumulativeLast();

        (
            uint256 reserveB0,
            uint256 reserveB1,
            uint32 lastUpdateTimestampB_
        ) = poolB.pair.getReserves();
        poolB.lastUpdateTimestamp = lastUpdateTimestampB_;

        if (reserveB0 == 0 || reserveB1 == 0) {
            revert PairIsEmpty();
        }
    }

    function updatePrice() external {
        _updatePoolInfo(poolA);
        _updatePoolInfo(poolB);
    }

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (token == token0) {
            uint256 poolBAmountIn = _getAnotherPoolAmountIn(
                amountIn,
                token,
                poolA
            );

            if (token1 == poolB.token0) {
                amountOut = TWAPLib.getAmountOut(
                    poolBAmountIn,
                    poolB.price1Average
                );
            } else {
                amountOut = TWAPLib.getAmountOut(
                    poolBAmountIn,
                    poolB.price0Average
                );
            }
        } else if (token == token1) {
            uint256 poolAAmountIn = _getAnotherPoolAmountIn(
                amountIn,
                token,
                poolB
            );

            if (token0 == poolA.token0) {
                amountOut = TWAPLib.getAmountOut(
                    poolAAmountIn,
                    poolA.price1Average
                );
            } else {
                amountOut = TWAPLib.getAmountOut(
                    poolAAmountIn,
                    poolA.price0Average
                );
            }
        } else {
            revert UnknownToken();
        }
    }

    function _getAnotherPoolAmountIn(
        uint256 amountIn,
        address token,
        PoolInfo storage pool
    ) private view returns (uint256 anotherPoolAmountIn) {
        if (token == pool.token0) {
            anotherPoolAmountIn = TWAPLib.getAmountOut(
                amountIn,
                pool.price0Average
            );
        } else {
            anotherPoolAmountIn = TWAPLib.getAmountOut(
                amountIn,
                pool.price1Average
            );
        }
    }
}
