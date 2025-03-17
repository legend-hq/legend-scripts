// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

import {TStoracle} from "../src/TStoracle.sol";
import {OracleExecutor} from "../src/OracleExecutor.sol";
import {QuarkNonceManager} from "quark-core/src/QuarkNonceManager.sol";
import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";

import {QuarkMinimalProxy} from "quark-proxy/src/QuarkMinimalProxy.sol";

import {Ethcall} from "src/Ethcall.sol";

import {Counter} from "test/lib/Counter.sol";
import {Reverts} from "test/lib/Reverts.sol";

import {OracleScript} from "test/lib/OracleScript.sol";

import {YulHelper} from "test/lib/YulHelper.sol";
import {SignatureHelper} from "test/lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "test/lib/QuarkOperationHelper.sol";

contract OracleExecutorTest is Test {
    TStoracle public tStoracle;
    OracleExecutor public oracleExecutor;
    CodeJar public codeJar;
    Counter public counter;
    QuarkNonceManager public nonceManager;
    QuarkWallet public walletImplementation;

    uint256 alicePrivateKey = 0x8675309;
    uint256 bobPrivateKey = 0xb0b5309;
    address aliceAccount = vm.addr(alicePrivateKey);
    address bobAccount = vm.addr(bobPrivateKey);
    QuarkWallet aliceWallet; // see constructor()
    QuarkWallet bobWallet; // see constructor()

    bytes ethcall = new YulHelper().getCode("Ethcall.sol/Ethcall.json");
    bytes oracleScript = new YulHelper().getCode("OracleScript.sol/OracleScript.json");

    constructor() {
        tStoracle = new TStoracle();
        console.log("TStoracle deployed to: %s", address(tStoracle));

        oracleExecutor = new OracleExecutor();
        console.log("OracleExecutor deployed to: %s", address(oracleExecutor));

        codeJar = new CodeJar();
        console.log("CodeJar deployed to: %s", address(codeJar));

        counter = new Counter();
        counter.setNumber(0);
        console.log("Counter deployed to: %s", address(counter));

        nonceManager = new QuarkNonceManager();
        console.log("QuarkNonceManager deployed to: %s", address(nonceManager));

        walletImplementation = new QuarkWallet(codeJar, nonceManager);
        console.log("QuarkWallet implementation: %s", address(walletImplementation));

        aliceWallet =
            QuarkWallet(payable(new QuarkMinimalProxy(address(walletImplementation), aliceAccount, address(0))));
        console.log("Alice wallet at: %s", address(aliceWallet));

        bobWallet = QuarkWallet(payable(new QuarkMinimalProxy(address(walletImplementation), bobAccount, address(0))));
        console.log("Bob wallet at: %s", address(aliceWallet));
    }

    function testOracleExecutorSimpleExecuteSingle() public {
        // We test multiple operations with different wallets
        // gas: do not meter set-up
        vm.pauseGasMetering();

        QuarkWallet.QuarkOperation memory aliceOp = new QuarkOperationHelper().newBasicOpWithCalldata(
            aliceWallet,
            oracleScript,
            abi.encodeWithSelector(
                OracleScript.incrementCounter.selector, tStoracle, counter
            ),
            ScriptType.ScriptSource
        );

        bytes memory aliceSignature = new SignatureHelper().signOp(alicePrivateKey, aliceWallet, aliceOp);

        bytes[] memory oracleKeys = new bytes[](1);
        bytes[] memory oracleValues = new bytes[](1);

        oracleKeys[0] = "amount";
        oracleValues[0] = abi.encode(uint256(22));

        assertEq(counter.number(), 0);

        // gas: meter execute
        vm.resumeGasMetering();
        oracleExecutor.executeSingle(tStoracle, oracleKeys, oracleValues, aliceWallet, aliceOp, aliceSignature);

        assertEq(counter.number(), 22);
    }

    function testOracleExecutorSimpleExecuteSingleFailsIfOracleValueAlreadySet() public {
        // We test multiple operations with different wallets
        // gas: do not meter set-up
        vm.pauseGasMetering();

        QuarkWallet.QuarkOperation memory aliceOp = new QuarkOperationHelper().newBasicOpWithCalldata(
            aliceWallet,
            oracleScript,
            abi.encodeWithSelector(
                OracleScript.incrementCounter.selector, tStoracle, counter
            ),
            ScriptType.ScriptSource
        );

        bytes memory aliceSignature = new SignatureHelper().signOp(alicePrivateKey, aliceWallet, aliceOp);

        bytes[] memory oracleKeys = new bytes[](1);
        bytes[] memory oracleValues = new bytes[](1);

        oracleKeys[0] = "amount";
        oracleValues[0] = abi.encode(uint256(22));

        tStoracle.put(bytes("amount"), abi.encode(uint256(33)));

        assertEq(counter.number(), 0);

        // gas: meter execute
        vm.resumeGasMetering();
        vm.expectRevert(abi.encodeWithSelector(TStoracle.KeyAlreadySet.selector, bytes("amount")));
        oracleExecutor.executeSingle(tStoracle, oracleKeys, oracleValues, aliceWallet, aliceOp, aliceSignature);

        assertEq(counter.number(), 0);
    }

    function testOracleExecutorSimpleExecuteMulti() public {
        // We test multiple operations with different wallets
        // gas: do not meter set-up
        vm.pauseGasMetering();

        QuarkWallet.QuarkOperation memory op1 = new QuarkOperationHelper().newBasicOpWithCalldata(
            aliceWallet,
            ethcall,
            abi.encodeWithSelector(
                Ethcall.run.selector, address(counter), abi.encodeWithSignature("increment(uint256)", (1)), 0
            ),
            ScriptType.ScriptAddress
        );
        bytes32 op1Digest = new SignatureHelper().opDigest(address(aliceWallet), op1);

        QuarkWallet.QuarkOperation memory op2 = new QuarkOperationHelper().newBasicOpWithCalldata(
            aliceWallet,
            oracleScript,
            abi.encodeWithSelector(
                OracleScript.incrementCounter.selector, tStoracle, counter
            ),
            ScriptType.ScriptAddress
        );
        op2.nonce = new QuarkOperationHelper().incrementNonce(op1.nonce);
        bytes32 op2Digest = new SignatureHelper().opDigest(address(aliceWallet), op2);

        bytes32[] memory opDigests = new bytes32[](2);
        opDigests[0] = op1Digest;
        opDigests[1] = op2Digest;
        bytes memory signature = new SignatureHelper().signMultiOp(alicePrivateKey, opDigests);

        bytes[] memory oracleKeys1 = new bytes[](0);
        bytes[] memory oracleValues1 = new bytes[](0);

        bytes[] memory oracleKeys2 = new bytes[](1);
        bytes[] memory oracleValues2 = new bytes[](1);

        oracleKeys2[0] = "amount";
        oracleValues2[0] = abi.encode(uint256(22));

        assertEq(counter.number(), 0);

        // gas: meter execute
        vm.resumeGasMetering();
        oracleExecutor.executeMulti(tStoracle, oracleKeys1, oracleValues1, aliceWallet, op1, opDigests, signature);

        assertEq(counter.number(), 1);

        oracleExecutor.executeMulti(tStoracle, oracleKeys2, oracleValues2, aliceWallet, op2, opDigests, signature);

        assertEq(counter.number(), 23);
    }
}
