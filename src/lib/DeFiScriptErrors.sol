// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

/**
 * @title Errors library for DeFi scripts
 * @notice Defines the custom errors that are returned by different DeFi scripts
 * @author Compound Labs, Inc.
 */
library DeFiScriptErrors {
    error InvalidInput();
    error TransferFailed();
    error ApproveAndSwapFailed(bytes data);
    error TooMuchSlippage(uint256 expectedBuyAmount, uint256 actualBuyAmount);
}
