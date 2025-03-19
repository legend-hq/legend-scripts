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
import {UnloopLong} from "src/UnloopLong.sol";

import {IMorpho, MarketParams, Position} from "src/interfaces/IMorpho.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";

contract UnloopLongTest is Test {
    event UnloopExecuted(
        address indexed sender, address indexed exposureToken, address indexed backingToken, uint256 exposureAmount
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
    bytes unloop = new YulHelper().getCode("UnloopLong.sol/UnloopLong.json");
    address loopAddress;
    address unloopAddress;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            22047554 // 2025-03-14 08:38:23 UTC
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
        loopAddress = QuarkWallet(payable(factory.walletImplementation())).codeJar().saveCode(loop);
        unloopAddress = QuarkWallet(payable(factory.walletImplementation())).codeJar().saveCode(unloop);
    }

    function testUnloopLong() public {
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

        // Exit ~$1500 of WBTC exposure
        uint256 exposureToReduce = wbtcExposure * 0.5e18 / 1e18;
        uint256 minSwapBackingAmount = exitLoopPosition({wallet: wallet, exposureToReduce: exposureToReduce});

        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        assertLoopPosition({
            wallet: wallet,
            wbtcLongExposure: wbtcExposure - exposureToReduce,
            usdcShortExposure: 2 * startingUSDCAmount - minSwapBackingAmount
        });
    }

    function testUnloopLongMax() public {
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

        // Exit the entire exposure
        exitLoopPosition({wallet: wallet, exposureToReduce: type(uint256).max});

        // The wallet should have the starting USDC amount (within a 0.5% tolerance) now that the position is fully unlooped
        assertApproxEqRel(IERC20(USDC).balanceOf(address(wallet)), startingUSDCAmount, 0.005e18);
        assertLoopPosition({wallet: wallet, wbtcLongExposure: 0, usdcShortExposure: 0});
    }

    function testRevertsForSwapTooExpensiveUnloopingLong() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Set up some funds for test
        uint256 startingUSDCAmount = 1_000e6;
        deal(USDC, address(wallet), startingUSDCAmount);

        // Unloop $1000 of WBTC exposure
        uint256 wbtcExposure = startingUSDCAmount * 1e8 / WBTC_USDC_PRICE / 1e6;
        // Should be ~$1000 of USDC, but we set it higher to force a revert
        uint256 minSwapBackingAmount = 1_200e6;
        UnloopLong.UnloopInfo memory unloopInfo = UnloopLong.UnloopInfo({
            exposureToken: WBTC,
            backingToken: USDC,
            poolFee: 500,
            exposureAmount: wbtcExposure,
            minSwapBackingAmount: minSwapBackingAmount
        });

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            unloop,
            abi.encodeWithSelector(UnloopLong.unloop.selector, morpho, WBTC_USDC_MARKET_PARAMS, unloopInfo),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(UnloopLong.SwapTooExpensive.selector, USDC, minSwapBackingAmount, 1_000_759_942)
        );
        wallet.executeQuarkOperation(op, signature);
    }

    function testInvalidCaller() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Try to invoke callback directly, expect revert with invalid caller
        UnloopLong.UnloopLongInput memory input;
        input.poolKey = PoolAddress.getPoolKey(WBTC, USDC, 500);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            unloop,
            abi.encodeWithSelector(UnloopLong.uniswapV3SwapCallback.selector, 1e6, 1e6, abi.encode(input)),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.expectRevert(abi.encodeWithSelector(UnloopLong.InvalidCaller.selector));
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
    }

    /* ========== Helpers ========== */

    function enterLoopPosition(QuarkWallet wallet, uint256 startingUSDCAmount, uint256 loopFactor)
        internal
        returns (uint256)
    {
        vm.pauseGasMetering();
        uint256 wbtcExposure = loopFactor * startingUSDCAmount * 1e8 / WBTC_USDC_PRICE / 1e6;
        // We add a 0.5% buffer to account for price impact and swap fees
        uint256 maxSwapBackingAmount = loopFactor * startingUSDCAmount * 1.005e18 / 1e18;
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
        wallet.executeQuarkOperation(op, signature);

        return wbtcExposure;
    }

    function exitLoopPosition(QuarkWallet wallet, uint256 exposureToReduce) internal returns (uint256) {
        vm.pauseGasMetering();
        // We add a 0.5% buffer to account for price impact and swap fees
        uint256 minSwapBackingAmount =
            exposureToReduce == type(uint256).max ? 0 : exposureToReduce * WBTC_USDC_PRICE * 0.995e6 / 1e8;
        UnloopLong.UnloopInfo memory unloopInfo = UnloopLong.UnloopInfo({
            exposureToken: WBTC,
            backingToken: USDC,
            poolFee: 500,
            exposureAmount: exposureToReduce,
            minSwapBackingAmount: minSwapBackingAmount
        });

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            unloop,
            abi.encodeWithSelector(UnloopLong.unloop.selector, morpho, WBTC_USDC_MARKET_PARAMS, unloopInfo),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectEmit(true, true, true, true);
        emit UnloopExecuted(address(wallet), WBTC, USDC, exposureToReduce);
        wallet.executeQuarkOperation(op, signature);

        return minSwapBackingAmount;
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
