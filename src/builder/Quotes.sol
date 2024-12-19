// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {Accounts} from "src/builder/Accounts.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {Strings} from "src/builder/Strings.sol";
import {Math} from "src/lib/Math.sol";

library Quotes {
    string public constant OP_TYPE_BASELINE = "BASELINE";

    error NoKnownAssetQuote(string symbol);

    struct Quote {
        bytes32 quoteId;
        uint256 issuedAt;
        uint256 expiresAt;
        AssetQuote[] assetQuotes;
        NetworkOperationFee[] networkOperationFees;
    }

    struct AssetQuote {
        string symbol;
        uint256 price;
    }

    struct NetworkOperationFee {
        uint256 chainId;
        string opType;
        uint256 price;
    }

    function getPaymentFromQuotesAndSymbol(
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quote memory quote,
        string memory symbol
    ) internal pure returns (PaymentInfo.Payment memory) {
        if (Strings.stringEqIgnoreCase(symbol, "USD")) {
            return PaymentInfo.Payment({
                currency: symbol,
                quoteId: quote.quoteId,
                chainCosts: new PaymentInfo.ChainCost[](0)
            });
        }

        AssetQuote memory assetQuote;
        bool assetQuoteFound = false;

        for (uint256 i = 0; i < quote.assetQuotes.length; ++i) {
            if (Strings.stringEqIgnoreCase(symbol, quote.assetQuotes[i].symbol)) {
                assetQuote = quote.assetQuotes[i];
                assetQuoteFound = true;
            }
        }

        if (!assetQuoteFound) {
            revert NoKnownAssetQuote(symbol);
        }

        PaymentInfo.ChainCost[] memory chainCosts = new PaymentInfo.ChainCost[](quote.networkOperationFees.length);

        for (uint256 i = 0; i < quote.networkOperationFees.length; ++i) {
            NetworkOperationFee memory networkOperationFee = quote.networkOperationFees[i];

            Accounts.ChainAccounts memory chainAccountListByChainId =
                Accounts.findChainAccounts(networkOperationFee.chainId, chainAccountsList);

            Accounts.AssetPositions memory singularAssetPositionsForSymbol =
                Accounts.findAssetPositions(symbol, chainAccountListByChainId.assetPositionsList);

            chainCosts[i] = PaymentInfo.ChainCost({
                chainId: networkOperationFee.chainId,
                amount: (networkOperationFee.price * (10 ** singularAssetPositionsForSymbol.decimals))
                    / Math.subtractFlooredAtOne(assetQuote.price, 1)
            });
        }

        return PaymentInfo.Payment({currency: symbol, quoteId: quote.quoteId, chainCosts: chainCosts});
    }
}
