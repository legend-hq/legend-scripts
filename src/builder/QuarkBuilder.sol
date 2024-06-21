// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.23;

import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";

import {Actions} from "./Actions.sol";
import {Accounts} from "./Accounts.sol";
import {BridgeRoutes} from "./BridgeRoutes.sol";
import {EIP712Helper} from "./EIP712Helper.sol";
import {Strings} from "./Strings.sol";
import {PaycallWrapper} from "./PaycallWrapper.sol";
import {QuotecallWrapper} from "./QuotecallWrapper.sol";
import {PaymentInfo} from "./PaymentInfo.sol";

contract QuarkBuilder {
    /* ===== Constants ===== */

    string constant VERSION = "1.0.0";
    uint256 constant MAX_BRIDGE_ACTION = 1;

    // Note: This is a default max cost for passing into paycall if PaymentMaxCost is missing for particular chainId
    uint256 constant DEFAULT_MAX_PAYCALL_COST = 40e6;

    /* ===== Custom Errors ===== */

    error AssetPositionNotFound();
    error FundsUnavailable();
    error InsufficientFunds();
    error InvalidInput();
    error MaxCostTooHigh();
    error TooManyBridgeOperations();
    error InvalidActionType();

    /* ===== Input Types ===== */

    /* ===== Output Types ===== */

    struct BuilderResult {
        // version of the builder interface. (Same as VERSION, but attached to the output.)
        string version;
        // array of quark operations to execute to fulfill the client intent
        IQuarkWallet.QuarkOperation[] quarkOperations;
        // array of action context and other metadata corresponding 1:1 with quarkOperations
        Actions.Action[] actions;
        // EIP-712 digest to sign for either a MultiQuarkOperation or a single QuarkOperation to fulfill the client intent.
        // The digest will be for a MultiQuarkOperation if there are more than one QuarkOperations in the BuilderResult.
        // Otherwise, the digest will be for a single QuarkOperation.
        bytes32 quarkOperationDigest;
        // client-provided paymentCurrency string that was used to derive token addresses.
        // client may re-use this string to construct a request that simulates the transaction.
        string paymentCurrency;
    }

    /* ===== Helper Functions ===== */

    /* ===== Main Implementation ===== */

    struct TransferIntent {
        uint256 chainId;
        string assetSymbol;
        uint256 amount;
        address sender;
        address recipient;
        uint256 blockTimestamp;
    }

    // TODO: handle transfer max
    // TODO: support expiry
    function transfer(
        TransferIntent memory transferIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    ) external pure returns (BuilderResult memory) {
        // TransferMax flag
        bool transferMax = transferIntent.amount == type(uint256).max;
        // Convert transferIntent to user aggregated balance
        if (transferMax) {
            transferIntent.amount = totalAvailableAsset(transferIntent.assetSymbol, chainAccountsList, payment);
        }

        assertSufficientFunds(transferIntent, chainAccountsList);
        assertFundsAvailable(transferIntent, chainAccountsList, payment);

        /*
         * at most one bridge operation per non-destination chain,
         * and at most one transferIntent operation on the destination chain.
         *
         * therefore the upper bound is chainAccountsList.length.
         */
        uint256 actionIndex = 0;
        // TODO: actually allocate quark actions
        Actions.Action[] memory actions = new Actions.Action[](chainAccountsList.length);
        IQuarkWallet.QuarkOperation[] memory quarkOperations =
            new IQuarkWallet.QuarkOperation[](chainAccountsList.length);

        if (needsBridgedFunds(transferIntent, chainAccountsList)) {
            // Note: Assumes that the asset uses the same # of decimals on each chain
            uint256 balanceOnDstChain =
                Accounts.getBalanceOnChain(transferIntent.assetSymbol, transferIntent.chainId, chainAccountsList);
            uint256 amountLeftToBridge = transferIntent.amount - balanceOnDstChain;
            // If the payment token is the transfer token and user opt for paying with the payment token, need to add max cost back to the amountLeftToBridge for target chain
            if (payment.isToken && Strings.stringEqIgnoreCase(payment.currency, transferIntent.assetSymbol)) {
                amountLeftToBridge += PaymentInfo.findMaxCost(payment, transferIntent.chainId);
            }

            uint256 bridgeActionCount = 0;
            // TODO: bridge routing logic (which bridge to prioritize, how many bridges?)
            // Iterate chainAccountList and find upto 2 chains that can provide enough fund
            // Backend can provide optimal routes by adjust the order in chainAccountList.
            for (uint256 i = 0; i < chainAccountsList.length; ++i) {
                if (amountLeftToBridge == 0) {
                    break;
                }

                Accounts.ChainAccounts memory srcChainAccounts = chainAccountsList[i];
                if (srcChainAccounts.chainId == transferIntent.chainId) {
                    continue;
                }

                if (
                    !BridgeRoutes.canBridge(srcChainAccounts.chainId, transferIntent.chainId, transferIntent.assetSymbol)
                ) {
                    continue;
                }

                Accounts.AssetPositions memory srcAssetPositions =
                    Accounts.findAssetPositions(transferIntent.assetSymbol, srcChainAccounts.assetPositionsList);
                Accounts.AccountBalance[] memory srcAccountBalances = srcAssetPositions.accountBalances;
                // TODO: Make logic smarter. Currently, this uses a greedy algorithm.
                // e.g. Optimize by trying to bridge with the least amount of bridge operations
                for (uint256 j = 0; j < srcAccountBalances.length; ++j) {
                    if (bridgeActionCount >= MAX_BRIDGE_ACTION) {
                        revert TooManyBridgeOperations();
                    }

                    uint256 amountToBridge = srcAccountBalances[j].balance >= amountLeftToBridge
                        ? amountLeftToBridge
                        : srcAccountBalances[j].balance;
                    amountLeftToBridge -= amountToBridge;

                    (quarkOperations[actionIndex], actions[actionIndex]) = Actions.bridgeAsset(
                        Actions.BridgeAsset({
                            chainAccountsList: chainAccountsList,
                            assetSymbol: transferIntent.assetSymbol,
                            amount: amountToBridge,
                            // where it comes from
                            srcChainId: srcChainAccounts.chainId,
                            sender: srcAccountBalances[j].account,
                            // where it goes
                            destinationChainId: transferIntent.chainId,
                            recipient: transferIntent.sender,
                            blockTimestamp: transferIntent.blockTimestamp
                        }),
                        payment,
                        transferMax
                    );

                    actionIndex++;
                    bridgeActionCount++;
                }
            }

            if (amountLeftToBridge > 0) {
                revert FundsUnavailable();
            }
        }

        // Need to re-adjust the transferIntent.amount before operation struct is created when transferMax is true and transfer token is payment token at the same time
        // Will need to allocate some for the payment at the end
        if (transferMax && Strings.stringEqIgnoreCase(payment.currency, transferIntent.assetSymbol)) {
            // Subtract the max cost (quotecall cost) from the transferIntent.amount
            transferIntent.amount -= PaymentInfo.findMaxCost(payment, transferIntent.chainId);
        }

        // Then, transferIntent `amount` of `assetSymbol` to `recipient`
        (quarkOperations[actionIndex], actions[actionIndex]) = Actions.transferAsset(
            Actions.TransferAsset({
                chainAccountsList: chainAccountsList,
                assetSymbol: transferIntent.assetSymbol,
                amount: transferIntent.amount,
                chainId: transferIntent.chainId,
                sender: transferIntent.sender,
                recipient: transferIntent.recipient,
                blockTimestamp: transferIntent.blockTimestamp
            }),
            payment,
            transferMax
        );

        actionIndex++;

        // Construct EIP712 digests
        // We leave `multiQuarkOperationDigest` empty if there is only a single QuarkOperation
        // We leave `quarkOperationDigest` if there are more than one QuarkOperations
        actions = Actions.truncate(actions, actionIndex);
        quarkOperations = Actions.truncate(quarkOperations, actionIndex);

        // Validate generated actions for affordability
        assertActionsAffordable(actions, chainAccountsList, transferIntent);

        bytes32 quarkOperationDigest;
        if (quarkOperations.length == 1) {
            quarkOperationDigest =
                EIP712Helper.getDigestForQuarkOperation(quarkOperations[0], actions[0].quarkAccount, actions[0].chainId);
        } else if (quarkOperations.length > 1) {
            quarkOperationDigest = EIP712Helper.getDigestForMultiQuarkOperation(quarkOperations, actions);
        }

        return BuilderResult({
            version: VERSION,
            actions: actions,
            quarkOperations: quarkOperations,
            paymentCurrency: payment.currency,
            quarkOperationDigest: quarkOperationDigest
        });
    }

    function assertSufficientFunds(
        TransferIntent memory transferIntent,
        Accounts.ChainAccounts[] memory chainAccountsList
    ) internal pure {
        uint256 aggregateTransferAssetBalance;
        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            aggregateTransferAssetBalance += Accounts.sumBalances(
                Accounts.findAssetPositions(transferIntent.assetSymbol, chainAccountsList[i].assetPositionsList)
            );
        }
        // There are not enough aggregate funds on all chains to fulfill the transfer.
        if (aggregateTransferAssetBalance < transferIntent.amount) {
            revert InsufficientFunds();
        }
    }

    // For some reason, funds that may otherwise be bridgeable or held by the
    // user cannot be made available to fulfill the transaction. Funds cannot
    // be bridged, e.g. no bridge exists Funds cannot be withdrawn from comet,
    // e.g. no reserves In order to consider the availability here, we’d need
    // comet data to be passed in as an input. (So, if we were including
    // withdraw.)
    function assertFundsAvailable(
        TransferIntent memory transferIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    ) internal pure {
        if (needsBridgedFunds(transferIntent, chainAccountsList)) {
            uint256 aggregateTransferAssetAvailableBalance;
            for (uint256 i = 0; i < chainAccountsList.length; ++i) {
                Accounts.AssetPositions memory positions =
                    Accounts.findAssetPositions(transferIntent.assetSymbol, chainAccountsList[i].assetPositionsList);
                if (
                    chainAccountsList[i].chainId == transferIntent.chainId
                        || BridgeRoutes.canBridge(
                            chainAccountsList[i].chainId, transferIntent.chainId, transferIntent.assetSymbol
                        )
                ) {
                    aggregateTransferAssetAvailableBalance += Accounts.sumBalances(positions);
                    // If the payment token is the transfer token and user opt for paying with the payment token, reduce the available balance by the maxCost
                    if (payment.isToken && Strings.stringEqIgnoreCase(payment.currency, transferIntent.assetSymbol)) {
                        uint256 maxCost = PaymentInfo.findMaxCost(payment, chainAccountsList[i].chainId);
                        aggregateTransferAssetAvailableBalance -= maxCost;
                    }
                }
            }
            if (aggregateTransferAssetAvailableBalance < transferIntent.amount) {
                revert FundsUnavailable();
            }
        }
    }

    function needsBridgedFunds(TransferIntent memory transferIntent, Accounts.ChainAccounts[] memory chainAccountsList)
        internal
        pure
        returns (bool)
    {
        return Accounts.getBalanceOnChain(transferIntent.assetSymbol, transferIntent.chainId, chainAccountsList)
            < transferIntent.amount;
    }

    // Assert that each chain has sufficient funds to cover the max cost for that chain.
    // Check user account can cover the cost of each actions
    function assertActionsAffordable(
        Actions.Action[] memory actions,
        Accounts.ChainAccounts[] memory chainAccountsList,
        TransferIntent memory transferIntent
    ) internal pure {
        Actions.Action[] memory bridgeActions = Actions.findActionsOfType(actions, Actions.ACTION_TYPE_BRIDGE);
        Actions.Action[] memory transferActions = Actions.findActionsOfType(actions, Actions.ACTION_TYPE_TRANSFER);

        uint256 plannedBridgeAmount = 0;
        // Verify bridge actions are affordable, and update plannedBridgeAmount for verifying transfer actions
        for (uint256 i = 0; i < bridgeActions.length; ++i) {
            Actions.BridgeActionContext memory bridgeActionContext =
                abi.decode(bridgeActions[i].actionContext, (Actions.BridgeActionContext));
            uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(
                Accounts.findAssetPositions(bridgeActions[i].paymentToken, bridgeActions[i].chainId, chainAccountsList)
            );
            if (bridgeActionContext.token == bridgeActions[i].paymentToken) {
                // If the payment token is the transfer token and this is the target chain, we need to account for the transfer amount
                // If its bridge step, check if user has enough balance to cover the bridge amount
                if (paymentAssetBalanceOnChain < bridgeActions[i].paymentMaxCost + bridgeActionContext.amount) {
                    revert MaxCostTooHigh();
                }
            } else {
                // Just check payment token can cover the max cost
                if (paymentAssetBalanceOnChain < bridgeActions[i].paymentMaxCost) {
                    revert MaxCostTooHigh();
                }
            }

            plannedBridgeAmount += bridgeActionContext.amount;
        }

        // Verify transfer actions are affordable
        // NOTE: Assume all transfer actions are on the TransferIntent.chainId as Bridging logics is currently assuming destination at TransferIntent.chainId
        // NOTE: To support multi-chain transfers, call below functions to check repeatedly with each chainId and plannedBridgeAmount
        // for each chain (Likely passed from TransferIntent with a list of chain Id)
        assertTransferActionsAffordableOnTargetChain(
            transferActions, chainAccountsList, transferIntent.chainId, plannedBridgeAmount
        );
    }

    function assertTransferActionsAffordableOnTargetChain(
        Actions.Action[] memory transferActions,
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 targetChainId,
        uint256 plannedBridgeAmountToTargetChain
    ) internal pure {
        uint256 paymentTokensUsed = 0;
        for (uint256 i = 0; i < transferActions.length; ++i) {
            Actions.TransferActionContext memory transferActionContext =
                abi.decode(transferActions[i].actionContext, (Actions.TransferActionContext));
            // Filter with the targetChainId and paymentTokensUsed will track on one chain at a time
            if (transferActionContext.chainId == targetChainId) {
                address transferToken = transferActionContext.token;
                uint256 transferAmount = transferActionContext.amount;
                uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(
                    Accounts.findAssetPositions(transferToken, transferActions[i].chainId, chainAccountsList)
                );
                paymentTokensUsed += transferActions[i].paymentMaxCost;
                if (transferToken == transferActions[i].paymentToken) {
                    // If the payment token is the transfer token and this is the target chain, we need to account for the transfer amount
                    // If its transfer step, check if user has enough balance to cover the transfer amount after bridge
                    if (
                        paymentAssetBalanceOnChain + plannedBridgeAmountToTargetChain
                            < paymentTokensUsed + transferAmount
                    ) {
                        revert MaxCostTooHigh();
                    }

                    // Special handling as the payment token is sent out so it will be part of the cost
                    paymentTokensUsed += transferAmount;
                } else {
                    // Just check payment token can cover the max cost
                    if (paymentAssetBalanceOnChain < paymentTokensUsed) {
                        revert MaxCostTooHigh();
                    }
                }
            }
        }
    }

    function totalAvailableAsset(
        string memory tokenSymbol,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    ) internal pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < payment.maxCosts.length; ++i) {
            uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(
                Accounts.findAssetPositions(tokenSymbol, payment.maxCosts[i].chainId, chainAccountsList)
            );
            uint256 paymentAssetNeeded = payment.maxCosts[i].amount;
            if (paymentAssetBalanceOnChain > paymentAssetNeeded) {
                total += paymentAssetBalanceOnChain - paymentAssetNeeded;
            }
        }
        return total;
    }
}
