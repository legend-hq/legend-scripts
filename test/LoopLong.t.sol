// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";
import {QuarkNonceManager} from "quark-core/src/QuarkNonceManager.sol";

import {QuarkWalletProxyFactory} from "quark-proxy/src/QuarkWalletProxyFactory.sol";

import {PoolAddress} from "src/vendor/uniswap-v3-periphery/PoolAddress.sol";
import {SharesMathLib} from "src/vendor/morpho_blue_periphery/SharesMathLib.sol";

import {LoopLong} from "src/LoopLong.sol";
import {IMorpho, MarketParams, Position} from "src/interfaces/IMorpho.sol";

import {Counter} from "./lib/Counter.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";

import {IComet} from "src/interfaces/IComet.sol";

contract LoopLongTest is Test {
    event LoopExecuted(
        address indexed sender,
        address indexed exposureToken,
        address indexed backingToken,
        uint256 exposureAmount,
        uint256 backingAmount
    );

    QuarkWalletProxyFactory public factory;
    // For signature to QuarkWallet
    uint256 alicePrivateKey = 0xa11ce;
    address alice = vm.addr(alicePrivateKey);

    // Contracts address on mainnet
    address constant morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    // Params for market at https://legacy.morpho.org/market?id=0x3a85e619751152991742810df6ec69ce473daef99e28a64ab2340d7b7ccfee49&network=mainnet
    address constant adaptiveCurveIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    address constant WBTC_USDC_ORACLE = 0xDddd770BADd886dF3864029e4B377B5F6a2B6b83;
    // Price from oracle at block is: 838255374224381093797298580131002978024
    uint256 constant WBTC_USDC_PRICE = 83_825;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    MarketParams WBTC_USDC_MARKET_PARAMS = MarketParams(USDC, WBTC, WBTC_USDC_ORACLE, adaptiveCurveIrm, 0.86e18);

    bytes loop = new YulHelper().getCode("LoopLong.sol/LoopLong.json");
    address loopAddress;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            22047554 // 2025-03-14 08:38:23 UTC
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
        loopAddress = QuarkWallet(payable(factory.walletImplementation())).codeJar().saveCode(loop);
    }

    function testLoopLong() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Set up some funds for test
        uint256 startingUSDCAmount = 1_000e6;
        deal(USDC, address(wallet), startingUSDCAmount);

        // Loop $1000 of USDC to get ~$3000 of WBTC exposure
        uint256 wbtcExposure =
            enterLoopPosition({wallet: wallet, startingUSDCAmount: startingUSDCAmount, loopFactor: 3});

        // Verify that the user is now supplying WBTC and borrowing USDC from Morpho
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        assertLoopPosition({wallet: wallet, wbtcLongExposure: wbtcExposure, usdcShortExposure: 2 * startingUSDCAmount});
    }

    function testLoopLongAdjustPosition() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Set up some funds for test
        uint256 startingUSDCAmount = 1_000e6;
        uint256 extraBackingAmount = 1_000e6;
        deal(USDC, address(wallet), startingUSDCAmount + extraBackingAmount);

        // 1. Loop $1000 of USDC to get ~$3000 of WBTC exposure
        uint256 wbtcExposure =
            enterLoopPosition({wallet: wallet, startingUSDCAmount: startingUSDCAmount, loopFactor: 3});

        assertEq(IERC20(USDC).balanceOf(address(wallet)), extraBackingAmount);
        assertLoopPosition({wallet: wallet, wbtcLongExposure: wbtcExposure, usdcShortExposure: 2 * startingUSDCAmount});

        // 2. Add $1000 of backing token to the position
        enterLoopPosition({wallet: wallet, startingUSDCAmount: startingUSDCAmount, loopFactor: 0});

        // Verify that the user is now supplying WBTC and borrowing USDC from Morpho
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        assertLoopPosition({
            wallet: wallet,
            wbtcLongExposure: wbtcExposure,
            usdcShortExposure: 2 * startingUSDCAmount - extraBackingAmount
        });

        // 3. Increase WBTC exposure by $1000
        uint256 extraWBTCExposure = extraBackingAmount * 1e8 / WBTC_USDC_PRICE / 1e6;
        enterLoopPosition({
            wallet: wallet,
            exposureAmount: extraWBTCExposure,
            maxSwapBackingAmount: extraBackingAmount * 1.005e18 / 1e18,
            startingUSDCAmount: 0
        });

        // Verify that the user is now supplying WBTC and borrowing USDC from Morpho
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        assertLoopPosition({
            wallet: wallet,
            wbtcLongExposure: wbtcExposure + extraWBTCExposure,
            usdcShortExposure: 2 * startingUSDCAmount - extraBackingAmount + extraBackingAmount
        });
    }

    function testRevertsForSwapTooExpensiveLoopingLong() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Set up some funds for test
        uint256 startingUSDCAmount = 1_000e6;
        deal(USDC, address(wallet), startingUSDCAmount);

        // Loop $1000 of USDC to get ~$3000 of WBTC exposure
        uint256 wbtcExposure = 3 * startingUSDCAmount * 1e8 / WBTC_USDC_PRICE / 1e6;
        // Should be at least 3x the starting USDC amount, but we set it as 2x here to force a revert
        uint256 maxSwapBackingAmount = 2 * startingUSDCAmount;
        LoopLong.LoopInfo memory loopInfo = LoopLong.LoopInfo({
            exposureToken: WBTC,
            backingToken: USDC,
            poolFee: 500,
            exposureAmount: wbtcExposure,
            maxSwapBackingAmount: maxSwapBackingAmount,
            initialBackingAmount: startingUSDCAmount
        });

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            loop,
            abi.encodeWithSelector(LoopLong.loop.selector, morpho, WBTC_USDC_MARKET_PARAMS, loopInfo),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(LoopLong.SwapTooExpensive.selector, USDC, maxSwapBackingAmount, 3_005_547_356)
        );
        wallet.executeQuarkOperation(op, signature);
    }

    function testInvalidCaller() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Try to invoke callback directly, expect revert with invalid caller
        LoopLong.LoopLongInput memory input;
        input.poolKey = PoolAddress.getPoolKey(WBTC, USDC, 500);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            loop,
            abi.encodeWithSelector(LoopLong.uniswapV3SwapCallback.selector, 1e6, 1e6, abi.encode(input)),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.expectRevert(abi.encodeWithSelector(LoopLong.InvalidCaller.selector));
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
    }

    /* ========== Helpers ========== */

    function enterLoopPosition(QuarkWallet wallet, uint256 startingUSDCAmount, uint256 loopFactor)
        internal
        returns (uint256)
    {
        uint256 wbtcExposure = loopFactor * startingUSDCAmount * 1e8 / WBTC_USDC_PRICE / 1e6;
        // We add a 0.5% buffer to account for price impact and swap fees
        uint256 maxSwapBackingAmount = loopFactor * startingUSDCAmount * 1.005e18 / 1e18;
        return enterLoopPosition({
            wallet: wallet,
            exposureAmount: wbtcExposure,
            maxSwapBackingAmount: maxSwapBackingAmount,
            startingUSDCAmount: startingUSDCAmount
        });
    }

    function enterLoopPosition(
        QuarkWallet wallet,
        uint256 exposureAmount,
        uint256 maxSwapBackingAmount,
        uint256 startingUSDCAmount
    ) internal returns (uint256) {
        vm.pauseGasMetering();
        LoopLong.LoopInfo memory loopInfo = LoopLong.LoopInfo({
            exposureToken: WBTC,
            backingToken: USDC,
            poolFee: 500,
            exposureAmount: exposureAmount,
            maxSwapBackingAmount: maxSwapBackingAmount,
            initialBackingAmount: startingUSDCAmount
        });

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            loop,
            abi.encodeWithSelector(LoopLong.loop.selector, morpho, WBTC_USDC_MARKET_PARAMS, loopInfo),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectEmit(true, true, true, true);
        emit LoopExecuted(address(wallet), WBTC, USDC, exposureAmount, startingUSDCAmount);
        wallet.executeQuarkOperation(op, signature);

        return exposureAmount;
    }

    function assertLoopPosition(QuarkWallet wallet, uint256 wbtcLongExposure, uint256 usdcShortExposure) internal {
        uint256 maxDeltaPercentage = 0.01e18; // 1%
        assertApproxEqRel(
            IMorpho(morpho).position(marketId(WBTC_USDC_MARKET_PARAMS), address(wallet)).collateral,
            wbtcLongExposure,
            maxDeltaPercentage
        );
        (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) =
            IMorpho(morpho).market(marketId(WBTC_USDC_MARKET_PARAMS));
        assertApproxEqRel(
            SharesMathLib.toAssetsUp(
                IMorpho(morpho).position(marketId(WBTC_USDC_MARKET_PARAMS), address(wallet)).borrowShares,
                totalBorrowAssets,
                totalBorrowShares
            ),
            usdcShortExposure,
            maxDeltaPercentage
        );
    }

    // Helper function to convert MarketParams to bytes32 Id
    // Reference: https://github.com/morpho-org/morpho-blue/blob/731e3f7ed97cf15f8fe00b86e4be5365eb3802ac/src/libraries/MarketParamsLib.sol
    function marketId(MarketParams memory params) public pure returns (bytes32 marketParamsId) {
        assembly ("memory-safe") {
            marketParamsId := keccak256(params, 160)
        }
    }
}
