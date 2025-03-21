// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import "forge-std/StdMath.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

import {QuarkScript} from "quark-core/src/QuarkScript.sol";
import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";
import {QuarkNonceManager} from "quark-core/src/QuarkNonceManager.sol";

import {QuarkWalletProxyFactory} from "quark-proxy/src/QuarkWalletProxyFactory.sol";

import {Multicall} from "src/Multicall.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";

import {Counter} from "./lib/Counter.sol";
import {EvilReceiver} from "./lib/EvilReceiver.sol";
import {VictimERC777} from "./lib/VictimERC777.sol";
import {AllowCallbacks} from "./lib/AllowCallbacks.sol";
import {ReentrantTransfer} from "./lib/ReentrantTransfer.sol";

import {DeFiScriptErrors} from "src/lib/DeFiScriptErrors.sol";
import "src/DeFiScripts.sol";

/**
 * Tests for transferring assets
 */
contract TransferActionsTest is Test {
    QuarkWalletProxyFactory public factory;
    CodeJar public codeJar;
    Counter public counter;
    uint256 alicePrivateKey = 0xa11ce;
    address alice = vm.addr(alicePrivateKey);
    uint256 bobPrivateKey = 0xb0b;
    address bob = vm.addr(bobPrivateKey);
    bytes transferScript = new YulHelper().getCode("DeFiScripts.sol/TransferActions.json");
    bytes multicall = new YulHelper().getCode("Multicall.sol/Multicall.json");
    bytes allowCallbacks = new YulHelper().getCode("AllowCallbacks.sol/AllowCallbacks.json");

    // Contracts address on mainnet
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address constant ETH_PSEUDO_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        // Fork setup
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            18429607 // 2023-10-25 13:24:00 PST
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
        codeJar = QuarkWallet(payable(factory.walletImplementation())).codeJar();
    }

    function testTransferERC20TokenToEOA() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, WETH, bob, 10 ether, false),
            ScriptType.ScriptSource
        );

        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), bob, WETH, 10 ether);
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 10 ether);
    }

    function testTransferERC20TokenToQuarkWallet() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet walletBob = QuarkWallet(factory.create(bob, address(0)));

        deal(WETH, address(wallet), 10 ether);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(
                TransferActions.transferERC20Token.selector, WETH, address(walletBob), 10 ether, false
            ),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), address(walletBob), WETH, 10 ether);
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IERC20(WETH).balanceOf(address(walletBob)), 10 ether);
    }

    function testTransferERC20TokenMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, WETH, bob, type(uint256).max, true),
            ScriptType.ScriptSource
        );

        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 0 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 10 ether);
    }

    function testTransferERC20TokenMaxButCapped() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 10 ether);

        assertEq(IERC20(WETH).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, WETH, bob, 8 ether, true),
            ScriptType.ScriptSource
        );

        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(WETH).balanceOf(address(wallet)), 2 ether);
        assertEq(IERC20(WETH).balanceOf(bob), 8 ether);
    }

    function testTransferNativeTokenToEOA() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(address(wallet), 10 ether);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(bob.balance, 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, bob, 10 ether, false),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), bob, ETH_PSEUDO_ADDRESS, 10 ether);
        wallet.executeQuarkOperation(op, signature);
        // assert on native ETH balance
        assertEq(address(wallet).balance, 0 ether);
        assertEq(bob.balance, 10 ether);
    }

    function testTransferNativeTokenToQuarkWallet() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        QuarkWallet walletBob = QuarkWallet(factory.create(bob, address(0)));
        deal(address(wallet), 10 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(walletBob), 10 ether, false),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(walletBob).balance, 0 ether);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), address(walletBob), ETH_PSEUDO_ADDRESS, 10 ether);
        wallet.executeQuarkOperation(op, signature);
        // assert on native ETH balance
        assertEq(address(wallet).balance, 0 ether);
        assertEq(address(walletBob).balance, 10 ether);
    }

    function testTransferNativeTokenMax() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(address(wallet), 10 ether);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(bob.balance, 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, bob, type(uint256).max, true),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        // assert on native ETH balance
        assertEq(address(wallet).balance, 0 ether);
        assertEq(bob.balance, 10 ether);
    }

    function testTransferNativeTokenMaxButCapped() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(address(wallet), 10 ether);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(bob.balance, 0 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, bob, 8 ether, true),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        // assert on native ETH balance
        assertEq(address(wallet).balance, 2 ether);
        assertEq(bob.balance, 8 ether);
    }

    function testTransferReentrancyAttackSuccessWithCallbackEnabled() public {
        vm.pauseGasMetering();
        bytes memory reentrantTransfer = new YulHelper().getCode("ReentrantTransfer.sol/ReentrantTransfer.json");
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address reentrantTransferAddress = codeJar.saveCode(reentrantTransfer);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 2)
        );
        deal(address(wallet), 10 ether);
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(reentrantTransferAddress));
        callContracts[1] = reentrantTransferAddress;
        callDatas[1] = abi.encodeWithSelector(
            ReentrantTransfer.transferNativeToken.selector, address(evilReceiver), 1 ether, false
        );

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(address(wallet).balance, 7 ether);
        assertEq(address(evilReceiver).balance, 3 ether);
    }

    function testTransferERC777TokenReentrancyAttackSuccessWithCallbackEnabled() public {
        vm.pauseGasMetering();
        bytes memory reentrantTransfer = new YulHelper().getCode("ReentrantTransfer.sol/ReentrantTransfer.json");
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address reentrantTransferAddress = codeJar.saveCode(reentrantTransfer);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 2)
        );
        // Create victim ERC777 token
        VictimERC777 victimERC777 = new VictimERC777();
        victimERC777.mint(address(wallet), 10 ether);
        evilReceiver.setTargetTokenAddress(address(victimERC777));
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(reentrantTransferAddress));
        callContracts[1] = reentrantTransferAddress;
        callDatas[1] = abi.encodeWithSelector(
            ReentrantTransfer.transferERC20Token.selector, address(victimERC777), address(evilReceiver), 1 ether, false
        );

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 0 ether);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        // Attacker successfully transfers 3 eth by exploiting reentrancy in 1eth transfers
        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 7 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 3 ether);
    }

    function testTransferSuccessWithEvilReceiverWithoutAttackAttempt() public {
        vm.pauseGasMetering();
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address transferScriptAddress = codeJar.saveCode(transferScript);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        // Attack maxCalls set to 0, so no attack will be attempted
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 0)
        );
        deal(address(wallet), 10 ether);
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(transferScriptAddress));
        callContracts[1] = transferScriptAddress;
        callDatas[1] =
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(evilReceiver), 1 ether, false);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), address(evilReceiver), ETH_PSEUDO_ADDRESS, 1 ether);
        wallet.executeQuarkOperation(op, signature);
        assertEq(address(wallet).balance, 9 ether);
        assertEq(address(evilReceiver).balance, 1 ether);
    }

    function testTransferERC777SuccessWithEvilReceiverWithoutAttackAttempt() public {
        vm.pauseGasMetering();
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address transferScriptAddress = codeJar.saveCode(transferScript);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        // Attack maxCalls set to 0, so no attack will be attempted
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 0)
        );
        // Create victim ERC777 token
        VictimERC777 victimERC777 = new VictimERC777();
        victimERC777.mint(address(wallet), 10 ether);
        evilReceiver.setTargetTokenAddress(address(victimERC777));
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(transferScriptAddress));
        callContracts[1] = transferScriptAddress;
        callDatas[1] = abi.encodeWithSelector(
            ReentrantTransfer.transferERC20Token.selector, address(victimERC777), address(evilReceiver), 1 ether, false
        );

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 0 ether);
        vm.resumeGasMetering();
        vm.expectEmit();
        emit TransferActions.TransferExecuted(address(wallet), address(evilReceiver), address(victimERC777), 1 ether);
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 9 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 1 ether);
    }

    function testRevertsForTransferReentrancyAttackWithReentrancyGuard() public {
        vm.pauseGasMetering();
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address transferScriptAddress = codeJar.saveCode(transferScript);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 2)
        );
        deal(address(wallet), 10 ether);
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(transferScriptAddress));
        callContracts[1] = transferScriptAddress;
        callDatas[1] =
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(evilReceiver), 1 ether, false);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(
                Multicall.MulticallError.selector,
                1,
                callContracts[1],
                abi.encodeWithSelector(DeFiScriptErrors.TransferFailed.selector)
            )
        );
        wallet.executeQuarkOperation(op, signature);
        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
    }

    function testRevertsForTransferERC777ReentrancyAttackWithReentrancyGuard() public {
        vm.pauseGasMetering();
        address allowCallbacksAddress = codeJar.saveCode(allowCallbacks);
        address transferScriptAddress = codeJar.saveCode(transferScript);
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 2)
        );
        // Create victim ERC777 token
        VictimERC777 victimERC777 = new VictimERC777();
        victimERC777.mint(address(wallet), 10 ether);
        evilReceiver.setTargetTokenAddress(address(victimERC777));
        // Compose array of parameters
        address[] memory callContracts = new address[](2);
        bytes[] memory callDatas = new bytes[](2);
        callContracts[0] = allowCallbacksAddress;
        callDatas[0] = abi.encodeWithSelector(AllowCallbacks.run.selector, address(transferScriptAddress));
        callContracts[1] = transferScriptAddress;
        callDatas[1] = abi.encodeWithSelector(
            ReentrantTransfer.transferERC20Token.selector, address(victimERC777), address(evilReceiver), 1 ether, false
        );

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            multicall,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 0 ether);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(
                Multicall.MulticallError.selector,
                1,
                callContracts[1],
                abi.encodeWithSelector(QuarkScript.ReentrantCall.selector)
            )
        );
        wallet.executeQuarkOperation(op, signature);
        assertEq(IERC20(victimERC777).balanceOf(address(wallet)), 10 ether);
        assertEq(IERC20(victimERC777).balanceOf(address(evilReceiver)), 0 ether);
    }

    function testRevertsForTransferReentrancyAttackWithoutCallbackEnabled() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.REINVOKE_TRANSFER, address(evilReceiver), 1 ether, 2)
        );
        deal(address(wallet), 10 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(evilReceiver), 1 ether, false),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);

        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
        // Reentering into the QuarkWallet fails due to there being no active callback
        vm.expectRevert(abi.encodeWithSelector(DeFiScriptErrors.TransferFailed.selector));
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
    }

    function testRevertsForTransferReentrantAttackWithStolenSignature() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        EvilReceiver evilReceiver = new EvilReceiver();
        evilReceiver.setAttack(
            EvilReceiver.ReentryAttack(EvilReceiver.AttackType.STOLEN_SIGNATURE, address(evilReceiver), 1 ether, 2)
        );
        deal(address(wallet), 10 ether);
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            transferScript,
            abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(evilReceiver), 1 ether, false),
            ScriptType.ScriptSource
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        evilReceiver.stealSignature(EvilReceiver.StolenSignature(op, signature));

        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
        vm.resumeGasMetering();
        // Not replayable signature will blocked by QuarkWallet during executeQuarkOperation
        vm.expectRevert(abi.encodeWithSelector(DeFiScriptErrors.TransferFailed.selector));
        wallet.executeQuarkOperation(op, signature);
        // assert on native ETH balance
        assertEq(address(wallet).balance, 10 ether);
        assertEq(address(evilReceiver).balance, 0 ether);
    }
}
