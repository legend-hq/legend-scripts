// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {BuilderPackHelper} from "./BuilderPackHelper.sol";
import {Strings} from "./Strings.sol";

library PaymentInfo {
    string constant PAYMENT_METHOD_OFFCHAIN = "OFFCHAIN";
    string constant PAYMENT_METHOD_PAYCALL = "PAY_CALL";
    string constant PAYMENT_METHOD_QUOTEPAY = "QUOTE_PAY";
    address constant NON_TOKEN_PAYMENT = address(0);

    error NoKnownPaymentToken(uint256 chainId);
    error MaxCostMissingForChain(uint256 chainId);

    struct Payment {
        // Note: Payment `currency` should be the same across chains
        string currency;
        // Note: If quote is not specified for a chain when paying with token, then that chain is ignored
        bytes32 quoteId;
        // TODO: Rename to something more fitting (e.g. `quote`)
        ChainCost[] chainCosts;
    }

    struct ChainCost {
        uint256 chainId;
        uint256 amount;
    }

    struct PaymentToken {
        uint256 chainId;
        string symbol;
        address token;
        address priceFeed;
    }

    function knownToken(string memory tokenSymbol, uint256 chainId) internal pure returns (PaymentToken memory) {
        (string memory addressResult, address tokenAddress) = BuilderPackHelper.knownAssetAddress(tokenSymbol, chainId);
        string memory symbol = Strings.stringEqIgnoreCase("USDC", tokenSymbol) ? "USD" : tokenSymbol;
        (string memory priceFeedResult, address priceFeed) =
            BuilderPackHelper.knownPriceFeedAddress("ETH", symbol, chainId);

        if (Strings.isError(addressResult) || Strings.isError(priceFeedResult)) {
            revert NoKnownPaymentToken(chainId);
        }

        return PaymentToken({chainId: chainId, symbol: tokenSymbol, token: tokenAddress, priceFeed: priceFeed});
    }

    function findCostForChain(Payment memory payment, uint256 chainId) internal pure returns (uint256) {
        for (uint256 i = 0; i < payment.chainCosts.length; ++i) {
            if (payment.chainCosts[i].chainId == chainId) {
                return payment.chainCosts[i].amount;
            }
        }
        revert MaxCostMissingForChain(chainId);
    }

    function totalCost(Payment memory payment, uint256[] memory chainIds) internal pure returns (uint256) {
        uint256 total;
        for (uint256 i = 0; i < chainIds.length; ++i) {
            total += PaymentInfo.findCostForChain(payment, chainIds[i]);
        }
        return total;
    }

    function hasCostForChain(Payment memory payment, uint256 chainId) internal pure returns (bool) {
        for (uint256 i = 0; i < payment.chainCosts.length; ++i) {
            if (payment.chainCosts[i].chainId == chainId) {
                return true;
            }
        }
        return false;
    }

    function isOffchainPayment(Payment memory payment) internal pure returns (bool) {
        return Strings.stringEqIgnoreCase("USD", payment.currency);
    }

    function paymentMethodForPayment(PaymentInfo.Payment memory payment, bool isRecurring)
        internal
        pure
        returns (string memory)
    {
        if (isOffchainPayment(payment)) {
            return PAYMENT_METHOD_OFFCHAIN;
        } else if (isRecurring) {
            return PAYMENT_METHOD_PAYCALL;
        } else {
            return PAYMENT_METHOD_QUOTEPAY;
        }
    }
}
