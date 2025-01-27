// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

library Math {
    function subtractFlooredAtZero(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 0;
    }

    function subtractFlooredAtOne(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : 1;
    }

    function subtractFlooredAtZero(uint256 a, uint256 b, uint256 c) internal pure returns (uint256) {
        if (a < b || a - b < c) {
            return 0;
        }
        return a - b - c;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
