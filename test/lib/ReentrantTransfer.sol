// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

contract ReentrantTransfer {
    using SafeERC20 for IERC20;

    error TransferFailed(bytes data);

    /**
     * @notice Transfer native token (i.e. ETH) without re-entrancy guards
     * @param recipient The recipient address
     * @param amount The amount to transfer
     * @param cappedMax A flag indicating whether to deposit up to the sender's balance, but capped at `amount`
     */
    function transferNativeToken(address recipient, uint256 amount, bool cappedMax) external {
        // Transfer without using re-entrancy guards
        if (cappedMax) {
            uint256 balance = address(this).balance;
            amount = amount <= balance ? amount : balance;
        }
        (bool success, bytes memory data) = payable(recipient).call{value: amount}("");
        if (!success) {
            revert TransferFailed(data);
        }
    }

    /**
     * @notice Transfer ERC20 token without re-entrancy guards
     * @param token The token address
     * @param recipient The recipient address
     * @param amount The amount to transfer
     * @param cappedMax A flag indicating whether to deposit up to the sender's balance, but capped at `amount`
     */
    function transferERC20Token(address token, address recipient, uint256 amount, bool cappedMax) external {
        if (cappedMax) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            amount = amount <= balance ? amount : balance;
        }
        IERC20(token).safeTransfer(recipient, amount);
    }
}
