//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library FixedPoint {
    struct UQ112x112 {
        uint224 _x;
    }

    struct UQ144x112 {
        uint256 _x;
    }

    uint8 private constant RESOLUTION = 112;

    function mul(UQ112x112 memory self, uint256 y)
        internal
        pure
        returns (UQ144x112 memory)
    {
        uint256 z = 0;
        require(
            y == 0 || (z = self._x * y) / y == self._x,
            "FixedPoint::mul: overflow"
        );
        return UQ144x112(z);
    }

    function decode144(UQ144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }
}
