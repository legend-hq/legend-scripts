// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import "forge-std/StdMath.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";
import {QuarkNonceManager} from "quark-core/src/QuarkNonceManager.sol";

import {QuarkWalletProxyFactory} from "quark-proxy/src/QuarkWalletProxyFactory.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";

import {DeFiScriptErrors} from "src/lib/DeFiScriptErrors.sol";

import "src/DeFiScripts.sol";

/**
 * Tests for supplying assets to Comet
 */
contract SupplyActionsTest is Test {
    QuarkWalletProxyFactory public factory;
    uint256 alicePrivateKey = 0xa11ce;
    address alice = vm.addr(alicePrivateKey);

    // Contracts address on mainnet
    address constant comet = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    bytes cometSupplyScript = new YulHelper().getCode("DeFiScripts.sol/CometSupplyActions.json");

    function setUp() public {
        // Fork setup
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            18429607 // 2023-10-25 13:24:00 PST
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
    }

    function testSupply() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supply.selector, comet, WETH, 10 ether),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
    }

    function testSupplyMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supply.selector, comet, WETH, type(uint256).max),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
    }

    function testSupplyTo() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet wallet2 = QuarkWallet(factory.create(alice, address(wallet), bytes32("2")));

        deal(WETH, address(wallet), 10 ether);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supplyTo.selector, comet, address(wallet2), WETH, 10 ether),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet2), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet2), WETH), 10 ether);
    }

    function testSupplyToMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet wallet2 = QuarkWallet(factory.create(alice, address(wallet), bytes32("2")));

        deal(WETH, address(wallet), 10 ether);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(
                CometSupplyActions.supplyTo.selector, comet, address(wallet2), WETH, type(uint256).max
            ),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet2), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet2), WETH), 10 ether);
    }

    function testSupplyFrom() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet wallet2 = QuarkWallet(factory.create(alice, address(wallet), bytes32("2")));

        deal(WETH, address(wallet2), 10 ether);
        vm.startPrank(address(wallet2));
        IERC20(WETH).approve(comet, 10 ether);
        IComet(comet).allow(address(wallet), true);
        vm.stopPrank();

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(
                CometSupplyActions.supplyFrom.selector, comet, address(wallet2), address(wallet), WETH, 10 ether
            ),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet2)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet2)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
    }

    function testSupplyFromMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet wallet2 = QuarkWallet(factory.create(alice, address(wallet), bytes32("2")));

        deal(WETH, address(wallet2), 10 ether);
        vm.startPrank(address(wallet2));
        IERC20(WETH).approve(comet, 10 ether);
        IComet(comet).allow(address(wallet), true);
        vm.stopPrank();

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(
                CometSupplyActions.supplyFrom.selector,
                comet,
                address(wallet2),
                address(wallet),
                WETH,
                type(uint256).max
            ),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet2)), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet2)), 0 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
    }

    function testRepayBorrow() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        vm.startPrank(address(wallet));
        IERC20(WETH).approve(comet, 10 ether);
        IComet(comet).supply(WETH, 10 ether);
        IComet(comet).withdraw(USDC, 1000e6);
        vm.stopPrank();

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supply.selector, comet, USDC, 1000e6),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IComet(comet).borrowBalanceOf(address(wallet)), 1000e6);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IComet(comet).borrowBalanceOf(address(wallet)), 0e6);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
    }

    function testSupplyMultipleCollateral() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);
        deal(LINK, address(wallet), 10e18);
        deal(USDC, address(wallet), 1000e6);

        address[] memory assets = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        assets[0] = WETH;
        assets[1] = LINK;
        assets[2] = USDC;
        amounts[0] = 10 ether;
        amounts[1] = 10e18;
        amounts[2] = 1000e6;

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supplyMultipleAssets.selector, comet, assets, amounts),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(LINK).balanceOf(address(wallet)), 10e18);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), LINK), 10e18);
        assertApproxEqAbs(IComet(comet).balanceOf(address(wallet)), 1000e6, 1);
    }

    function testSupplyMultipleCollateralMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);
        deal(LINK, address(wallet), 10e18);
        deal(USDC, address(wallet), 1000e6);

        address[] memory assets = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        assets[0] = WETH;
        assets[1] = LINK;
        assets[2] = USDC;
        amounts[0] = type(uint256).max;
        amounts[1] = 5e18;
        amounts[2] = type(uint256).max;

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supplyMultipleAssets.selector, comet, assets, amounts),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(LINK).balanceOf(address(wallet)), 10e18);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 10 ether);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), LINK), 5e18);
        assertApproxEqAbs(IComet(comet).balanceOf(address(wallet)), 1000e6, 1);
    }

    function testInvalidInput() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        address[] memory assets = new address[](3);
        uint256[] memory amounts = new uint256[](2);
        assets[0] = WETH;
        assets[1] = LINK;
        assets[2] = USDC;
        amounts[0] = 10 ether;
        amounts[1] = 10e18;

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            cometSupplyScript,
            abi.encodeWithSelector(CometSupplyActions.supplyMultipleAssets.selector, comet, assets, amounts),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        vm.expectRevert(abi.encodeWithSelector(DeFiScriptErrors.InvalidInput.selector));
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
    }
}
