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

import {Ethcall} from "src/Ethcall.sol";
import {Multicall} from "src/Multicall.sol";
import {PoolAddress} from "src/vendor/uniswap-v3-periphery/PoolAddress.sol";
import {UniswapFlashLoan} from "src/UniswapFlashLoan.sol";

import {Counter} from "./lib/Counter.sol";

import {YulHelper} from "./lib/YulHelper.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {QuarkOperationHelper, ScriptType} from "./lib/QuarkOperationHelper.sol";

import {IComet} from "src/interfaces/IComet.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

contract UniswapFlashLoanTest is Test {
    QuarkWalletProxyFactory public factory;
    // For signature to QuarkWallet
    uint256 alicePrivateKey = 0xa11ce;
    address alice = vm.addr(alicePrivateKey);

    // Comet address in mainnet
    address constant comet = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // Router info on mainnet
    address constant uniswapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    bytes multicall = new YulHelper().getCode("Multicall.sol/Multicall.json");
    bytes ethcall = new YulHelper().getCode("Ethcall.sol/Ethcall.json");
    bytes uniswapFlashLoan = new YulHelper().getCode("UniswapFlashLoan.sol/UniswapFlashLoan.json");
    address ethcallAddress;
    address multicallAddress;
    address uniswapFlashLoanAddress;

    function setUp() public {
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            18429607 // 2023-10-25 13:24:00 PST
        );
        factory = new QuarkWalletProxyFactory(address(new QuarkWallet(new CodeJar(), new QuarkNonceManager())));
        CodeJar codeJar = QuarkWallet(payable(factory.walletImplementation())).codeJar();
        ethcallAddress = codeJar.saveCode(ethcall);
        multicallAddress = codeJar.saveCode(multicall);
        uniswapFlashLoanAddress = codeJar.saveCode(uniswapFlashLoan);
    }

    function testFlashLoanForCollateralSwapOnCompound() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Set up some funds for test
        deal(WETH, address(wallet), 100 ether);
        // Set up compound position via prank
        vm.startPrank(address(wallet));
        // Approve Comet to spend WETH
        IERC20(WETH).approve(comet, 100 ether);
        // Supply WETH to Comet
        IComet(comet).supply(WETH, 2 ether);
        // Withdraw USDC from Comet
        IComet(comet).withdraw(USDC, 1000e6);
        // Transfer all USDC out to null address so test wallet will need to use flashloan to pay off debt
        // Leave only 1 USDC to repay flash loan fee
        IERC20(USDC).transfer(address(123), 999e6);
        vm.stopPrank();

        // Test user can switch collateral from WETH to LINK via flashloan without allocating USDC to pay off debt
        // Math here is not perfect. Terminal scripts should be able to compute more precise numbers
        address[] memory callContracts = new address[](8);
        bytes[] memory callDatas = new bytes[](8);

        // Use 90% of price calculation to account for price slippage during swapping
        uint256 linkBalanceEst = 2e18 * IComet(comet).getPrice(IComet(comet).getAssetInfoByAddress(WETH).priceFeed)
            / IComet(comet).getPrice(IComet(comet).getAssetInfoByAddress(LINK).priceFeed) * 9 / 10;

        // Approve Comet to spend USDC
        callContracts[0] = ethcallAddress;
        callDatas[0] =
            abi.encodeWithSelector(Ethcall.run.selector, USDC, abi.encodeCall(IERC20.approve, (comet, 1000e6)), 0);

        // Use flashloan usdc to pay off comet debt (1000USDC)
        callContracts[1] = ethcallAddress;
        callDatas[1] =
            abi.encodeWithSelector(Ethcall.run.selector, comet, abi.encodeCall(IComet.supply, (USDC, 1000e6)), 0);

        // Withdraw all comet collateral (2 WETH)
        callContracts[2] = ethcallAddress;
        callDatas[2] =
            abi.encodeWithSelector(Ethcall.run.selector, comet, abi.encodeCall(IComet.withdraw, (WETH, 2 ether)), 0);

        // Approve uniswapRouter for WETH
        callContracts[3] = ethcallAddress;
        callDatas[3] = abi.encodeWithSelector(
            Ethcall.run.selector, WETH, abi.encodeCall(IERC20.approve, (uniswapRouter, 2 ether)), 0
        );

        // Swap 2 WETH for LINK via uniswapRouter
        callContracts[4] = ethcallAddress;
        callDatas[4] = abi.encodeWithSelector(
            Ethcall.run.selector,
            uniswapRouter,
            abi.encodeCall(
                ISwapRouter.exactInputSingle,
                (
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: WETH,
                        tokenOut: LINK,
                        fee: 3000, // 0.3%
                        recipient: address(wallet),
                        deadline: block.timestamp,
                        amountIn: 2 ether,
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                )
            ),
            0 // value
        );

        // Approve Comet for LINK
        callContracts[5] = ethcallAddress;
        callDatas[5] = abi.encodeWithSelector(
            Ethcall.run.selector,
            LINK,
            abi.encodeCall(IERC20.approve, (comet, type(uint256).max)),
            0 // value
        );

        // Supply LINK back to Comet
        callContracts[6] = ethcallAddress;
        callDatas[6] = abi.encodeWithSelector(
            Ethcall.run.selector,
            comet,
            abi.encodeCall(IComet.supply, (LINK, linkBalanceEst)),
            0 // value
        );

        // Withdraw 1000 USDC from Comet again to repay debt
        callContracts[7] = ethcallAddress;
        callDatas[7] = abi.encodeWithSelector(
            Ethcall.run.selector,
            comet,
            abi.encodeCall(IComet.withdraw, (USDC, 1000e6)),
            0 // value
        );

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(
                UniswapFlashLoan.run.selector,
                UniswapFlashLoan.UniswapFlashLoanPayload({
                    token0: USDC,
                    token1: DAI,
                    fee: 100,
                    amount0: 1000e6,
                    amount1: 0,
                    callContract: multicallAddress,
                    callData: abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas)
                })
            ),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);

        // Verify that user now has no WETH collateral on Comet, but only LINK
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), WETH), 0);
        assertEq(IComet(comet).collateralBalanceOf(address(wallet), LINK), linkBalanceEst);
        assertEq(IComet(comet).borrowBalanceOf(address(wallet)), 1000e6);
    }

    function testRevertsForSecondCallback() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));
        address[] memory callContracts = new address[](1);
        bytes[] memory callDatas = new bytes[](1);
        // Call into the wallet and try to execute the fallback function again using the callback mechanism
        callContracts[0] = address(wallet);
        callDatas[0] = abi.encodeWithSelector(
            Ethcall.run.selector,
            address(wallet),
            abi.encodeCall(UniswapFlashLoan.uniswapV3FlashCallback, (100, 500, bytes(""))),
            0
        );
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(
                UniswapFlashLoan.run.selector,
                UniswapFlashLoan.UniswapFlashLoanPayload({
                    token0: USDC,
                    token1: DAI,
                    fee: 100,
                    amount0: 1000e6,
                    amount1: 0,
                    callContract: multicallAddress,
                    callData: abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas)
                })
            ),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.resumeGasMetering();
        vm.expectRevert(
            abi.encodeWithSelector(
                Multicall.MulticallError.selector,
                0,
                callContracts[0],
                abi.encodeWithSelector(QuarkWallet.NoActiveCallback.selector)
            )
        );
        wallet.executeQuarkOperation(op, signature);
    }

    function testRevertsForInvalidCaller() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(WETH, address(wallet), 100 ether);
        deal(USDC, address(wallet), 1000e6);

        // Invoking the callback directly should revert as invalid caller
        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(
                UniswapFlashLoan.uniswapV3FlashCallback.selector,
                1000e6,
                1000e6,
                abi.encode(
                    UniswapFlashLoan.FlashLoanCallbackPayload({
                        amount0: 1 ether,
                        amount1: 0,
                        poolKey: PoolAddress.getPoolKey(WETH, USDC, 500),
                        callContract: address(0),
                        callData: hex""
                    })
                )
            ),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.expectRevert(abi.encodeWithSelector(UniswapFlashLoan.InvalidCaller.selector));
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
    }

    function testRevertsForInsufficientFundsToRepayFlashLoan() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        // Send USDC to random address
        UniswapFlashLoan.UniswapFlashLoanPayload memory payload = UniswapFlashLoan.UniswapFlashLoanPayload({
            token0: USDC,
            token1: DAI,
            fee: 100,
            amount0: 1000e6,
            amount1: 0,
            callContract: ethcallAddress,
            callData: abi.encodeWithSelector(
                Ethcall.run.selector, USDC, abi.encodeCall(IERC20.transfer, (address(1), 1000e6)), 0
            )
        });

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(UniswapFlashLoan.run.selector, payload),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op, signature);
    }

    function testTokensOrderInvariant() public {
        vm.pauseGasMetering();
        QuarkWallet wallet = QuarkWallet(factory.create(alice, address(0)));

        deal(USDC, address(wallet), 10_000e6);

        QuarkWallet.QuarkOperation memory op = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(
                UniswapFlashLoan.run.selector,
                UniswapFlashLoan.UniswapFlashLoanPayload({
                    token0: USDC,
                    token1: DAI,
                    fee: 100,
                    amount0: 10_000e6,
                    amount1: 0,
                    callContract: ethcallAddress,
                    callData: abi.encodeWithSelector(
                        Ethcall.run.selector, USDC, abi.encodeCall(IERC20.approve, (comet, 1000e6)), 0
                    )
                })
            ),
            ScriptType.ScriptAddress
        );
        bytes memory signature = new SignatureHelper().signOp(alicePrivateKey, wallet, op);
        wallet.executeQuarkOperation(op, signature);

        // Lose 1 USDC to flash loan fee
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 9999e6);

        QuarkWallet.QuarkOperation memory op2 = new QuarkOperationHelper().newBasicOpWithCalldata(
            wallet,
            uniswapFlashLoan,
            abi.encodeWithSelector(
                UniswapFlashLoan.run.selector,
                UniswapFlashLoan.UniswapFlashLoanPayload({
                    token0: DAI,
                    token1: USDC,
                    fee: 100,
                    amount0: 0,
                    amount1: 10_000e6,
                    callContract: ethcallAddress,
                    callData: abi.encodeWithSelector(
                        Ethcall.run.selector,
                        USDC,
                        abi.encodeCall(IERC20.approve, (comet, 1000e6)),
                        0 // value
                    )
                })
            ),
            ScriptType.ScriptAddress
        );
        bytes memory signature2 = new SignatureHelper().signOp(alicePrivateKey, wallet, op2);
        vm.resumeGasMetering();
        wallet.executeQuarkOperation(op2, signature2);

        // Lose 1 USDC to flash loan fee
        assertEq(IERC20(USDC).balanceOf(address(wallet)), 9998e6);
    }
}
