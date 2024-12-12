// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {Arrays} from "test/builder/lib/Arrays.sol";
import {Accounts, PaymentInfo, QuarkBuilder, QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {CometActionsBuilder} from "src/builder/actions/CometActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {CometWithdrawActions, TransferActions} from "src/DeFiScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderCometWithdrawTest is Test, QuarkBuilderTest {
    function cometWithdraw_(
        uint256 chainId,
        address comet,
        string memory assetSymbol,
        uint256 amount,
        string memory paymentAssetSymbol
    ) internal pure returns (CometActionsBuilder.CometWithdrawIntent memory) {
        return CometActionsBuilder.CometWithdrawIntent({
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: BLOCK_TIMESTAMP,
            chainId: chainId,
            comet: comet,
            withdrawer: address(0xa11ce),
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    // XXX test that you have enough of the asset to withdraw

    function testCometWithdraw() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "LINK", 1e18, "USD"),
            chainAccountsList_(2e6), // holding 2 USDC in total across 1, 8453
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                /* codeJar address */
                                address(CodeJarHelper.CODE_JAR_ADDRESS),
                                uint256(0),
                                /* script bytecode */
                                keccak256(type(CometWithdrawActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(CometWithdrawActions.withdraw, (cometUsdc_(1), link_(1), 1e18)),
            "calldata is CometWithdrawActions.withdraw(cometUsdc_(1), LINK_1, 1e18);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainId 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "WITHDRAW", "action type is 'WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.WithdrawActionContext({
                    amount: 1e18,
                    assetSymbol: "LINK",
                    chainId: 1,
                    comet: cometUsdc_(1),
                    price: LINK_PRICE,
                    token: link_(1)
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometWithdrawWithQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        QuarkBuilder.BuilderResult memory result = builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "LINK", 1e18, "USDC"),
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
            quote_(networkOperationFees)
        );

        address cometWithdrawActionsAddress = CodeJarHelper.getCodeAddress(type(CometWithdrawActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometWithdrawActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(CometWithdrawActions.withdraw.selector, cometUsdc_(1), link_(1), 1e18);
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometWithdrawActionsAddress, quotePayAddress], [CometWithdrawActions.withdraw(cometUsdc_(1), LINK_1, 1e18), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "WITHDRAW", "action type is 'WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.WithdrawActionContext({
                    amount: 1e18,
                    assetSymbol: "LINK",
                    chainId: 1,
                    comet: cometUsdc_(1),
                    price: LINK_PRICE,
                    token: link_(1)
                })
            ),
            "action context encoded from WithdrawActionContext"
        );
        assertEq(
            result.actions[0].quotePayActionContext,
            abi.encode(
                Actions.QuotePayActionContext({
                    amount: 0.1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    price: USDC_PRICE,
                    token: USDC_1,
                    payee: Actions.QUOTE_PAY_RECIPIENT,
                    quoteId: QUOTE_ID
                })
            ),
            "action context encoded from QuotePayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometWithdrawPayFromWithdraw() public {
        QuarkBuilder builder = new QuarkBuilder();

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.5e8});

        QuarkBuilder.BuilderResult memory result = builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "USDC", 1e6, "USDC"), // user will be withdrawing 1 USDC
            chainAccountsList_(0), // and has no additional USDC balance
            quote_(networkOperationFees)
        );

        address cometWithdrawActionsAddress = CodeJarHelper.getCodeAddress(type(CometWithdrawActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometWithdrawActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(CometWithdrawActions.withdraw.selector, cometUsdc_(1), usdc_(1), 1e6);
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.5e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometWithdrawActionsAddress, quotePayAddress], [CometWithdrawActions.withdraw(COMET, USDC_1, 1e6), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.5e6, QUOTE_ID)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "WITHDRAW", "action type is 'WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.WithdrawActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    comet: cometUsdc_(1),
                    price: USDC_PRICE,
                    token: usdc_(1)
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometWithdrawMax() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 1e6,
            baseBorrowed: 0,
            collateralAssetSymbols: Arrays.stringArray("LINK"),
            collateralAssetBalances: Arrays.uintArray(0)
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "USDC", type(uint256).max, "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios), // user has no assets
            quote_(networkOperationFees)
        );

        address cometWithdrawActionsAddress = CodeJarHelper.getCodeAddress(type(CometWithdrawActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometWithdrawActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] =
            abi.encodeWithSelector(CometWithdrawActions.withdraw.selector, cometUsdc_(1), usdc_(1), type(uint256).max);
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometWithdrawActionsAddress, quotePayAddress], [CometWithdrawActions.withdraw(COMET, USDC_1, uint256.max), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainId 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "WITHDRAW", "action type is 'WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.WithdrawActionContext({
                    amount: type(uint256).max,
                    assetSymbol: "USDC",
                    chainId: 1,
                    comet: cometUsdc_(1),
                    price: USDC_PRICE,
                    token: usdc_(1)
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometWithdrawMaxRevertsMaxCostTooHigh() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 100e8}); // operation cost is very high

        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 1e6,
            baseBorrowed: 0,
            collateralAssetSymbols: Arrays.stringArray("LINK"),
            collateralAssetBalances: Arrays.uintArray(0)
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();

        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                QuarkBuilderBase.GenerateQuotePayStatus.ImpossibleToConstruct,
                "USDC",
                100000000
            )
        );
        builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "USDC", type(uint256).max, "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees) // user will pay for transaction with withdrawn funds, but it is not enough
        );
    }

    function testCometWithdrawCostTooHigh() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](3);
        networkOperationFees[0] = Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 5e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 5e8});
        networkOperationFees[2] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 7777, price: 5e8});

        QuarkBuilder builder = new QuarkBuilder();

        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                QuarkBuilderBase.GenerateQuotePayStatus.ImpossibleToConstruct,
                "USDC",
                10e6
            )
        );
        builder.cometWithdraw(
            cometWithdraw_(1, cometUsdc_(1), "USDC", 1e6, "USDC"),
            chainAccountsList_(0e6),
            quote_(networkOperationFees) // user will pay for transaction with withdrawn funds, but it is not enough
        );
    }
}
