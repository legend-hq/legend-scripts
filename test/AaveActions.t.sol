// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import "forge-std/StdMath.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";
import {IERC20} from "openzeppelin/interfaces/IERC20.sol";
import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";
import {QuarkNonceManager} from "quark-core/src/QuarkNonceManager.sol";

import {QuarkWalletProxyFactory} from "quark-proxy/src/QuarkWalletProxyFactory.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";
import {IPool} from "aave-v3-origin/src/contracts/interfaces/IPool.sol";
import {IPoolDataProvider} from "aave-v3-origin/src/contracts/interfaces/IPoolDataProvider.sol";
import {IPoolAddressesProvider} from "aave-v3-origin/src/contracts/interfaces/IPoolAddressesProvider.sol";
import "src/AaveScripts.sol";

/**
 * Tests for Morpho Blue market
 */
contract MorphoActionsTest is Test {
    QuarkWalletProxyFactory public factory;
    uint256 alicePrivateKey = 0xa11ce;
    address alice = vm.addr(alicePrivateKey);

    // Contracts address on mainnet
    address constant pool = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IPoolAddressesProvider poolAddressesProvider;
    IPoolDataProvider poolDataProvider;
    bytes AaveActionsScripts = new YulHelper().getCode("AaveScripts.sol/AaveActions.json");

    function setUp() public {
        // Fork setup
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            20564787 // 2024-08-19 12:34:00 PST
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
        poolAddressesProvider = IPoolAddressesProvider(IPool(pool).ADDRESSES_PROVIDER());
        poolDataProvider = IPoolDataProvider(poolAddressesProvider.getPoolDataProvider());
    }

    function testAaveSupply() public {
        vm.pauseGasMetering();

        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(USDC, address(wallet), 1000e6);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            AaveActionsScripts,
            abi.encodeWithSelector(AaveActions.supply.selector, pool, USDC, 1000e6),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 1000e6);
        (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(USDC, address(wallet));
        assertEq(currentATokenBalance, 0);

        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);

        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        (uint256 newCurrentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(USDC, address(wallet));
        assertEq(newCurrentATokenBalance, 1000e6);
    }

    function testAaveWithdraw() public {
        vm.pauseGasMetering();

        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(USDC, address(wallet), 1000e6);

        // Supply 1000 USDC
        vm.startPrank(address(wallet));
        IERC20(USDC).approve(pool, 1000e6);
        IPool(pool).deposit(USDC, 1000e6, address(wallet), 0);
        vm.stopPrank();

        // Time warp to get interest
        vm.warp(block.timestamp + 180 days);
        vm.roll(block.number + 180 days / 12);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            AaveActionsScripts,
            abi.encodeWithSelector(AaveActions.withdraw.selector, pool, USDC, type(uint256).max),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 0);
        (uint256 currentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(USDC, address(wallet));
        assertEq(currentATokenBalance, 1018_747609);

        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);

        assertEq(IERC20(USDC).balanceOf(address(wallet)), 1018_747609);
        (uint256 newCurrentATokenBalance,,,,,,,,) = poolDataProvider.getUserReserveData(USDC, address(wallet));
        assertEq(newCurrentATokenBalance, 0);
    }
}
