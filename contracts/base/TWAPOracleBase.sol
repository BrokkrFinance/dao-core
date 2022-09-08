//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IPriceOracle } from "../interfaces/IPriceOracle.sol";
import { TWAPLib } from "../libraries/TWAPLib.sol";
import { FixedPoint } from "../libraries/FixedPoint.sol";

abstract contract TWAPOracleBase {
    function _updatePoolInfo(IPriceOracle.PoolInfo storage pool) internal {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = TWAPLib.currentCumulativePrices(pool.pair);

        uint32 timeElapsed = blockTimestamp - pool.lastUpdateTimestamp;
        if (timeElapsed < pool.priceUpdateInterval) {
            return;
        }

        pool.price0Average = FixedPoint.UQ112x112(
            TWAPLib.getAveragePrice(
                price0Cumulative,
                pool.price0CumulativeLast,
                timeElapsed
            )
        );
        pool.price1Average = FixedPoint.UQ112x112(
            TWAPLib.getAveragePrice(
                price1Cumulative,
                pool.price1CumulativeLast,
                timeElapsed
            )
        );

        pool.price0CumulativeLast = price0Cumulative;
        pool.price1CumulativeLast = price1Cumulative;
        pool.lastUpdateTimestamp = blockTimestamp;
    }
}
