// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "v3-core/contracts/libraries/SafeCast.sol";

import "quark-core/src/QuarkScript.sol";

import "./vendor/uniswap-v3-periphery/PoolAddress.sol";
import "./lib/UniswapFactoryAddress.sol";

contract Loop is IUniswapV3SwapCallback, QuarkScript {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    error InvalidCaller();

    /// @notice Input for flash swap when interacting with UniswapV3 Pool swap function
    struct FlashSwapExactOutInput {
        PoolAddress.PoolKey poolKey;
        LoopInfo loopInfo;
    }

    /// @notice Payload for UniswapFlashSwap
    struct UniswapFlashSwapExactOutPayload {
        // TODO: REDUNDANT?
        address tokenIn;
        address tokenOut;
        uint24 fee;
        uint256 amountOut;
        uint160 sqrtPriceLimitX96;
        LoopInfo loopInfo;
    }

    // TODO: NEED MORPHO MARKET
    struct LoopInfo {
        address exposureToken;
        address backingToken;
        uint24 poolFee;
        uint256 exposureAmount;
        // TODO: DO WE NEED BACKING AMOUNT? amountInMaximum, basically
        uint256 backingAmount;
        uint256 startingBackingAmount;
        bool isShort;
    }

    // TODO:
    // e.g. flash swap from collateral pool against USDC, deposit collateral, borrow USDC to repay flashloan

    // collateralToDeposit
    // find aggregateAssetBalance across chains
    // get diff=collateralToDeposit - aggregateAssetBalance to see how much to be flashed
    // flash the diff collateral -> deposit collateral -> borrow USDC -> repay loan -> repay max borrow (?)
    // - does the repay max borrow at the end work? if user already has USDC in that account, then it wouldn't work

    // TODO: need to calculate how much to repay flash loan with -> requires chaining outputs
    // TODO: Front-runnable? MEV?

    // User specifies I want to enter a 2x long loop position for collateral asset
    //  - collateral amount -> $100 USDC, loop amount -> $200 cbBTC, final borrow position of $100 USDC
    // starts with 100 USDC, flash swaps $200 of cbBTC, deposits into lending protocol and borrows $200-100 of USDC, repays flash swap

    // for shorting, user flash swaps the USDC, deposits it, then borrows the short token to repay the flash swap.
    // the diff between long and short is that for longs, starting USDC is subtracted from USDC borrow amount, and for shorts
    // starting USDC is subtracted from starting flash swap amount

    /**
     * @notice Execute a flash swap with a callback
     * @param payload Struct containing pool info and script info to execute before repaying the flash swap
     */
    function run(UniswapFlashSwapExactOutPayload memory payload) external {
        allowCallback();
        bool zeroForOne = payload.collateralToken < payload.borrowToken;
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(payload.collateralToken, payload.borrowToken, payload.fee);
        IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), poolKey)).swap(
            address(this),
            zeroForOne,
            -payload.amountOut.toInt256(),
            payload.sqrtPriceLimitX96 == 0
                ? (zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1)
                : payload.sqrtPriceLimitX96,
            abi.encode(
                FlashSwapExactOutInput({
                    poolKey: poolKey,
                    callContract: payload.callContract,
                    callData: payload.callData
                })
            )
        );
    }

    /**
     * @notice Callback function for Uniswap flash swap
     * @param amount0Delta Amount of token0 owed (only need to repay positive value)
     * @param amount1Delta Amount of token1 owed (only need to repay positive value)
     * @param data FlashSwap encoded to bytes passed from UniswapV3Pool.swap(); contains script info to execute (possibly with checks) before returning the owed amount
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        disallowCallback();

        FlashSwapExactOutInput memory input = abi.decode(data, (FlashSwapExactOutInput));
        IUniswapV3Pool pool =
            IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), input.poolKey));
        if (msg.sender != address(pool)) {
            revert InvalidCaller();
        }

        (bool success, bytes memory returnData) = input.callContract.delegatecall(input.callData);
        if (!success) {
            assembly {
                revert(add(returnData, 32), mload(returnData))
            }
        }

        // Attempt to pay back amount owed after execution
        if (amount0Delta > 0) {
            IERC20(input.poolKey.token0).safeTransfer(address(pool), uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            IERC20(input.poolKey.token1).safeTransfer(address(pool), uint256(amount1Delta));
        }
    }

    // address morpho,
    //     MarketParams memory marketParams,
    //     uint256 supplyAssetAmount,
    //     uint256 borrowAssetAmount
    // ) external {
    //     if (supplyAssetAmount == type(uint256).max) {
    //         supplyAssetAmount = IERC20(marketParams.collateralToken).balanceOf(address(this));
    //     }
    //     if (supplyAssetAmount > 0) {
    //         IERC20(marketParams.collateralToken).forceApprove(morpho, supplyAssetAmount);
    //         IMorpho(morpho).supplyCollateral({
    //             marketParams: marketParams,
    //             assets: supplyAssetAmount,
    //             onBehalf: address(this),
    //             data: new bytes(0)
    //         });
    //     }
    //     if (borrowAssetAmount > 0) {
    //         IMorpho(morpho).borrow({
    //             marketParams: marketParams,
    //             assets: borrowAssetAmount,
    //             shares: 0,
    //             onBehalf: address(this),
    //             receiver: address(this)
    //         });
    //     }
    // }

}
