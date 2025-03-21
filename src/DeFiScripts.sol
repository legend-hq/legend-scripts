// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ISwapRouter02, IV3SwapRouter} from "src/vendor/uniswap-swap-router-contracts/ISwapRouter02.sol";

import {QuarkScript} from "quark-core/src/QuarkScript.sol";

import {IComet} from "./interfaces/IComet.sol";
import {ICometRewards} from "./interfaces/ICometRewards.sol";
import {DeFiScriptErrors} from "./lib/DeFiScriptErrors.sol";

contract CometSupplyActions {
    using SafeERC20 for IERC20;

    /**
     *   @notice Supply an asset to Comet
     *   @param comet The Comet address
     *   @param asset The asset address
     *   @param amount The amount to supply
     */
    function supply(address comet, address asset, uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = IERC20(asset).balanceOf(address(this));
        }
        IERC20(asset).forceApprove(comet, amount);
        IComet(comet).supply(asset, amount);
    }

    /**
     * @notice Supply an asset to Comet to a specific address
     * @param comet The Comet address
     * @param to The recipient address
     * @param asset The asset address
     * @param amount The amount to supply
     */
    function supplyTo(address comet, address to, address asset, uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = IERC20(asset).balanceOf(address(this));
        }
        IERC20(asset).forceApprove(comet, amount);
        IComet(comet).supplyTo(to, asset, amount);
    }

    /**
     *   @notice Supply an asset to Comet from one address to another address
     *   @param comet The Comet address
     *   @param from The from address
     *   @param to The to address
     *   @param asset The asset address
     *   @param amount The amount to supply
     */
    function supplyFrom(address comet, address from, address to, address asset, uint256 amount) external {
        if (amount == type(uint256).max) {
            amount = IERC20(asset).balanceOf(from);
        }
        IComet(comet).supplyFrom(from, to, asset, amount);
    }

    /**
     * @notice Supply multiple assets to Comet
     * @param comet The Comet address
     * @param assets The assets to supply
     * @param amounts The amounts of each asset to supply
     */
    function supplyMultipleAssets(address comet, address[] calldata assets, uint256[] calldata amounts) external {
        if (assets.length != amounts.length) {
            revert DeFiScriptErrors.InvalidInput();
        }

        for (uint256 i = 0; i < assets.length;) {
            uint256 amount = amounts[i];
            if (amount == type(uint256).max) {
                amount = IERC20(assets[i]).balanceOf(address(this));
            }
            IERC20(assets[i]).forceApprove(comet, amount);
            IComet(comet).supply(assets[i], amount);
            unchecked {
                ++i;
            }
        }
    }
}

contract CometWithdrawActions {
    using SafeERC20 for IERC20;

    /**
     *  @notice Withdraw an asset from Comet
     *  @param comet The Comet address
     *  @param asset The asset address
     *  @param amount The amount to withdraw
     */
    function withdraw(address comet, address asset, uint256 amount) external {
        IComet(comet).withdraw(asset, amount);
    }

    /**
     * @notice Withdraw an asset from Comet to a specific address
     * @param comet The Comet address
     * @param to The recipient address
     * @param asset The asset address
     * @param amount The amount to withdraw
     */
    function withdrawTo(address comet, address to, address asset, uint256 amount) external {
        IComet(comet).withdrawTo(to, asset, amount);
    }

    /**
     *   @notice Withdraw an asset from Comet from one address to another address
     *   @param comet The Comet address
     *   @param from The from address
     *   @param to The to address
     *   @param asset The asset address
     *   @param amount The amount to withdraw
     */
    function withdrawFrom(address comet, address from, address to, address asset, uint256 amount) external {
        IComet(comet).withdrawFrom(from, to, asset, amount);
    }

    /**
     * @notice Withdraw multiple assets from Comet
     * @param comet The Comet address
     * @param assets The assets to withdraw
     * @param amounts The amounts of each asset to withdraw
     */
    function withdrawMultipleAssets(address comet, address[] calldata assets, uint256[] calldata amounts) external {
        if (assets.length != amounts.length) {
            revert DeFiScriptErrors.InvalidInput();
        }

        for (uint256 i = 0; i < assets.length;) {
            IComet(comet).withdraw(assets[i], amounts[i]);
            unchecked {
                ++i;
            }
        }
    }
}

