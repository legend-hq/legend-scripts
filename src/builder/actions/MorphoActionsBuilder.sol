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
import {List} from "src/builder/List.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract MorphoActionsBuilder is QuarkBuilderBase {
    function morphoBorrow(
        MorphoBorrowIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory amountOuts = new uint256[](1);
        amountOuts[0] = intent.collateralAmount;
        string[] memory assetSymbolOuts = new string[](1);
        assetSymbolOuts[0] = intent.collateralAssetSymbol;

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.borrower,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_MORPHO_BORROW,
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

    function morphoRepay(
        MorphoRepayIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256 repayAmount;
        if (intent.amount == type(uint256).max) {
            uint256 maxRepayAmount = morphoRepayMaxAmount(
                chainAccountsList,
                intent.chainId,
                Accounts.findAssetPositions(intent.assetSymbol, intent.chainId, chainAccountsList).asset,
                Accounts.findAssetPositions(intent.collateralAssetSymbol, intent.chainId, chainAccountsList).asset,
                intent.repayer
            );
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
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_MORPHO_REPAY,
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

    function morphoClaimRewards(
        MorphoRewardsClaimIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        if (
            intent.accounts.length != intent.claimables.length || intent.accounts.length != intent.distributors.length
                || intent.accounts.length != intent.rewards.length || intent.accounts.length != intent.proofs.length
        ) {
            revert InvalidInput();
        }

        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory amountOuts = new uint256[](0);
        string[] memory assetSymbolOuts = new string[](0);
        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.claimer,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_MORPHO_CLAIM_REWARDS,
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
