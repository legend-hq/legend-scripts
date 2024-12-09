// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IAcrossFFI} from "src/interfaces/IAcrossFFI.sol";

library MockAcrossFFIConstants {
    uint256 public constant GAS_FEE = 1e6;
    uint256 public constant L2_GAS_FEE = 3e4;
    uint256 public constant VARIABLE_FEE_PCT = 0.01e18;
}

contract MockAcrossFFI is IAcrossFFI {
    function requestAcrossQuote(
        address, /* inputToken */
        address, /* outputToken */
        uint256, /* srcChain */
        uint256 dstChain, /* dstChain */
        uint256 /* amount */
    ) external pure override returns (uint256 gasFee, uint256 variableFeePct) {
        if (dstChain == 1) {
            return (MockAcrossFFIConstants.GAS_FEE, MockAcrossFFIConstants.VARIABLE_FEE_PCT);
        }
        
        return (MockAcrossFFIConstants.L2_GAS_FEE, MockAcrossFFIConstants.VARIABLE_FEE_PCT);
    }
}
