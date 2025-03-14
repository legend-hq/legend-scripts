// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {DeFiScriptErrors} from "src/lib/DeFiScriptErrors.sol";
import {IPool} from "aave-v3-origin/src/contracts/interfaces/IPool.sol";

contract AaveActions {
    using SafeERC20 for IERC20;

    function supply(address pool, address asset, uint256 amount) external {
        IERC20(asset).safeApprove(pool, amount);
        IPool(pool).deposit(asset, amount, address(this), 0);
    }

    function withdraw(address pool, address asset, uint256 amount) external {
        IPool(pool).withdraw(asset, amount, address(this));
    }
}
