// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IZeroExFFI} from "src/interfaces/IZeroExFFI.sol";

library MockZeroExFFIConstants {
    bytes public constant SWAP_DATA = hex"def1";
    uint256 public constant BUY_AMOUNT = 1e18;
    uint256 public constant FEE_AMOUNT = 0.01e18;
}

contract MockZeroExFFI is IZeroExFFI {
    function requestExactInSwapQuote(
        address buyToken,
        address, /* sellToken */
        uint256, /* sellAmount */
        uint256 /* chainId */
    ) external pure override returns (bytes memory swapData, uint256 buyAmount, address feeToken, uint256 feeAmount) {
        return (
            MockZeroExFFIConstants.SWAP_DATA,
            MockZeroExFFIConstants.BUY_AMOUNT,
            buyToken,
            MockZeroExFFIConstants.FEE_AMOUNT
        );
    }
}
