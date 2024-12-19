// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {console} from "src/builder/console.sol";
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
import {Quotes} from "src/builder/Quotes.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {QuarkOperationHelper} from "src/builder/QuarkOperationHelper.sol";
import {List} from "src/builder/List.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";

contract TransferActionsBuilder is QuarkBuilderBase {
    struct TransferIntent {
        uint256 chainId;
        string assetSymbol;
        uint256 amount;
        address sender;
        address recipient;
        uint256 blockTimestamp;
        bool preferAcross;
        string paymentAssetSymbol;
    }

    function transfer(
        TransferIntent memory transferIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, transferIntent.paymentAssetSymbol);

        List.DynamicArray memory actions = List.newList();
        List.DynamicArray memory quarkOperations = List.newList();
        bool hasBridgeError = false;

        (
            IQuarkWallet.QuarkOperation[] memory bridgeOperationsArray,
            Actions.Action[] memory bridgeActions,
            uint256 finalAmountOnDst,
            uint256 bridgeFees,
            uint256 supplementalBalance
        ) = getBridgeOperationsForAsset({
            chainId: transferIntent.chainId,
            assetSymbol: transferIntent.assetSymbol,
            amount: transferIntent.amount,
            recipient: transferIntent.sender,
            blockTimestamp: transferIntent.blockTimestamp,
            preferAcross: transferIntent.preferAcross,
            chainAccountsList: chainAccountsList,
            payment: payment
        });

        List.addQuarkOperations(quarkOperations, bridgeOperationsArray);
        List.addActions(actions, bridgeActions);

        // Convert transferIntent to user aggregated balance
        if (transferIntent.amount == type(uint256).max) {
            transferIntent.amount =
                Accounts.totalAvailableAsset(transferIntent.assetSymbol, chainAccountsList, payment) - bridgeFees;
        } else {
            hasBridgeError = finalAmountOnDst != transferIntent.amount;
        }

        checkAndInsertWrapOrUnwrapAction({
            actions: actions,
            quarkOperations: quarkOperations,
            chainAccountsList: chainAccountsList,
            payment: payment,
            assetSymbol: transferIntent.assetSymbol,
            amountNeeded: finalAmountOnDst,
            supplementalBalance: supplementalBalance,
            chainId: transferIntent.chainId,
            account: transferIntent.sender,
            blockTimestamp: transferIntent.blockTimestamp,
            isRecurring: false
        });

        // Then, transfer `amount` of `assetSymbol` to `recipient`
        (IQuarkWallet.QuarkOperation memory operation, Actions.Action memory action) = Actions.transferAsset(
            Actions.TransferAsset({
                chainAccountsList: chainAccountsList,
                assetSymbol: transferIntent.assetSymbol,
                amount: transferIntent.amount,
                chainId: transferIntent.chainId,
                sender: transferIntent.sender,
                recipient: transferIntent.recipient,
                blockTimestamp: transferIntent.blockTimestamp
            }),
            payment
        );

        List.addQuarkOperation(quarkOperations, operation);
        List.addAction(actions, action);

        string memory quotePayResult = Strings.OK;
        uint256 totalQuoteAmount;

        if (!PaymentInfo.isOffchainPayment(payment)) {
            (
                IQuarkWallet.QuarkOperation memory quotePayOperation,
                Actions.Action memory quotePayAction,
                string memory result,
                uint256 totalQuoteAmount_
            ) = generateQuotePayOperation(
                PaymentBalanceAssertionArgs({
                    actions: List.toActionArray(actions),
                    chainAccountsList: chainAccountsList,
                    targetChainId: transferIntent.chainId,
                    account: transferIntent.sender,
                    blockTimestamp: transferIntent.blockTimestamp,
                    payment: payment
                })
            );

            quotePayResult = result;
            totalQuoteAmount = totalQuoteAmount_;

            List.addQuarkOperation(quarkOperations, quotePayOperation);
            List.addAction(actions, quotePayAction);
        }

        if (hasBridgeError || !Strings.isOk(quotePayResult)) {
            revert UnableToConstructActionIntent(
                hasBridgeError,
                transferIntent.assetSymbol,
                bridgeFees,
                quotePayResult,
                payment.currency,
                totalQuoteAmount
            );
        }

        // Convert to array
        IQuarkWallet.QuarkOperation[] memory quarkOperationsArray = List.toQuarkOperationArray(quarkOperations);
        Actions.Action[] memory actionsArray = List.toActionArray(actions);

        // Merge operations that are from the same chain into one Multicall operation
        (quarkOperationsArray, actionsArray) =
            QuarkOperationHelper.mergeSameChainOperations(quarkOperationsArray, actionsArray);

        return BuilderResult({
            version: VERSION,
            actions: actionsArray,
            quarkOperations: quarkOperationsArray,
            paymentCurrency: payment.currency,
            eip712Data: EIP712Helper.eip712DataForQuarkOperations(quarkOperationsArray, actionsArray)
        });
    }
}
