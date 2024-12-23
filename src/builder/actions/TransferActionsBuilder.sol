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
    function transfer(
        QuarkBuilderBase.TransferIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
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
            actionIntent: ConstructActionIntent({
                actor: intent.sender,
                amountIns: amountIns,
                assetSymbolIns: assetSymbolIns,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                actionType: Actions.ACTION_TYPE_TRANSFER,
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
