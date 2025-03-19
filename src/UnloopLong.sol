// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {SafeERC20, IERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IUniswapV3SwapCallback} from "v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol";
import {IUniswapV3Pool} from "v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {SafeCast} from "v3-core/contracts/libraries/SafeCast.sol";

import {QuarkScript} from "quark-core/src/QuarkScript.sol";

import {SharesMathLib} from "src/vendor/morpho_blue_periphery/SharesMathLib.sol";

import {PoolAddress} from "./vendor/uniswap-v3-periphery/PoolAddress.sol";
import {UniswapFactoryAddress} from "./lib/UniswapFactoryAddress.sol";

import {IMorpho, MarketParams, Position} from "src/interfaces/IMorpho.sol";

/**
 * @title Unloop Long
 * @notice Implements an unloop long strategy on Morpho using Uniswap V3 flash swap as liquidity
 * @author Legend Labs, Inc.
 */
contract UnloopLong is IUniswapV3SwapCallback, QuarkScript {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error InvalidCaller();
    error BadData();
    error SwapTooExpensive(address token, uint256 minAmountOut, uint256 actualAmountOut);
    error InvalidMarketParams();

    event UnloopExecuted(
        address indexed sender, address indexed exposureToken, address indexed backingToken, uint256 exposureAmount
    );

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    /// Reference: https://github.com/Uniswap/v3-core/blob/main/contracts/libraries/TickMath.sol
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /// @notice Stores details about the unlooping operation
    struct UnloopInfo {
        address exposureToken;
        address backingToken;
        // Uniswap pool fee
        uint24 poolFee;
        // The amount of exposure tokens to reduce from the loop position
        uint256 exposureAmount;
        // Minimum amount of backing tokens that should be received for the exposure amount
        uint256 minSwapBackingAmount;
    }

    /// @notice Input for unloop long when interacting with the callback in a Uniswap V3 flash swap
    struct UnloopLongInput {
        PoolAddress.PoolKey poolKey;
        UnloopInfo unloopInfo;
        address morpho;
        MarketParams morphoMarketParams;
    }

    /**
     * @notice Executes an unlooping long strategy via a flash swap (if necessary)
     * @param morpho Address of the Morpho contract to interact with
     * @param morphoMarketParams The parameters for the Morpho market to unloop in
     * @param unloopInfo Information for executing the unloop
     */
    function unloop(address morpho, MarketParams memory morphoMarketParams, UnloopInfo memory unloopInfo) external {
        allowCallback();

        if (
            (
                morphoMarketParams.collateralToken != unloopInfo.exposureToken
                    || morphoMarketParams.loanToken != unloopInfo.backingToken
            )
        ) {
            revert InvalidMarketParams();
        }
        // When unlooping long, we swap the exposure token to repay the backing token
        address tokenIn = unloopInfo.exposureToken;
        address tokenOut = unloopInfo.backingToken;
        uint256 amountIn;
        if (unloopInfo.exposureAmount == type(uint256).max) {
            amountIn = IMorpho(morpho).position(marketId(morphoMarketParams), address(this)).collateral;
        } else {
            amountIn = unloopInfo.exposureAmount;
        }

        bool zeroForOne = tokenIn < tokenOut;
        PoolAddress.PoolKey memory poolKey = PoolAddress.getPoolKey(tokenIn, tokenOut, unloopInfo.poolFee);
        IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), poolKey)).swap(
            address(this),
            zeroForOne,
            // Positive value for exact in
            amountIn.toInt256(),
            zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1,
            abi.encode(
                UnloopLongInput({
                    poolKey: poolKey,
                    unloopInfo: unloopInfo,
                    morpho: morpho,
                    morphoMarketParams: morphoMarketParams
                })
            )
        );
    }

    /**
     * @notice Callback function for Uniswap flash swap
     * @param amount0Delta Amount of token0 owed (only need to repay positive value)
     * @param amount1Delta Amount of token1 owed (only need to repay positive value)
     * @param data Encoded UnloopLongInput data passed from UniswapV3Pool.swap()
     */
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external {
        disallowCallback();

        UnloopLongInput memory input = abi.decode(data, (UnloopLongInput));
        UnloopInfo memory unloopInfo = input.unloopInfo;
        IUniswapV3Pool pool =
            IUniswapV3Pool(PoolAddress.computeAddress(UniswapFactoryAddress.getAddress(), input.poolKey));
        if (msg.sender != address(pool)) {
            revert InvalidCaller();
        }

        uint256 backingTokensReceived = amount0Delta < 0 ? uint256(-amount0Delta) : uint256(-amount1Delta);
        uint256 exposureTokensOwed = amount0Delta > 0 ? uint256(amount0Delta) : uint256(amount1Delta);
        if (backingTokensReceived < unloopInfo.minSwapBackingAmount) {
            revert SwapTooExpensive(unloopInfo.backingToken, unloopInfo.minSwapBackingAmount, backingTokensReceived);
        }

        if (unloopInfo.exposureAmount == type(uint256).max) {
            IERC20(input.morphoMarketParams.loanToken).forceApprove(input.morpho, type(uint256).max);
            IMorpho(input.morpho).repay({
                marketParams: input.morphoMarketParams,
                assets: 0,
                shares: IMorpho(input.morpho).position(marketId(input.morphoMarketParams), address(this)).borrowShares,
                onBehalf: address(this),
                data: new bytes(0)
            });
            IERC20(input.morphoMarketParams.loanToken).forceApprove(input.morpho, 0);
        } else {
            IERC20(input.morphoMarketParams.loanToken).forceApprove(input.morpho, backingTokensReceived);
            IMorpho(input.morpho).repay({
                marketParams: input.morphoMarketParams,
                assets: backingTokensReceived,
                shares: 0,
                onBehalf: address(this),
                data: new bytes(0)
            });
        }
        IMorpho(input.morpho).withdrawCollateral({
            marketParams: input.morphoMarketParams,
            assets: exposureTokensOwed,
            onBehalf: address(this),
            receiver: address(this)
        });

        // Attempt to pay back amount owed after execution
        IERC20(unloopInfo.exposureToken).safeTransfer(address(pool), exposureTokensOwed);

        emit UnloopExecuted(address(this), unloopInfo.exposureToken, unloopInfo.backingToken, unloopInfo.exposureAmount);
    }

    // Helper function to convert MarketParams to bytes32 Id
    // Reference: https://github.com/morpho-org/morpho-blue/blob/731e3f7ed97cf15f8fe00b86e4be5365eb3802ac/src/libraries/MarketParamsLib.sol
    function marketId(MarketParams memory params) public pure returns (bytes32 marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(params, 160)
        }
    }
}
