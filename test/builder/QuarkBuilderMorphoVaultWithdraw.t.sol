// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {Arrays} from "test/builder/lib/Arrays.sol";
import {Accounts, PaymentInfo, QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";
import {MorphoVaultActionsBuilder} from "src/builder/actions/MorphoVaultActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {CometWithdrawActions, TransferActions} from "src/DeFiScripts.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {MorphoVaultActions} from "src/MorphoScripts.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {Multicall} from "src/Multicall.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderMorphoVaultWithdrawTest is Test, QuarkBuilderTest {
    function morphoWithdrawIntent_(
        uint256 chainId,
        uint256 amount,
        string memory assetSymbol,
        string memory paymentAssetSymbol
    ) internal pure returns (MorphoVaultActionsBuilder.MorphoVaultWithdrawIntent memory) {
        return morphoWithdrawIntent_({
            amount: amount,
            assetSymbol: assetSymbol,
            chainId: chainId,
            withdrawer: address(0xa11ce),
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function morphoWithdrawIntent_(
        uint256 chainId,
        uint256 amount,
        string memory assetSymbol,
        address withdrawer,
        string memory paymentAssetSymbol
    ) internal pure returns (MorphoVaultActionsBuilder.MorphoVaultWithdrawIntent memory) {
        return MorphoVaultActionsBuilder.MorphoVaultWithdrawIntent({
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: BLOCK_TIMESTAMP,
            chainId: chainId,
            withdrawer: withdrawer,
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    // XXX test that you have enough of the asset to withdraw

    function testMorphoVaultWithdraw() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoVaultWithdraw(
            morphoWithdrawIntent_(1, 2e6, "USDC", "USD"),
            chainAccountsList_(2e6), // holding 2 USDC in total across 1, 8453
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(MorphoVaultActions.withdraw, (MorphoInfo.getMorphoVaultAddress(1, "USDC"), 2e6)),
            "calldata is MorphoVaultActions.withdraw(MorphoInfo.getMorphoVaultAddress(1, USDC), 2e6);"
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
        assertEq(result.actions[0].actionType, "MORPHO_VAULT_WITHDRAW", "action type is 'MORPHO_VAULT_WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoVaultWithdrawActionContext({
                    amount: 2e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    morphoVault: MorphoInfo.getMorphoVaultAddress(1, "USDC"),
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoVaultWithdrawWithQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        QuarkBuilder.BuilderResult memory result = builder.morphoVaultWithdraw(
            morphoWithdrawIntent_(1, 2e6, "USDC", "USDC"), chainAccountsList_(3e6), quote_(networkOperationFees)
        );

        address morphoVaultActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode);
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
        callContracts[0] = morphoVaultActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            MorphoVaultActions.withdraw.selector, MorphoInfo.getMorphoVaultAddress(1, "USDC"), 2e6
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoVaultActionsAddress, quotePayAddress], [MorphoVaultActions.withdraw(MorphoInfo.getMorphoVaultAddress(1, USDC), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
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
        assertEq(result.actions[0].actionType, "MORPHO_VAULT_WITHDRAW", "action type is 'MORPHO_VAULT_WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoVaultWithdrawActionContext({
                    amount: 2e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    morphoVault: MorphoInfo.getMorphoVaultAddress(1, "USDC"),
                    price: USDC_PRICE,
                    token: USDC_1
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

    function testMorphoVaultWithdrawPayFromWithdraw() public {
        QuarkBuilder builder = new QuarkBuilder();

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.5e8});

        QuarkBuilder.BuilderResult memory result = builder.morphoVaultWithdraw(
            morphoWithdrawIntent_(1, 2e6, "USDC", "USDC"), chainAccountsList_(0), quote_(networkOperationFees)
        );

        address morphoVaultActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode);
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
        callContracts[0] = morphoVaultActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            MorphoVaultActions.withdraw.selector, MorphoInfo.getMorphoVaultAddress(1, "USDC"), 2e6
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.5e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoVaultActionsAddress, quotePayAddress], [MorphoVaultWithdrawActions.withdraw(MorphoInfo.getMorphoVaultAddress(1, USDC), 2e6), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.5e6, QUOTE_ID)]);"
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
        assertEq(result.actions[0].actionType, "MORPHO_VAULT_WITHDRAW", "action type is 'MORPHO_VAULT_WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoVaultWithdrawActionContext({
                    amount: 2e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    morphoVault: MorphoInfo.getMorphoVaultAddress(1, "USDC"),
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoVaultWithdrawMax() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        MorphoVaultPortfolio[] memory morphoVaultPortfolios = new MorphoVaultPortfolio[](1);
        morphoVaultPortfolios[0] = MorphoVaultPortfolio({
            assetSymbol: "USDC",
            balance: 5e6,
            vault: MorphoInfo.getMorphoVaultAddress(1, "USDC")
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: morphoVaultPortfolios
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoVaultWithdraw(
            morphoWithdrawIntent_(1, type(uint256).max, "USDC", "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios), // user has no assets
            quote_(networkOperationFees) // but will pay from withdrawn funds
        );

        address morphoVaultActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode);
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
        callContracts[0] = morphoVaultActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            MorphoVaultActions.withdraw.selector, MorphoInfo.getMorphoVaultAddress(1, "USDC"), type(uint256).max
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoVaultActionsAddress, quotePayAddress], [MorphoVaultActions.redeemAll(MorphoInfo.getMorphoVaultAddress(1, USDC)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
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
        assertEq(result.actions[0].actionType, "MORPHO_VAULT_WITHDRAW", "action type is 'MORPHO_VAULT_WITHDRAW'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoVaultWithdrawActionContext({
                    amount: type(uint256).max,
                    assetSymbol: "USDC",
                    chainId: 1,
                    morphoVault: MorphoInfo.getMorphoVaultAddress(1, "USDC"),
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from WithdrawActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoVaultWithdrawMaxRevertsMaxCostTooHigh() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 100e8}); // operation cost is very high

        MorphoVaultPortfolio[] memory morphoVaultPortfolios = new MorphoVaultPortfolio[](1);
        morphoVaultPortfolios[0] = MorphoVaultPortfolio({
            assetSymbol: "USDC",
            balance: 5e6,
            vault: MorphoInfo.getMorphoVaultAddress(1, "USDC")
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: morphoVaultPortfolios
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
                100e6
            )
        );
        builder.morphoVaultWithdraw(
            morphoWithdrawIntent_(1, type(uint256).max, "USDC", "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees) // user will pay for transaction with withdrawn funds, but it is not enough
        );
    }
}
