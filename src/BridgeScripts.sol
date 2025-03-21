// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ITokenMessenger} from "./interfaces/ITokenMessenger.sol";

contract CCTPBridgeActions {
    function bridgeUSDC(
        address tokenMessenger,
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bool cappedMax
    ) external {
        if (cappedMax) {
            uint256 balance = IERC20(burnToken).balanceOf(address(this));
            amount = amount <= balance ? amount : balance;
        }
        IERC20(burnToken).approve(tokenMessenger, amount);
        ITokenMessenger(tokenMessenger).depositForBurn(amount, destinationDomain, mintRecipient, burnToken);
    }
}
