// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";

import {Accounts} from "src/builder/Accounts.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {Quotes} from "src/builder/Quotes.sol";

import {QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";

contract QuotesTest is Test, QuarkBuilderTest {
    function testConvertingQuotesToPayment() public {
        Accounts.ChainAccounts[] memory chainAccountsList = chainAccountsList_(6e6);
        Quotes.AssetQuote memory assetQuote = Quotes.AssetQuote({symbol: "USDC", price: 1e8});

        Quotes.AssetQuote[] memory assetQuotes = new Quotes.AssetQuote[](1);
        assetQuotes[0] = assetQuote;

        Quotes.NetworkOperationFee memory networkOperationFee =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 3e6});

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] = networkOperationFee;

        bytes32 quoteId = 0xdeadbeef00000000000000000000000000000000000000000000000000000000;
        Quotes.Quote memory quote = Quotes.Quote({
            quoteId: quoteId,
            issuedAt: 1704067200,
            expiresAt: 1704069200,
            assetQuotes: assetQuotes,
            networkOperationFees: networkOperationFees
        });
        string memory symbol = "USDC";
        PaymentInfo.Payment memory result = Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, symbol);

        assertEq(result.currency, symbol, "currency is set to passed in symbol");
        assertEq(result.quoteId, quote.quoteId, "quoteId is set to quiteId from quote");
        assertEq(
            result.chainCosts[0].chainId, networkOperationFee.chainId, "chainId is set to networkOperationFee chainId"
        );
        assertEq(result.chainCosts[0].amount, 3e4, "amount is set to networkOperationFee in units of token");
    }

    function testConvertingQuotesToPaymentForUsd() public {
        Accounts.ChainAccounts[] memory chainAccountsList = chainAccountsList_(6e6);
        Quotes.AssetQuote memory assetQuote = Quotes.AssetQuote({symbol: "USDC", price: 1e8});

        Quotes.AssetQuote[] memory assetQuotes = new Quotes.AssetQuote[](1);
        assetQuotes[0] = assetQuote;

        Quotes.NetworkOperationFee memory networkOperationFee =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 3e6});

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] = networkOperationFee;

        bytes32 quoteId = 0xdeadbeef00000000000000000000000000000000000000000000000000000000;
        Quotes.Quote memory quote = Quotes.Quote({
            quoteId: quoteId,
            issuedAt: 1704067200,
            expiresAt: 1704069200,
            assetQuotes: assetQuotes,
            networkOperationFees: networkOperationFees
        });
        string memory symbol = "USD";
        PaymentInfo.Payment memory result = Quotes.getPaymentFromQuotesAndSymbol(chainAccountsList, quote, symbol);

        assertEq(result.currency, symbol, "currency is set to passed in symbol");
        assertEq(result.quoteId, quote.quoteId, "quoteId is set to quiteId from quote");
        assertEq(result.chainCosts.length, 0, "chainCosts are not set");
    }
}