contract UniswapSwapActions {
    using SafeERC20 for IERC20;

    struct SwapParamsExactIn {
        address uniswapRouter;
        address recipient;
        address tokenFrom;
        uint256 amount;
        // Minimum amount of target token to receive (revert if return amount is less than this)
        uint256 amountOutMinimum;
        // Path of the swap
        bytes path;
    }

    struct SwapParamsExactOut {
        address uniswapRouter;
        address recipient;
        address tokenFrom;
        uint256 amount;
        // Maximum amount of input token to spend (revert if input amount is greater than this)
        uint256 amountInMaximum;
        // Path of the swap
        bytes path;
    }

    /**
     * @notice Swap token on Uniswap with Exact Input (i.e. Set input amount and swap for target token)
     * @param params SwapParamsExactIn struct
     */
    function swapAssetExactIn(SwapParamsExactIn calldata params) external {
        uint256 amount = params.amount;
        if (amount == type(uint256).max) {
            amount = IERC20(params.tokenFrom).balanceOf(address(this));
        }
        IERC20(params.tokenFrom).forceApprove(params.uniswapRouter, params.amount);
        ISwapRouter02(params.uniswapRouter).exactInput(
            IV3SwapRouter.ExactInputParams({
                path: params.path,
                recipient: params.recipient,
                amountIn: amount,
                amountOutMinimum: params.amountOutMinimum
            })
        );
    }

    /**
     * @notice Swap token on Uniswap with Exact Output (i.e. Set output amount and swap with required amount of input token)
     * @param params SwapParamsExactOut struct
     */
    function swapAssetExactOut(SwapParamsExactOut calldata params) external {
        IERC20(params.tokenFrom).forceApprove(params.uniswapRouter, params.amountInMaximum);
        uint256 amountIn = ISwapRouter02(params.uniswapRouter).exactOutput(
            IV3SwapRouter.ExactOutputParams({
                path: params.path,
                recipient: params.recipient,
                amountOut: params.amount,
                amountInMaximum: params.amountInMaximum
            })
        );

        // Reset approved leftover input token back to 0, if there is any leftover approved amount
        if (amountIn < params.amountInMaximum) {
            IERC20(params.tokenFrom).forceApprove(params.uniswapRouter, 0);
        }
    }
}

contract TransferActions is QuarkScript {
    using SafeERC20 for IERC20;

    address constant ETH_PSEUDO_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event TransferExecuted(address indexed sender, address indexed recipient, address indexed token, uint256 amount);

    /**
     * @notice Transfer ERC20 token
     * @param token The token address
     * @param recipient The recipient address
     * @param amount The amount to transfer
     * @param cappedMax A flag indicating whether to deposit up to the sender's balance, but capped at `amount`
     */
    function transferERC20Token(address token, address recipient, uint256 amount, bool cappedMax)
        external
        nonReentrant
    {
        if (cappedMax) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            amount = amount <= balance ? amount : balance;
        }
        IERC20(token).safeTransfer(recipient, amount);
        emit TransferExecuted(address(this), recipient, token, amount);
    }

    /**
     * @notice Transfer native token (i.e. ETH)
     * @param recipient The recipient address
     * @param amount The amount to transfer
     * @param cappedMax A flag indicating whether to deposit up to the sender's balance, but capped at `amount`
     */
    function transferNativeToken(address recipient, uint256 amount, bool cappedMax) external nonReentrant {
        if (cappedMax) {
            uint256 balance = address(this).balance;
            amount = amount <= balance ? amount : balance;
        }
        bool success = payable(recipient).send(amount);
        if (!success) {
            revert DeFiScriptErrors.TransferFailed();
        }
        emit TransferExecuted(address(this), recipient, ETH_PSEUDO_ADDRESS, amount);
    }
}

