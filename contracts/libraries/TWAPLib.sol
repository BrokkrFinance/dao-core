//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { UQ112x112 } from "../libraries/UQ112x112.sol";
import { FixedPoint } from "../libraries/FixedPoint.sol";

import { IUniswapV2Pair } from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

library TWAPLib {
    using UQ112x112 for uint224;
    using FixedPoint for *;

    function getAveragePrice(
        uint256 priceCumulative,
        uint256 priceCumulativeLast,
        uint32 timeElapsed
    ) internal pure returns (uint224) {
        return uint224((priceCumulative - priceCumulativeLast) / timeElapsed);
    }

    function getAmountOut(
        uint256 amountIn,
        FixedPoint.UQ112x112 memory priceAverage
    ) internal pure returns (uint256) {
        return priceAverage.mul(amountIn).decode144();
    }

    function currentCumulativePrices(IUniswapV2Pair pair)
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
