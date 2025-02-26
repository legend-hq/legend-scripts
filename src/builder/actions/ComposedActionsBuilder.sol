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
import {Arrays} from "src/builder/lib/Arrays.sol";

contract ComposedActionsBuilder is QuarkBuilderBase {
    function swapAndSupply(
        SwapAndSupplyIntent memory intent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        PaymentInfo.Payment memory payment =
            Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, intent.paymentAssetSymbol);

        uint256[] memory swapAmountOuts = Arrays.uintArray(intent.swapIntent.sellAmount);
        string[] memory swapAssetSymbolOuts = Arrays.stringArray(
            Accounts.findAssetPositions(intent.swapIntent.sellToken, intent.swapIntent.chainId, chainAccountsList)
                .symbol
        );
        uint256[] memory supplyAmountOuts = Arrays.uintArray(intent.supplyIntent.amount);
        string[] memory supplyAssetSymbolOuts = Arrays.stringArray(intent.supplyIntent.assetSymbol);

        ActionIntent[] memory actionIntents = new ActionIntent[](2);
        actionIntents[0] = ActionIntent({
            actor: intent.swapIntent.sender,
            amountOuts: swapAmountOuts,
            assetSymbolOuts: swapAssetSymbolOuts,
            actionType: Actions.ACTION_TYPE_SWAP,
            intent: abi.encode(intent.swapIntent),
            blockTimestamp: intent.blockTimestamp,
            chainId: intent.swapIntent.chainId,
            preferAcross: intent.preferAcross
        });
        actionIntents[1] = ActionIntent({
            actor: intent.supplyIntent.sender,
            amountOuts: supplyAmountOuts,
            assetSymbolOuts: supplyAssetSymbolOuts,
            actionType: Actions.ACTION_TYPE_SUPPLY,
            intent: abi.encode(intent.supplyIntent),
            blockTimestamp: intent.blockTimestamp,
            chainId: intent.supplyIntent.chainId,
            preferAcross: intent.preferAcross
        });

        (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray) =
        constructOperationsAndActions({
            actionIntents: actionIntents,
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
