// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {SafeERC20, IERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {SafeCast} from "v3-core/contracts/libraries/SafeCast.sol";

import {QuarkScript} from "quark-core/src/QuarkScript.sol";

import {PoolAddress} from "./vendor/uniswap-v3-periphery/PoolAddress.sol";
import {UniswapFactoryAddress} from "./lib/UniswapFactoryAddress.sol";

import {IMorpho, MarketParams, Position} from "src/interfaces/IMorpho.sol";

/**
 * @title Loop Long
 * @notice Implements a looping long strategy on Morpho using Uniswap V3 flash swap as liquidity
 * @author Legend Labs, Inc.
 */
contract LoopLong is IUniswapV3SwapCallback, QuarkScript {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error InvalidCaller();
    error SwapTooExpensive(address token, uint256 maxAmountIn, uint256 actualAmountIn);
    error InvalidMarketParams();

    event LoopExecuted(
        address indexed sender,
        address indexed exposureToken,
        address indexed backingToken,
        uint256 exposureAmount,
        uint256 backingAmount
    );

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Stores details about the looping operation
    struct LoopInfo {
        address exposureToken;
        address backingToken;
        // Uniswap pool fee
        uint24 poolFee;
        // The amount of exposure tokens to add to the loop position
        uint256 exposureAmount;
        // Maximum amount of backing tokens that should be received for the exposure amount
        uint256 maxSwapBackingAmount;
        // Amount of backing tokens added to the loop position that is provided up front by user
        uint256 initialBackingAmount;
    }

    /// @notice Input for loop long when interacting with the callback in a Uniswap V3 flash swap
    struct LoopLongInput {
        PoolAddress.PoolKey poolKey;
        address morpho;
        MarketParams morphoMarketParams;
        LoopInfo loopInfo;
    }

    /**
     * @notice Executes a looping long strategy via a flash swap (if necessary)
     * @param morpho Address of the Morpho contract to interact with
     * @param morphoMarketParams The parameters for the Morpho market to loop in
     * @param loopInfo Information for executing the loop
     */
    function loop(address morpho, MarketParams memory morphoMarketParams, LoopInfo memory loopInfo) external {
        allowCallback();

        if (
            (
                morphoMarketParams.collateralToken != loopInfo.exposureToken
                    || morphoMarketParams.loanToken != loopInfo.backingToken
            )
        ) {
            revert InvalidMarketParams();
        }
        // When looping long, we swap (short) the backing token to long the exposure token
        address tokenIn = loopInfo.backingToken;
        address tokenOut = loopInfo.exposureToken;
        uint256 amountOut = loopInfo.exposureAmount;

        bool zeroForOne = tokenIn < tokenOut;
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(tokenIn, tokenOut, loopInfo.poolFee);
        if (amountOut > 0) {
            IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), poolKey)).swap(
                address(this),
                zeroForOne,
                // Negative value for exact out
                -amountOut.toInt256(),
                zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
                abi.encode(
                    LoopLongInput({
                        poolKey: poolKey,
                        loopInfo: loopInfo,
                        morpho: morpho,
                        morphoMarketParams: morphoMarketParams
                    })
                )
            );
        } else {
            // No swap/callback necessary if the exposure amount is not being increased
            adjustBackingTokenPosition({
                repayAmount: loopInfo.initialBackingAmount,
                borrowAmount: 0,
                morpho: morpho,
                morphoMarketParams: morphoMarketParams
            });

            emit LoopExecuted(
                address(this),
                loopInfo.exposureToken,
                loopInfo.backingToken,
                loopInfo.exposureAmount,
                loopInfo.initialBackingAmount
            );
        }
    }

    /**
     * @notice Callback function for Uniswap flash swap
     * @param amount0Delta Amount of token0 owed (only need to repay positive value)
     * @param amount1Delta Amount of token1 owed (only need to repay positive value)
     * @param data Encoded LoopLongInput data passed from UniswapV3Pool.swap()
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        disallowCallback();

        LoopLongInput memory input = abi.decode(data, (LoopLongInput));
        LoopInfo memory loopInfo = input.loopInfo;
        IUniswapV3Pool pool =
            IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), input.poolKey));
        if (msg.sender != address(pool)) {
            revert InvalidCaller();
        }

        uint256 backingTokensOwed = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        if (backingTokensOwed > loopInfo.maxSwapBackingAmount) {
            revert SwapTooExpensive(loopInfo.backingToken, loopInfo.maxSwapBackingAmount, backingTokensOwed);
        }

        IERC20(input.morphoMarketParams.collateralToken).forceApprove(input.morpho, loopInfo.exposureAmount);
        IMorpho(input.morpho).supplyCollateral({
            marketParams: input.morphoMarketParams,
            assets: loopInfo.exposureAmount,
            onBehalf: address(this),
            data: new bytes(0)
        });
        adjustBackingTokenPosition({
            repayAmount: loopInfo.initialBackingAmount,
            borrowAmount: backingTokensOwed,
            morpho: input.morpho,
            morphoMarketParams: input.morphoMarketParams
        });

        // Attempt to pay back amount owed after execution
        IERC20(loopInfo.backingToken).safeTransfer(address(pool), backingTokensOwed);

        emit LoopExecuted(
            address(this),
            loopInfo.exposureToken,
            loopInfo.backingToken,
            loopInfo.exposureAmount,
            loopInfo.initialBackingAmount
        );
    }

    function adjustBackingTokenPosition(
        uint256 repayAmount,
        uint256 borrowAmount,
        address morpho,
        MarketParams memory morphoMarketParams
    ) internal {
        if (repayAmount > borrowAmount) {
            uint256 surplusAmount = repayAmount - borrowAmount;
            IERC20(morphoMarketParams.loanToken).forceApprove(morpho, surplusAmount);
            IMorpho(morpho).repay({
                marketParams: morphoMarketParams,
                assets: surplusAmount,
                shares: 0,
                onBehalf: address(this),
                data: new bytes(0)
            });
        } else if (repayAmount < borrowAmount) {
            IMorpho(morpho).borrow({
                marketParams: morphoMarketParams,
                assets: borrowAmount - repayAmount,
                shares: 0,
                onBehalf: address(this),
                receiver: address(this)
            });
        }
    }
}
