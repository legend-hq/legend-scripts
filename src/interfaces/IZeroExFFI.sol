// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

/// @dev Interface for 0x API foreign function interface (FFI) contracts
interface IZeroExFFI {
    function requestExactInSwapQuote(address buyToken, address sellToken, uint256 sellAmount, uint256 chainId)
        external
        pure
        returns (bytes memory swapData, uint256 buyAmount, address feeToken, uint256 feeAmount);
}
