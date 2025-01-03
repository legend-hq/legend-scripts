// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {Accounts} from "src/builder/Accounts.sol";
import {BridgeRoutes} from "src/builder/BridgeRoutes.sol";
import {EIP712Helper} from "src/builder/EIP712Helper.sol";
import {Math} from "src/lib/Math.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {Strings} from "src/builder/Strings.sol";
import {PaycallWrapper} from "src/builder/PaycallWrapper.sol";
import {QuotecallWrapper} from "src/builder/QuotecallWrapper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {QuarkOperationHelper} from "src/builder/QuarkOperationHelper.sol";
import {Quotes} from "src/builder/Quotes.sol";
import {List} from "src/builder/List.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";

contract CometActionsBuilder is QuarkBuilderBase {
    function cometRepay(
        CometRepayIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */ ) {
        if (intent.collateralAmounts.length != intent.collateralAssetSymbols.length) {
            revert InvalidInput();
        }

        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256 repayAmount;
        if (intent.amount == type(uint256).max) {
            uint256 maxRepayAmount =
                cometRepayMaxAmount(chainAccountsList, intent.chainId, intent.comet, intent.repayer);
            uint256 availableAssetBalance = Accounts.totalAvailableAsset(intent.assetSymbol, chainAccountsList, payment);
            repayAmount = maxRepayAmount < availableAssetBalance ? maxRepayAmount : type(uint256).max;
        } else {
            repayAmount = intent.amount;
        }

        uint256[] memory amountOuts = new uint256[](1);
        amountOuts[0] = repayAmount;
        string[] memory assetSymbolOuts = new string[](1);
        assetSymbolOuts[0] = intent.assetSymbol;
        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.repayer,
                amountIns: intent.collateralAmounts,
                assetSymbolIns: intent.collateralAssetSymbols,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_REPAY,
                intent: abi.encode(intent),
                blockTimestamp: intent.blockTimestamp,
                chainId: intent.chainId,
                preferAcross: intent.preferAcross
            }),
            chainAccountsList: chainAccountsList,
            payment: payment
        });

        return BuilderResult({
            version: VERSION,
            actions: actionsArray,
            quarkOperations: quarkOperationsArray,
            paymentCurrency: payment.currency,
            eip712Data: EIP712Helper.eip712DataForQuarkOperations(quarkOperationsArray, actionsArray)
        });
    }

    function cometBorrow(
        CometBorrowIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */ ) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        if (intent.collateralAmounts.length != intent.collateralAssetSymbols.length) {
            revert InvalidInput();
        }

        uint256[] memory amountIns = new uint256[](1);
        amountIns[0] = intent.amount;
        string[] memory assetSymbolIns = new string[](1);
        assetSymbolIns[0] = intent.assetSymbol;

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.borrower,
                amountIns: amountIns,
                assetSymbolIns: assetSymbolIns,
                amountOuts: intent.collateralAmounts,
                assetSymbolOuts: intent.collateralAssetSymbols,
                actionType: Actions.ACTION_TYPE_BORROW,
                intent: abi.encode(intent),
                blockTimestamp: intent.blockTimestamp,
                chainId: intent.chainId,
                preferAcross: intent.preferAcross
            }),
            chainAccountsList: chainAccountsList,
            payment: payment
        });

        return BuilderResult({
            version: VERSION,
            actions: actionsArray,
            quarkOperations: quarkOperationsArray,
            paymentCurrency: payment.currency,
            eip712Data: EIP712Helper.eip712DataForQuarkOperations(quarkOperationsArray, actionsArray)
        });
    }

    function cometSupply(
        CometSupplyIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */ ) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory amountOuts = new uint256[](1);
        amountOuts[0] = intent.amount;
        string[] memory assetSymbolOuts = new string[](1);
        assetSymbolOuts[0] = intent.assetSymbol;
        uint256[] memory amountIns = new uint256[](0);
        string[] memory assetSymbolIns = new string[](0);

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.sender,
                amountIns: amountIns,
                assetSymbolIns: assetSymbolIns,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_SUPPLY,
                intent: abi.encode(intent),
                blockTimestamp: intent.blockTimestamp,
                chainId: intent.chainId,
                preferAcross: intent.preferAcross
            }),
            chainAccountsList: chainAccountsList,
            payment: payment
        });

        return BuilderResult({
            version: VERSION,
            actions: actionsArray,
            quarkOperations: quarkOperationsArray,
            paymentCurrency: payment.currency,
            eip712Data: EIP712Helper.eip712DataForQuarkOperations(quarkOperationsArray, actionsArray)
        });
    }

    function cometWithdraw(
        CometWithdrawIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        // XXX confirm that you actually have the amount to withdraw
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256 actualWithdrawAmount = intent.amount;
        if (intent.amount == type(uint256).max) {
            // When doing a max withdraw, we need to find the actual approximate amount instead of using uint256 max
            actualWithdrawAmount =
                cometWithdrawMaxAmount(chainAccountsList, intent.chainId, intent.comet, intent.withdrawer);
        }

        uint256[] memory amountIns = new uint256[](1);
        amountIns[0] = actualWithdrawAmount;
        string[] memory assetSymbolIns = new string[](1);
        assetSymbolIns[0] = intent.assetSymbol;
        uint256[] memory amountOuts = new uint256[](0);
        string[] memory assetSymbolOuts = new string[](0);

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.withdrawer,
                amountIns: amountIns,
                assetSymbolIns: assetSymbolIns,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_WITHDRAW,
                intent: abi.encode(intent),
                blockTimestamp: intent.blockTimestamp,
                chainId: intent.chainId,
                preferAcross: intent.preferAcross
            }),
            chainAccountsList: chainAccountsList,
            payment: payment
        });

        return BuilderResult({
            version: VERSION,
            actions: actionsArray,
            quarkOperations: quarkOperationsArray,
            paymentCurrency: payment.currency,
            eip712Data: EIP712Helper.eip712DataForQuarkOperations(quarkOperationsArray, actionsArray)
        });
    }
}
