//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPriceOracle } from "./interfaces/IPriceOracle.sol";
import { UQ112x112 } from "./libraries/UQ112x112.sol";
import { FixedPoint } from "./libraries/FixedPoint.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

contract TWAPOracle is IPriceOracle {
    using UQ112x112 for uint224;
    using FixedPoint for *;

    IUniswapV2Pair private immutable pair;
    address private immutable token0;
    address private immutable token1;

    uint32 public priceUpdateInterval;

    uint32 public lastUpdateTimestamp;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    FixedPoint.UQ112x112 public price0Average;
    FixedPoint.UQ112x112 public price1Average;

    constructor(address pair_, uint32 priceUpdateInterval_) {
        priceUpdateInterval = priceUpdateInterval_;

        pair = IUniswapV2Pair(pair_);
        token0 = pair.token0();
        token1 = pair.token1();

        price0CumulativeLast = pair.price0CumulativeLast();
        price1CumulativeLast = pair.price1CumulativeLast();

        (uint256 reserve0, uint256 reserve1, uint32 lastUpdateTimestamp_) = pair
            .getReserves();
        lastUpdateTimestamp = lastUpdateTimestamp_;

        require(
            reserve0 != 0 && reserve1 != 0,
            "Empty pair. Provide liquidity"
        );
    }

    function updatePrice() external {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = currentCumulativePrices();
        uint32 timeElapsed = blockTimestamp - lastUpdateTimestamp;

        if (timeElapsed < priceUpdateInterval) {
            return;
        }

        price0Average = FixedPoint.UQ112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.UQ112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        lastUpdateTimestamp = blockTimestamp;
    }

    function consult(address token, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "Invalid token address");
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    function currentCumulativePrices()
        internal
        view
        returns (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        )
    {
        // solhint-disable-next-line not-rely-on-time
        blockTimestamp = uint32(block.timestamp % 2**32);
        price0Cumulative = pair.price0CumulativeLast();
        price1Cumulative = pair.price1CumulativeLast();

        (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast) = pair
            .getReserves();
        if (blockTimestampLast != blockTimestamp) {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;

            price0Cumulative +=
                uint256(UQ112x112.encode(reserve1).uqdiv(reserve0)) *
                timeElapsed;

            price1Cumulative +=
                uint256(UQ112x112.encode(reserve0).uqdiv(reserve1)) *
                timeElapsed;
        }
    }
}
