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

contract MorphoVaultActionsBuilder is QuarkBuilderBase {
    function morphoVaultSupply(
        MorphoVaultSupplyIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory amountsNeeded = new uint256[](1);
        amountsNeeded[0] = intent.amount;
        string[] memory assetSymbolsNeeded = new string[](1);
        assetSymbolsNeeded[0] = intent.assetSymbol;

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.sender,
                amountsNeeded: amountsNeeded,
                assetSymbolsNeeded: assetSymbolsNeeded,
                actionType: Actions.ACTION_TYPE_MORPHO_VAULT_SUPPLY,
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

    function morphoVaultWithdraw(
        MorphoVaultWithdrawIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        // XXX confirm that you actually have the amount to withdraw

        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory amountsNeeded = new uint256[](0);
        string[] memory assetSymbolsNeeded = new string[](0);

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntent: ActionIntent({
                actor: intent.withdrawer,
                amountsNeeded: amountsNeeded,
                assetSymbolsNeeded: assetSymbolsNeeded,
                actionType: Actions.ACTION_TYPE_MORPHO_VAULT_WITHDRAW,
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