contract CometClaimRewards {
    /**
     * @notice Claim rewards
     * @param cometRewards The CometRewards addresses
     * @param comets The Comet addresses
     * @param accounts The accounts that the Comet rewards are being claimed for
     */
    function claim(address[] calldata cometRewards, address[] calldata comets, address[] calldata accounts) external {
        if (cometRewards.length != comets.length || cometRewards.length != accounts.length) {
            revert DeFiScriptErrors.InvalidInput();
        }

        for (uint256 i = 0; i < cometRewards.length;) {
            ICometRewards(cometRewards[i]).claim(comets[i], accounts[i], true);
            unchecked {
                ++i;
            }
        }
    }
}

contract CometSupplyMultipleAssetsAndBorrow {
    // To handle non-standard ERC20 tokens (i.e. USDT)
    using SafeERC20 for IERC20;

    function run(
        address comet,
        address[] calldata assets,
        uint256[] calldata amounts,
        address baseAsset,
        uint256 borrow
    ) external {
        if (assets.length != amounts.length) {
            revert DeFiScriptErrors.InvalidInput();
        }

        for (uint256 i = 0; i < assets.length;) {
            uint256 amount = amounts[i];
            if (amount == type(uint256).max) {
                amount = IERC20(assets[i]).balanceOf(address(this));
            }
            if (amount > 0) {
                IERC20(assets[i]).forceApprove(comet, amount);
                IComet(comet).supply(assets[i], amount);
            }

            unchecked {
                ++i;
            }
        }

        if (borrow > 0) {
            IComet(comet).withdraw(baseAsset, borrow);
        }
    }
}

contract CometRepayAndWithdrawMultipleAssets {
    // To handle non-standard ERC20 tokens (i.e. USDT)
    using SafeERC20 for IERC20;

    function run(address comet, address[] calldata assets, uint256[] calldata amounts, address baseAsset, uint256 repay)
        external
    {
        if (assets.length != amounts.length) {
            revert DeFiScriptErrors.InvalidInput();
        }

        if (repay > 0) {
            IERC20(baseAsset).forceApprove(comet, repay);
            IComet(comet).supply(baseAsset, repay);
        }

        for (uint256 i = 0; i < assets.length;) {
            if (amounts[i] > 0) {
                IComet(comet).withdraw(assets[i], amounts[i]);
            }

            unchecked {
                ++i;
            }
        }
    }
}

contract ApproveAndSwap {
    // To handle non-standard ERC20 tokens (i.e. USDT)
    using SafeERC20 for IERC20;

    /// @notice Emitted when an approve and swap is executed
    event ApproveAndSwapExecuted(
        address indexed sender,
        address indexed swapContract,
        address sellToken,
        address buyToken,
        uint256 sellAmount,
        uint256 buyAmount
    );

    /**
     * Approve a specified contract for an amount of token and execute the data against it
     * @param to The contract address to approve execute on
     * @param sellToken The token address to approve
     * @param sellAmount The amount to approve
     * @param buyToken The token that is being bought
     * @param buyAmount The amount of the buy token to receive after the swap
     * @param data The data to execute
     */
    function run(
        address to,
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        uint256 buyAmount,
        bytes calldata data
    ) external {
        IERC20(sellToken).forceApprove(to, sellAmount);

        uint256 sellTokenBalanceBefore = IERC20(sellToken).balanceOf(address(this));
        uint256 buyTokenBalanceBefore = IERC20(buyToken).balanceOf(address(this));

        (bool success, bytes memory returnData) = to.call(data);
        if (!success) {
            revert DeFiScriptErrors.ApproveAndSwapFailed(returnData);
        }

        uint256 sellTokenBalanceAfter = IERC20(sellToken).balanceOf(address(this));
        uint256 buyTokenBalanceAfter = IERC20(buyToken).balanceOf(address(this));

        uint256 actualSellAmount = sellTokenBalanceBefore - sellTokenBalanceAfter;
        uint256 actualBuyAmount = buyTokenBalanceAfter - buyTokenBalanceBefore;

        if (actualBuyAmount < buyAmount) {
            revert DeFiScriptErrors.TooMuchSlippage(buyAmount, actualBuyAmount);
        }

        // Approvals to external contracts should always be reset to 0
        IERC20(sellToken).forceApprove(to, 0);

        // Emit the approve and swap event
        emit ApproveAndSwapExecuted(address(this), to, sellToken, buyToken, actualSellAmount, actualBuyAmount);
    }
}
