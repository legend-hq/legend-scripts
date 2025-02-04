// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {console} from "src/builder/console.sol";

import {HashMap} from "src/builder/HashMap.sol";
import {List} from "src/builder/List.sol";
import {Math} from "src/lib/Math.sol";
import {PaymentInfo} from "./PaymentInfo.sol";
import {Strings} from "./Strings.sol";
import {PaymentInfo} from "./PaymentInfo.sol";
import {TokenWrapper} from "./TokenWrapper.sol";

library Accounts {
    error QuarkSecretNotFound(address account);
    error AssetPositionNotFound(string symbol);

    struct ChainAccounts {
        uint256 chainId;
        QuarkSecret[] quarkSecrets;
        AssetPositions[] assetPositionsList;
        CometPositions[] cometPositions;
        MorphoPositions[] morphoPositions;
        MorphoVaultPositions[] morphoVaultPositions;
    }

    struct QuarkSecret {
        address account;
        bytes32 nonceSecret;
    }

    // Similarly, this is designed to intentionally reduce the encoding burden for the client
    // by making it equivalent in structure to data already in portfolios.
    struct AssetPositions {
        address asset;
        string symbol;
        uint256 decimals;
        uint256 usdPrice;
        AccountBalance[] accountBalances;
    }

    struct AccountBalance {
        address account;
        uint256 balance;
    }

    struct CometPositions {
        address comet;
        CometBasePosition basePosition;
        CometCollateralPosition[] collateralPositions;
        CometReward[] cometRewards;
    }

    struct CometBasePosition {
        address asset;
        address[] accounts;
        uint256[] borrowed;
        uint256[] supplied;
    }

    struct CometCollateralPosition {
        address asset;
        address[] accounts;
        uint256[] balances;
    }

    struct CometReward {
        address asset;
        address rewardContract;
        address[] accounts;
        uint256[] rewardsOwed;
    }

    struct MorphoPositions {
        bytes32 marketId;
        address morpho;
        address loanToken;
        address collateralToken;
        MorphoBorrowPosition borrowPosition;
        MorphoCollateralPosition collateralPosition;
    }

    struct MorphoBorrowPosition {
        address[] accounts;
        uint256[] borrowed;
    }

    struct MorphoCollateralPosition {
        address[] accounts;
        uint256[] balances;
    }

    struct MorphoVaultPositions {
        address asset;
        address[] accounts;
        uint256[] balances;
        address vault;
    }

    function findChainAccounts(uint256 chainId, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (ChainAccounts memory found)
    {
        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            if (chainAccountsList[i].chainId == chainId) {
                return found = chainAccountsList[i];
            }
        }
    }

    function findCometPositions(uint256 chainId, address comet, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (CometPositions memory found)
    {
        ChainAccounts memory chainAccounts = findChainAccounts(chainId, chainAccountsList);
        for (uint256 i = 0; i < chainAccounts.cometPositions.length; ++i) {
            if (chainAccounts.cometPositions[i].comet == comet) {
                return found = chainAccounts.cometPositions[i];
            }
        }
    }

    function findMorphoPositions(
        uint256 chainId,
        address loanToken,
        address collateralToken,
        ChainAccounts[] memory chainAccountsList
    ) internal pure returns (MorphoPositions memory found) {
        ChainAccounts memory chainAccounts = findChainAccounts(chainId, chainAccountsList);
        for (uint256 i = 0; i < chainAccounts.morphoPositions.length; ++i) {
            if (
                chainAccounts.morphoPositions[i].loanToken == loanToken
                    && chainAccounts.morphoPositions[i].collateralToken == collateralToken
            ) {
                return found = chainAccounts.morphoPositions[i];
            }
        }
    }

    function findMorphoVaultPositions(uint256 chainId, address asset, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (MorphoVaultPositions memory found)
    {
        ChainAccounts memory chainAccounts = findChainAccounts(chainId, chainAccountsList);
        for (uint256 i = 0; i < chainAccounts.morphoVaultPositions.length; ++i) {
            if (chainAccounts.morphoVaultPositions[i].asset == asset) {
                return found = chainAccounts.morphoVaultPositions[i];
            }
        }
    }

    function findAssetPositions(string memory assetSymbol, AssetPositions[] memory assetPositionsList)
        internal
        pure
        returns (AssetPositions memory found)
    {
        for (uint256 i = 0; i < assetPositionsList.length; ++i) {
            if (Strings.stringEqIgnoreCase(assetSymbol, assetPositionsList[i].symbol)) {
                return found = assetPositionsList[i];
            }
        }
    }

    function findAssetPositions(string memory assetSymbol, uint256 chainId, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (AssetPositions memory found)
    {
        ChainAccounts memory chainAccounts = findChainAccounts(chainId, chainAccountsList);
        return findAssetPositions(assetSymbol, chainAccounts.assetPositionsList);
    }

    function findAssetPositions(address assetAddress, AssetPositions[] memory assetPositionsList)
        internal
        pure
        returns (AssetPositions memory found)
    {
        for (uint256 i = 0; i < assetPositionsList.length; ++i) {
            if (assetAddress == assetPositionsList[i].asset) {
                return found = assetPositionsList[i];
            }
        }
    }

    function findAssetPositions(address assetAddress, uint256 chainId, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (AssetPositions memory found)
    {
        ChainAccounts memory chainAccounts = findChainAccounts(chainId, chainAccountsList);
        return findAssetPositions(assetAddress, chainAccounts.assetPositionsList);
    }

    // Finds the first asset position for the given symbol in the chain accounts list
    function findFirstAssetPositions(string memory assetSymbol, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (AssetPositions memory found)
    {
        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            AssetPositions memory assetPositions =
                findAssetPositions(assetSymbol, chainAccountsList[i].assetPositionsList);
            if (assetPositions.asset != address(0)) {
                return assetPositions;
            }
        }

        revert AssetPositionNotFound(assetSymbol);
    }

    function getAssetInfo(address[] memory assetAddresses, Accounts.AssetPositions[] memory assetPositionsList)
        internal
        pure
        returns (string[] memory symbols, uint256[] memory prices)
    {
        symbols = new string[](assetAddresses.length);
        prices = new uint256[](assetAddresses.length);

        for (uint256 i = 0; i < assetAddresses.length; ++i) {
            Accounts.AssetPositions memory assetPositions =
                Accounts.findAssetPositions(assetAddresses[i], assetPositionsList);
            symbols[i] = assetPositions.symbol;
            prices[i] = assetPositions.usdPrice;
        }
    }

    function findQuarkSecret(address account, Accounts.QuarkSecret[] memory quarkSecrets)
        internal
        pure
        returns (Accounts.QuarkSecret memory)
    {
        for (uint256 i = 0; i < quarkSecrets.length; ++i) {
            if (quarkSecrets[i].account == account) {
                return quarkSecrets[i];
            }
        }
        revert QuarkSecretNotFound(account);
    }

    function sumBalances(AssetPositions memory assetPositions) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < assetPositions.accountBalances.length; ++i) {
            total += assetPositions.accountBalances[i].balance;
        }
        return total;
    }

    function getBalanceOnChain(string memory assetSymbol, uint256 chainId, ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (uint256)
    {
        AssetPositions memory positions = findAssetPositions(assetSymbol, chainId, chainAccountsList);
        return sumBalances(positions);
    }

    /*
    * @notice Get the total available asset balance for a given token symbol across chains
    * Substraction of max cost is done if the payment token is the transfer token to readjust the available balance
    * @param tokenSymbol The token symbol to check
    * @param chainAccountsList The list of chain accounts to check
    * @param payment The payment info to check
    * @return The total available asset balance
    */
    function totalAvailableAsset(
        string memory tokenSymbol,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    ) internal pure returns (uint256) {
        uint256 total = 0;

        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            uint256 balance = Accounts.sumBalances(
                Accounts.findAssetPositions(tokenSymbol, chainAccountsList[i].chainId, chainAccountsList)
            );

            // If the wrapper contract exists in the chain, add the balance of the wrapped/unwrapped token here as well
            // Subtract with another max cost for wrapping/unwrapping action when the counter part is payment token
            uint256 counterpartBalance = 0;
            if (TokenWrapper.hasWrapperContract(chainAccountsList[i].chainId, tokenSymbol)) {
                // Add the balance of the wrapped token
                counterpartBalance += Accounts.sumBalances(
                    Accounts.findAssetPositions(
                        TokenWrapper.getWrapperCounterpartSymbol(chainAccountsList[i].chainId, tokenSymbol),
                        chainAccountsList[i].chainId,
                        chainAccountsList
                    )
                );
            }

            if (balance + counterpartBalance == 0) {
                continue;
            }

            // Account for max cost if the payment token is the transfer token
            // Simply subtract the max cost from the available asset batch
            if (Strings.stringEqIgnoreCase(payment.currency, tokenSymbol)) {
                // Use subtractFlooredAtZero to prevent errors from underflowing
                balance = Math.subtractFlooredAtZero(
                    balance, PaymentInfo.findCostForChain(payment, chainAccountsList[i].chainId)
                );
            }

            // If the wrapped token is the payment token, subtract the max cost
            if (
                Strings.stringEqIgnoreCase(
                    payment.currency,
                    TokenWrapper.getWrapperCounterpartSymbol(chainAccountsList[i].chainId, tokenSymbol)
                )
            ) {
                counterpartBalance = Math.subtractFlooredAtZero(
                    counterpartBalance, PaymentInfo.findCostForChain(payment, chainAccountsList[i].chainId)
                );
            }

            total += balance + counterpartBalance;
        }
        return total;
    }

    /*
    * @notice Get the total asset balance for a given token symbol across chains
    * @param tokenSymbol The token symbol to check
    * @param chainAccountsList The list of chain accounts to check
    * @return The total available asset balance
    */
    function totalBalance(string memory tokenSymbol, Accounts.ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (uint256)
    {
        uint256 total = 0;

        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            uint256 balance = Accounts.sumBalances(
                Accounts.findAssetPositions(tokenSymbol, chainAccountsList[i].chainId, chainAccountsList)
            );

            // If the wrapper contract exists in the chain, add the balance of the wrapped/unwrapped token here as well
            uint256 counterpartBalance = 0;
            if (TokenWrapper.hasWrapperContract(chainAccountsList[i].chainId, tokenSymbol)) {
                // Add the balance of the wrapped token
                counterpartBalance += Accounts.sumBalances(
                    Accounts.findAssetPositions(
                        TokenWrapper.getWrapperCounterpartSymbol(chainAccountsList[i].chainId, tokenSymbol),
                        chainAccountsList[i].chainId,
                        chainAccountsList
                    )
                );
            }

            total += balance + counterpartBalance;
        }
        return total;
    }

    /*
    * @notice Get the total asset balance net of fees for a given token symbol on the destination chain
    * @param chainAccountsList The list of chain accounts to check
    * @param payment The payment currency and cost per chains
    * @param amountsOnDst A map of the amount of assets on the dst chain after bridging
    * @param bridgeFees A map of bridge fees by asset symbol
    * @param chainIdsInvolved The list of chainIds involved for the current intent
    * @param assetSymbol The symbol of the asset to check the balance for
    * @return The total available asset balance less the fees
    */
    function getTotalAvailableBalanceOnDst(
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment,
        HashMap.Map memory amountsOnDst,
        HashMap.Map memory bridgeFees,
        List.DynamicArray memory chainIdsInvolved,
        string memory assetSymbol
    ) internal pure returns (uint256) {
        uint256 paymentFees = Strings.stringEqIgnoreCase(payment.currency, assetSymbol)
            && !PaymentInfo.isOffchainPayment(payment)
            ? PaymentInfo.totalCost(payment, List.toUint256Array(chainIdsInvolved))
            : 0;

        uint256 balanceOnDstAfterBridge = HashMap.getOrDefaultUint256(amountsOnDst, abi.encode(assetSymbol), 0);
        uint256 totalBridgeFees = HashMap.getOrDefaultUint256(bridgeFees, abi.encode(assetSymbol), 0);

        uint256 aggregateBalance = Accounts.totalBalance(assetSymbol, chainAccountsList);
        uint256 unbridgedBalance = aggregateBalance - balanceOnDstAfterBridge - totalBridgeFees;

        // If payment fees are higher than the unbridged balance, it means that we cannot use the unbridged
        // funds to pay for the fees, so fees need to be paid on the destination chain
        if (paymentFees > unbridgedBalance) {
            return Math.subtractFlooredAtZero(balanceOnDstAfterBridge, paymentFees);
        } else {
            return balanceOnDstAfterBridge;
        }
    }

    function truncate(ChainAccounts[] memory chainAccountsList, uint256 length)
        internal
        pure
        returns (ChainAccounts[] memory)
    {
        ChainAccounts[] memory result = new ChainAccounts[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = chainAccountsList[i];
        }
        return result;
    }

    function totalBorrowForAccount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        address comet,
        address account
    ) internal pure returns (uint256 totalBorrow) {
        Accounts.CometPositions memory cometPositions = Accounts.findCometPositions(chainId, comet, chainAccountsList);
        for (uint256 i = 0; i < cometPositions.basePosition.accounts.length; ++i) {
            if (cometPositions.basePosition.accounts[i] == account) {
                totalBorrow = cometPositions.basePosition.borrowed[i];
            }
        }
    }

    function totalMorphoBorrowForAccount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        address loanToken,
        address collateralToken,
        address account
    ) internal pure returns (uint256 totalBorrow) {
        Accounts.MorphoPositions memory morphoPositions =
            findMorphoPositions(chainId, loanToken, collateralToken, chainAccountsList);
        for (uint256 i = 0; i < morphoPositions.borrowPosition.accounts.length; ++i) {
            if (morphoPositions.borrowPosition.accounts[i] == account) {
                totalBorrow = morphoPositions.borrowPosition.borrowed[i];
            }
        }
    }
}
