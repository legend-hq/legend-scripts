// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
import {QuarkScript} from "quark-core/src/QuarkScript.sol";
import {DeFiScriptErrors} from "./lib/DeFiScriptErrors.sol";

contract AavePoolActions {
    using SafeERC20 for IERC20;

    /**
     *   @notice Supply an asset to Aave Pool
     *   @param pool The Aave Pool address
     *   @param asset The asset address
     *   @param amount The amount to supply
     */
    function supply(address pool, address asset, uint256 amount) external {
        IERC20(asset).safeApprove(pool, amount);
        IPool(pool).supply(asset, amount, msg.sender, 0);
    }

    /**
     *  @notice Withdraw an asset from Aave Pool
     *  @param pool The Aave Pool address
     *  @param asset The asset address
     *  @param amount The amount to withdraw
     */
    function withdraw(address pool, address asset, uint256 amount) external {
        IPool(pool).withdraw(asset, amount, msg.sender);
    }

    /**
     * @notice Borrow assets from Aave Pool
     * @param pool The Aave Pool address
     * @param asset The asset address to borrow
     * @param amountToBorrow The amount to borrow
     */
    function borrow(
        address pool,
        address asset,
        uint256 amountToBorrow
    ) external {
        IPool(pool).borrow(asset, amountToBorrow, 2, 0, msg.sender);
    }

    /**
     * @notice Repay assets to Aave Pool
     * @param pool The Aave Pool address
     * @param asset The asset address to repay
     * @param amountToRepay The amount to repay
     */
    function repay(
        address pool,
        address asset,
        uint256 amountToRepay
    ) external {
        IERC20(asset).safeApprove(pool, amountToRepay);
        IPool(pool).repay(asset, amountToRepay, 2, msg.sender);
    }
}
