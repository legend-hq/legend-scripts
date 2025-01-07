// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {console} from "src/builder/console.sol";

import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";

import {Actions} from "src/builder/actions/Actions.sol";
import {Accounts} from "src/builder/Accounts.sol";
import {Across, BridgeRoutes} from "src/builder/BridgeRoutes.sol";
import {BuilderPackHelper} from "src/builder/BuilderPackHelper.sol";
import {EIP712Helper} from "src/builder/EIP712Helper.sol";
import {Errors} from "src/builder/Errors.sol";
import {Math} from "src/lib/Math.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {Strings} from "src/builder/Strings.sol";
import {PaycallWrapper} from "src/builder/PaycallWrapper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {QuarkOperationHelper} from "src/builder/QuarkOperationHelper.sol";
import {List} from "src/builder/List.sol";
import {HashMap} from "src/builder/HashMap.sol";
import {QuotePay} from "src/QuotePay.sol";

string constant QUARK_BUILDER_VERSION = "0.5.4";

contract QuarkBuilderBase {
    /* ===== Output Types ===== */

    struct BuilderResult {
        // Version of the builder interface. (Same as VERSION, but attached to the output.)
        string version;
        // Array of quark operations to execute to fulfill the client intent
        IQuarkWallet.QuarkOperation[] quarkOperations;
        // Array of action context and other metadata corresponding 1:1 with quarkOperations
        Actions.Action[] actions;
        // Struct containing containing EIP-712 data for a QuarkOperation or MultiQuarkOperation
        EIP712Helper.EIP712Data eip712Data;
        // Client-provided paymentCurrency string that was used to derive token addresses.
        // Client may re-use this string to construct a request that simulates the transaction.
        string paymentCurrency;
    }

    /* ===== Constants ===== */

    string public constant VERSION = QUARK_BUILDER_VERSION;

    /* ===== Custom Errors ===== */

    error AssetPositionNotFound();
    error BadInputInsufficientFunds(string assetSymbol, uint256 requiredAmount, uint256 actualAmount);
    error BadInputInsufficientFundsForRecurring(string assetSymbol, uint256 requiredAmount, uint256 actualAmount);
    error BadInputUnbridgeableFunds(string assetSymbol, uint256 requiredAmount, uint256 amountLeftToBridge);
    error InvalidActionType();
    error InvalidInput();
    error MaxCostTooHigh();
    error MissingWrapperCounterpart();
    error BalanceNotRight(uint256 paymentAssetBalance, uint256 assetsIn, uint256 assetsOut);
    error InvalidRepayActionContext();
    error UnableToConstructPaycall(string assetSymbol, uint256 maxCost);
    error UnableToConstructActionIntent(
        bool bridgingError,
        string bridgeAssetSymbol,
        uint256 bridgeFees,
        string quotePayStatus,
        string paymentAssetSymbol,
        uint256 quoteAmount
    );

    /**
     * @dev Intent for an action to be executed by the Quark Wallet
     * @param actor The address of the actor who is initiating the action
     * @param amountOuts The amounts of assets to be transferred out from actor's account
     * @param assetSymbolOuts The symbols of the assets to be transferred out from actor's account
     * @param amountIns The amounts of assets to be transferred in to actor's account
     * @param assetSymbolIns The symbols of the assets to be transferred in to actor's account
     * @param blockTimestamp The block timestamp at which the action is initiated
     * @param chainId The chain ID on which the action is initiated
     * @param preferAcross Whether to use Across for bridging or not
     */
    struct ActionIntent {
        address actor;
        uint256[] amountOuts;
        string[] assetSymbolOuts;
        uint256[] amountIns;
        string[] assetSymbolIns;
        uint256 blockTimestamp;
        uint256 chainId;
        bool preferAcross;
    }

    /**
     * @dev Collects assets for an action by checking and bridging assets if necessary to accomodate the intended action.
     */
    function collectAssetsForAction(
        ActionIntent memory actionIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment,
        IQuarkWallet.QuarkOperation memory actionQuarkOperation,
        Actions.Action memory action
    )
        internal
        pure
        returns (IQuarkWallet.QuarkOperation[] memory quarkOperationsArray, Actions.Action[] memory actionsArray)
    {
        // Sanity check on ActionIntent
        if (
            actionIntent.amountOuts.length != actionIntent.assetSymbolOuts.length
                || actionIntent.amountIns.length != actionIntent.assetSymbolIns.length
        ) {
            revert InvalidInput();
        }

        List.DynamicArray memory actions = List.newList();
        List.DynamicArray memory quarkOperations = List.newList();

        string memory bridgeErrorSymbol;
        uint256 bridgeFees;

        // Track the amount of each asset that will be bridged to the destination chain
        HashMap.Map memory assetsBridged = HashMap.newMap();

        for (uint256 i = 0; i < actionIntent.assetSymbolOuts.length; ++i) {
            string memory assetSymbolOut = actionIntent.assetSymbolOuts[i];

            uint256 aggregateAssetBalance =
                getAggregateAssetBalance(actionIntent.chainId, assetSymbolOut, chainAccountsList);

            // Assert that there are enough of the intent token to complete the action
            if (aggregateAssetBalance < actionIntent.amountOuts[i]) {
                // Bad Input :: the specified amount exceeds the cumulative balance
                revert BadInputInsufficientFunds(assetSymbolOut, actionIntent.amountOuts[i], aggregateAssetBalance);
            }

            if (needsBridgedFunds(assetSymbolOut, actionIntent.amountOuts[i], actionIntent.chainId, chainAccountsList))
            {
                if (Actions.isRecurringAction(action)) {
                    uint256 balanceOnChain =
                        getBalanceOnChainIncludingCounterpart(assetSymbolOut, actionIntent.chainId, chainAccountsList);
                    uint256 amountNeededOnChain = actionIntent.amountOuts[i];
                    uint256 costOnChain = PaymentInfo.isOffchainPayment(payment)
                        ? 0
                        : PaymentInfo.findCostForChain(payment, actionIntent.chainId);
                    uint256 availableAssetBalance = balanceOnChain >= costOnChain ? balanceOnChain - costOnChain : 0;

                    revert BadInputInsufficientFundsForRecurring(
                        assetSymbolOut, amountNeededOnChain, availableAssetBalance
                    );
                }

                uint256 amountNeededOnDst = actionIntent.amountOuts[i];
                (
                    IQuarkWallet.QuarkOperation[] memory bridgeQuarkOperations,
                    Actions.Action[] memory bridgeActions,
                    uint256 amountLeftToBridge,
                    uint256 unbridgeableBalance,
                    uint256 totalBridgeFees
                ) = Actions.constructBridgeOperations(
                    Actions.BridgeOperationInfo({
                        assetSymbol: assetSymbolOut,
                        amountNeededOnDst: amountNeededOnDst,
                        dstChainId: actionIntent.chainId,
                        recipient: actionIntent.actor,
                        blockTimestamp: actionIntent.blockTimestamp,
                        preferAcross: actionIntent.preferAcross
                    }),
                    chainAccountsList,
                    payment
                );

                if (amountLeftToBridge > 0 && unbridgeableBalance > 0) {
                    // Bad Input :: the specified amount exceeds the bridgeable balance
                    revert BadInputUnbridgeableFunds(assetSymbolOut, amountNeededOnDst, amountLeftToBridge);
                }

                // Track how much is actually bridged for each asset
                HashMap.addOrPutUint256(
                    assetsBridged, abi.encode(assetSymbolOut), amountNeededOnDst - amountLeftToBridge
                );

                for (uint256 j = 0; j < bridgeQuarkOperations.length; ++j) {
                    List.addQuarkOperation(quarkOperations, bridgeQuarkOperations[j]);
                    List.addAction(actions, bridgeActions[j]);
                }

                if (amountLeftToBridge > 0) {
                    bridgeErrorSymbol = assetSymbolOut;
                    bridgeFees = totalBridgeFees;
                    break;
                }
            }
        }

        for (uint256 i = 0; i < actionIntent.assetSymbolOuts.length; ++i) {
            string memory assetSymbolOut = actionIntent.assetSymbolOuts[i];
            uint256 supplementalBalance = HashMap.contains(assetsBridged, abi.encode(assetSymbolOut))
                ? HashMap.getUint256(assetsBridged, abi.encode(assetSymbolOut))
                : 0;
            // Note: Right now, ETH/WETH is only bridged via Across. Across has a weird quirk where it will send ETH to EOAs and
            // WETH to contracts. Since the QuarkBuilder cannot know if a QuarkWallet is deployed before the operation is actually
            // executed on-chain, we need to assume there is no supplemental balance that arrives on the destination chain.
            if (Across.isNonDeterministicBridgeAction(assetsBridged, assetSymbolOut)) {
                supplementalBalance = 0;
            }

            checkAndInsertWrapOrUnwrapAction({
                actions: actions,
                quarkOperations: quarkOperations,
                chainAccountsList: chainAccountsList,
                payment: payment,
                assetSymbol: assetSymbolOut,
                amountNeeded: actionIntent.amountOuts[i],
                supplementalBalance: supplementalBalance,
                chainId: actionIntent.chainId,
                account: actionIntent.actor,
                blockTimestamp: actionIntent.blockTimestamp,
                isRecurring: Actions.isRecurringAction(action)
            });
        }

        // Insert action and operation that will be wrapped with this
        List.addAction(actions, action);
        List.addQuarkOperation(quarkOperations, actionQuarkOperation);

        string memory quotePayResult = Strings.OK;
        uint256 totalQuoteAmount;

        // Generate a QuotePay operation if the payment method is with tokens and the action is non-recurring
        if (!PaymentInfo.isOffchainPayment(payment) && !Actions.isRecurringAction(action)) {
            (
                IQuarkWallet.QuarkOperation memory quotePayOperation,
                Actions.Action memory quotePayAction,
                string memory result,
                uint256 totalQuoteAmount_
            ) = generateQuotePayOperation(
                PaymentBalanceAssertionArgs({
                    actions: List.toActionArray(actions),
                    chainAccountsList: chainAccountsList,
                    targetChainId: actionIntent.chainId,
                    account: actionIntent.actor,
                    blockTimestamp: actionIntent.blockTimestamp,
                    payment: payment
                })
            );

            quotePayResult = result;
            totalQuoteAmount = totalQuoteAmount_;

            List.addAction(actions, quotePayAction);
            List.addQuarkOperation(quarkOperations, quotePayOperation);
        }

        bool hasBridgeError = !Strings.stringEqIgnoreCase(bridgeErrorSymbol, "");
        if (hasBridgeError || !Strings.isOk(quotePayResult)) {
            revert UnableToConstructActionIntent(
                hasBridgeError, bridgeErrorSymbol, bridgeFees, quotePayResult, payment.currency, totalQuoteAmount
            );
        }

        // Convert to array
        quarkOperationsArray = List.toQuarkOperationArray(quarkOperations);
        actionsArray = List.toActionArray(actions);

        // Merge operations that are from the same chain into one Multicall operation
        (quarkOperationsArray, actionsArray) =
            QuarkOperationHelper.mergeSameChainOperations(quarkOperationsArray, actionsArray);

        // Wrap operations around Paycall if payment is with token and the action is recurring
        if (!PaymentInfo.isOffchainPayment(payment) && Actions.isRecurringAction(action)) {
            assertSufficientPaymentTokensForPaycall(
                PaymentBalanceAssertionArgs({
                    actions: List.toActionArray(actions),
                    chainAccountsList: chainAccountsList,
                    targetChainId: actionIntent.chainId,
                    account: actionIntent.actor,
                    blockTimestamp: actionIntent.blockTimestamp,
                    payment: payment
                })
            );

            quarkOperationsArray = QuarkOperationHelper.wrapOperationsWithTokenPayment({
                quarkOperations: quarkOperationsArray,
                actions: actionsArray,
                payment: payment
            });
        }
    }

    /**
     * @dev Construct bridge operations or no-op if no bridging is needed
     */
    function getBridgeOperationsForAsset(
        uint256 chainId,
        string memory assetSymbol,
        uint256 amount,
        address recipient,
        uint256 blockTimestamp,
        bool preferAcross,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    )
        internal
        pure
        returns (
            IQuarkWallet.QuarkOperation[] memory quarkOperationsArray,
            Actions.Action[] memory actionsArray,
            uint256 finalAmountOnDst,
            uint256 fees,
            uint256 supplementalBalance
        )
    {
        List.DynamicArray memory actions = List.newList();
        List.DynamicArray memory quarkOperations = List.newList();

        uint256 aggregateBalance = getAggregateAssetBalance(chainId, assetSymbol, chainAccountsList);
        uint256 amountNeededOnDst = amount == type(uint256).max ? aggregateBalance : amount;

        // Assert that there are enough of the intent token to complete the action
        if (aggregateBalance < amountNeededOnDst) {
            // Bad Input :: the specified amount exceeds the cumulative balance
            revert BadInputInsufficientFunds(assetSymbol, amountNeededOnDst, aggregateBalance);
        }

        if (needsBridgedFunds(assetSymbol, amount, chainId, chainAccountsList)) {
            (
                IQuarkWallet.QuarkOperation[] memory bridgeQuarkOperations,
                Actions.Action[] memory bridgeActions,
                uint256 amountLeftToBridge,
                uint256 unbridgeableBalance,
                uint256 totalBridgeFees
            ) = Actions.constructBridgeOperations(
                Actions.BridgeOperationInfo({
                    assetSymbol: assetSymbol,
                    amountNeededOnDst: amountNeededOnDst,
                    dstChainId: chainId,
                    recipient: recipient,
                    blockTimestamp: blockTimestamp,
                    preferAcross: preferAcross
                }),
                chainAccountsList,
                payment
            );

            if (amountLeftToBridge > 0 && unbridgeableBalance > 0) {
                // Bad Input :: the specified amount exceeds the bridgeable balance
                revert BadInputUnbridgeableFunds(assetSymbol, amount, amountLeftToBridge);
            }

            finalAmountOnDst = amountNeededOnDst - amountLeftToBridge;

            for (uint256 j = 0; j < bridgeQuarkOperations.length; ++j) {
                List.addQuarkOperation(quarkOperations, bridgeQuarkOperations[j]);
                List.addAction(actions, bridgeActions[j]);
            }

            if (amountLeftToBridge > 0) {
                fees = totalBridgeFees;
            }
        } else {
            finalAmountOnDst = amountNeededOnDst;
        }

        supplementalBalance = Across.isEthOrWethBridgeAction(assetSymbol, finalAmountOnDst) ? 0 : finalAmountOnDst;

        // Convert to array
        quarkOperationsArray = List.toQuarkOperationArray(quarkOperations);
        actionsArray = List.toActionArray(actions);
    }

    /* ===== Helper functions ===== */

    function cometRepayMaxAmount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        address comet,
        address repayer
    ) internal pure returns (uint256) {
        uint256 totalBorrowForAccount = Accounts.totalBorrowForAccount(chainAccountsList, chainId, comet, repayer);
        uint256 buffer = totalBorrowForAccount / 1000; // 0.1%
        return totalBorrowForAccount + buffer;
    }

    function morphoRepayMaxAmount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        address loanToken,
        address collateralToken,
        address repayer
    ) internal pure returns (uint256) {
        uint256 totalBorrowForAccount =
            Accounts.totalMorphoBorrowForAccount(chainAccountsList, chainId, loanToken, collateralToken, repayer);
        uint256 buffer = totalBorrowForAccount / 1000; // 0.1%
        return totalBorrowForAccount + buffer;
    }

    function cometWithdrawMaxAmount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        address comet,
        address withdrawer
    ) internal pure returns (uint256) {
        uint256 actualWithdrawAmount = 0;
        Accounts.CometPositions memory cometPositions = Accounts.findCometPositions(chainId, comet, chainAccountsList);

        for (uint256 i = 0; i < cometPositions.basePosition.accounts.length; ++i) {
            if (cometPositions.basePosition.accounts[i] == withdrawer) {
                actualWithdrawAmount += cometPositions.basePosition.supplied[i];
            }
        }
        return actualWithdrawAmount;
    }

    function morphoWithdrawMaxAmount(
        Accounts.ChainAccounts[] memory chainAccountsList,
        uint256 chainId,
        string memory assetSymbol,
        address withdrawer
    ) internal pure returns (uint256) {
        uint256 actualWithdrawAmount = 0;
        Accounts.MorphoVaultPositions memory morphoVaultPositions = Accounts.findMorphoVaultPositions(
            chainId, Accounts.findAssetPositions(assetSymbol, chainId, chainAccountsList).asset, chainAccountsList
        );

        for (uint256 i = 0; i < morphoVaultPositions.accounts.length; ++i) {
            if (morphoVaultPositions.accounts[i] == withdrawer) {
                actualWithdrawAmount += morphoVaultPositions.balances[i];
            }
        }
        return actualWithdrawAmount;
    }

    function getAggregateAssetBalance(
        uint256 chainId,
        string memory assetSymbol,
        Accounts.ChainAccounts[] memory chainAccountsList
    ) internal pure returns (uint256) {
        // Check each chain to see if there are enough action assets to be bridged over
        uint256 aggregateAssetBalance;
        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            Accounts.AssetPositions memory positions =
                Accounts.findAssetPositions(assetSymbol, chainAccountsList[i].assetPositionsList);
            if (
                chainAccountsList[i].chainId == chainId
                    || BridgeRoutes.canBridge(chainAccountsList[i].chainId, chainId, assetSymbol)
            ) {
                aggregateAssetBalance += Accounts.sumBalances(positions);
            }

            // If the asset has wrapper counterpart and can locally wrap/unwrap, accumulate the balance of the the counterpart
            // NOTE: Currently only at dst chain, and will ignore all the counterpart balance in other chains
            if (
                chainAccountsList[i].chainId == chainId
                    && TokenWrapper.hasWrapperContract(chainAccountsList[i].chainId, assetSymbol)
            ) {
                {
                    aggregateAssetBalance +=
                        getWrapperCounterpartBalance(assetSymbol, chainAccountsList[i].chainId, chainAccountsList);
                }
            }
        }

        return aggregateAssetBalance;
    }

    function needsBridgedFunds(
        string memory assetSymbol,
        uint256 amount,
        uint256 chainId,
        Accounts.ChainAccounts[] memory chainAccountsList
    ) internal pure returns (bool) {
        // We don't need to subtract quote from balanceOnChain because quote can be paid from another chain
        uint256 balanceOnChain = getBalanceOnChainIncludingCounterpart(assetSymbol, chainId, chainAccountsList);

        return balanceOnChain < amount;
    }

    /**
     * @dev If there is not enough of the asset to cover the amount and the asset has a counterpart asset,
     * insert a wrap/unwrap action to cover the gap in amount.
     *
     * `supplementalBalance` param describes an amount of the token that might have been received in the course
     * of an action (for example, bridging to the destination chain), which would therefore not be present in
     * `chainAccountsList` but could be used to cover action costs.
     */
    function checkAndInsertWrapOrUnwrapAction(
        List.DynamicArray memory actions,
        List.DynamicArray memory quarkOperations,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment,
        string memory assetSymbol,
        uint256 amountNeeded,
        uint256 supplementalBalance,
        uint256 chainId,
        address account,
        uint256 blockTimestamp,
        bool isRecurring
    ) internal pure {
        // Check if inserting wrapOrUnwrap action is necessary
        uint256 assetBalanceOnChain =
            Accounts.getBalanceOnChain(assetSymbol, chainId, chainAccountsList) + supplementalBalance;
        if (assetBalanceOnChain < amountNeeded && TokenWrapper.hasWrapperContract(chainId, assetSymbol)) {
            // If the asset has a wrapper counterpart, wrap/unwrap the token to cover the amount needed for the intent
            string memory counterpartSymbol = TokenWrapper.getWrapperCounterpartSymbol(chainId, assetSymbol);

            // Wrap/unwrap the token to cover the amount
            (IQuarkWallet.QuarkOperation memory wrapOrUnwrapOperation, Actions.Action memory wrapOrUnwrapAction) =
            Actions.wrapOrUnwrapAsset(
                Actions.WrapOrUnwrapAsset({
                    chainAccountsList: chainAccountsList,
                    assetSymbol: counterpartSymbol,
                    // Note: The wrapper logic should only "wrap all" or "wrap up to" the amount needed
                    amountNeeded: amountNeeded,
                    balanceOnChain: assetBalanceOnChain,
                    chainId: chainId,
                    sender: account,
                    blockTimestamp: blockTimestamp
                }),
                payment,
                isRecurring
            );
            List.addQuarkOperation(quarkOperations, wrapOrUnwrapOperation);
            List.addAction(actions, wrapOrUnwrapAction);
        }
    }

    struct PaymentBalanceAssertionArgs {
        Actions.Action[] actions;
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 targetChainId;
        address account;
        uint256 blockTimestamp;
        PaymentInfo.Payment payment;
    }

    string constant ERROR_IMPOSSIBLE_TO_CONSTRUCT = "IMPOSSIBLE_TO_CONSTRUCT";
    string constant ERROR_UNABLE_TO_CONSTRUCT = "UNABLE_TO_CONSTRUCT";
    string constant ERROR_NO_KNOWN_PAYMENT_TOKEN = "NO_KNOWN_PAYMENT_TOKEN";

    /**
     * @dev Generate a QuotePay operation on a single chain to cover the quoted costs for all the operations, if possible.
     *      Reverts with FundsUnavailable if no single chain has enough to cover the total quote cost
     */
    function generateQuotePayOperation(PaymentBalanceAssertionArgs memory args)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Actions.Action memory, string memory, uint256)
    {
        // Checks the chain ids that have actions
        List.DynamicArray memory chainIdsInvolved = List.newList();

        // Tracks the payment assets that are leaving and entering each chain
        HashMap.Map memory assetsInPerChain = HashMap.newMap();
        HashMap.Map memory assetsOutPerChain = HashMap.newMap();

        string memory paymentTokenSymbol = args.payment.currency;
        for (uint256 i = 0; i < args.actions.length; ++i) {
            Actions.Action memory action = args.actions[i];

            // Keep track of which chains have actions on them. This will be used to generate the final
            // quote amount later.
            if (!List.contains(chainIdsInvolved, action.chainId)) {
                List.addUint256(chainIdsInvolved, action.chainId);
            }

            trackAssetsInAndOut({
                assetsInPerChain: assetsInPerChain,
                assetsOutPerChain: assetsOutPerChain,
                action: action,
                chainAccountsList: args.chainAccountsList,
                paymentTokenSymbol: paymentTokenSymbol,
                account: args.account
            });
        }

        for (uint256 i = 0; i < args.chainAccountsList.length; ++i) {
            uint256 chainId = args.chainAccountsList[i].chainId;

            // Calculate the net payment balance on this chain
            // TODO: Need to be modified when supporting multiple accounts per chain, since this currently assumes all assets are in one account.
            //       Will need a 2D map for assetsIn/Out to map from chainId -> account
            Accounts.AssetPositions memory paymentAssetPositions =
                Accounts.findAssetPositions(paymentTokenSymbol, args.chainAccountsList[i].assetPositionsList);
            uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(paymentAssetPositions);

            uint256 netPaymentAssetBalanceOnChain = 0;
            if (
                paymentAssetBalanceOnChain + HashMap.getOrDefaultUint256(assetsInPerChain, abi.encode(chainId), 0)
                    >= HashMap.getOrDefaultUint256(assetsOutPerChain, abi.encode(chainId), 0)
            ) {
                netPaymentAssetBalanceOnChain = paymentAssetBalanceOnChain
                    + HashMap.getOrDefaultUint256(assetsInPerChain, abi.encode(chainId), 0)
                    - HashMap.getOrDefaultUint256(assetsOutPerChain, abi.encode(chainId), 0);
            }

            // Skip if there is no net payment balance on this chain
            if (netPaymentAssetBalanceOnChain == 0) {
                continue;
            }

            // Generate quote amount based on which chains have an operation on them
            uint256 quoteAmount = PaymentInfo.totalCost(args.payment, List.toUint256Array(chainIdsInvolved));

            // Add the quote for the current chain if it is not already included in the sum
            if (!List.contains(chainIdsInvolved, chainId)) {
                quoteAmount += PaymentInfo.findCostForChain(args.payment, chainId);
            }

            // Skip if there is not enough net payment balance on this chain
            if (netPaymentAssetBalanceOnChain < quoteAmount) {
                continue;
            }

            (string memory assetResult, address assetAddress) =
                BuilderPackHelper.knownAssetAddress(paymentTokenSymbol, chainId);

            if (Strings.isError(assetResult) || assetAddress != paymentAssetPositions.asset) {
                return (
                    IQuarkWallet.QuarkOperation(bytes32(0), false, address(0), new bytes[](0), "", 0),
                    Actions.Action(0, address(0), "", "", "", "", bytes32(0), 0),
                    ERROR_NO_KNOWN_PAYMENT_TOKEN,
                    quoteAmount
                );
            }

            // TODO: Right now we don't support multiple accounts
            address payer = paymentAssetPositions.accountBalances[0].account;

            (IQuarkWallet.QuarkOperation memory quotePayOperation, Actions.Action memory quotePayAction) = Actions
                .quotePay(
                Actions.QuotePayInfo({
                    chainAccountsList: args.chainAccountsList,
                    assetSymbol: paymentTokenSymbol,
                    amount: quoteAmount,
                    chainId: chainId,
                    sender: payer,
                    blockTimestamp: args.blockTimestamp
                }),
                args.payment
            );

            return (quotePayOperation, quotePayAction, Strings.OK, quoteAmount);
        }

        // Unable to construct a proper quote pay, so we try to find a chain that has enough of the payment token and then construct the totalQuoteAmount based on that.
        // Then we throw an error that contains the total quote amount.
        uint256 totalQuoteAmount;
        bool eligibleChainFound;
        // TODO: As an optimization, we can search for the chain that gives us the lowest totalQuoteAmount
        for (uint256 i = 0; i < args.chainAccountsList.length; ++i) {
            uint256 chainId = args.chainAccountsList[i].chainId;

            // Calculate the net payment balance on this chain
            // TODO: Need to be modified when supporting multiple accounts per chain, since this currently assumes all assets are in one account.
            //       Will need a 2D map for assetsIn/Out to map from chainId -> account
            Accounts.AssetPositions memory paymentAssetPositions =
                Accounts.findAssetPositions(paymentTokenSymbol, args.chainAccountsList[i].assetPositionsList);
            uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(paymentAssetPositions);

            if (paymentAssetBalanceOnChain == 0) {
                continue;
            }

            // Generate quote amount based on which chains have an operation on them
            totalQuoteAmount = PaymentInfo.totalCost(args.payment, List.toUint256Array(chainIdsInvolved));
            // Add the quote for the current chain if it is not already included in the sum
            if (!List.contains(chainIdsInvolved, chainId)) {
                totalQuoteAmount += PaymentInfo.findCostForChain(args.payment, chainId);
            }

            if (paymentAssetBalanceOnChain >= totalQuoteAmount) {
                eligibleChainFound = true;
                break;
            }
        }

        return (
            IQuarkWallet.QuarkOperation(bytes32(0), false, address(0), new bytes[](0), "", 0),
            Actions.Action(0, address(0), "", "", "", "", bytes32(0), 0),
            eligibleChainFound ? ERROR_UNABLE_TO_CONSTRUCT : ERROR_IMPOSSIBLE_TO_CONSTRUCT,
            totalQuoteAmount
        );
    }

    /**
     * @dev Assert that there are sufficient payment tokens for a recurring transaction that uses Paycall
     */
    function assertSufficientPaymentTokensForPaycall(PaymentBalanceAssertionArgs memory args) internal pure {
        // Tracks the payment assets that are leaving and entering each chain
        HashMap.Map memory assetsInPerChain = HashMap.newMap();
        HashMap.Map memory assetsOutPerChain = HashMap.newMap();

        string memory paymentTokenSymbol = args.payment.currency;
        for (uint256 i = 0; i < args.actions.length; ++i) {
            Actions.Action memory action = args.actions[i];

            trackAssetsInAndOut({
                assetsInPerChain: assetsInPerChain,
                assetsOutPerChain: assetsOutPerChain,
                action: action,
                chainAccountsList: args.chainAccountsList,
                paymentTokenSymbol: paymentTokenSymbol,
                account: args.account
            });
        }

        uint256 chainId = args.targetChainId;
        uint256 maxCost = PaymentInfo.findCostForChain(args.payment, chainId);
        Accounts.ChainAccounts memory chainAccount = Accounts.findChainAccounts(chainId, args.chainAccountsList);

        Accounts.AssetPositions memory paymentAssetPositions =
            Accounts.findAssetPositions(paymentTokenSymbol, chainAccount.assetPositionsList);
        uint256 paymentAssetBalanceOnChain = Accounts.sumBalances(paymentAssetPositions);

        if (
            paymentAssetBalanceOnChain + HashMap.getOrDefaultUint256(assetsInPerChain, abi.encode(chainId), 0)
                < HashMap.getOrDefaultUint256(assetsOutPerChain, abi.encode(chainId), 0)
        ) {
            // Note: This should be unreachable. Something is very wrong if this hits!
            revert BalanceNotRight(
                paymentAssetBalanceOnChain,
                HashMap.getOrDefaultUint256(assetsInPerChain, abi.encode(chainId), 0),
                HashMap.getOrDefaultUint256(assetsOutPerChain, abi.encode(chainId), 0)
            );
        }

        uint256 netPaymentAssetBalanceOnChain = paymentAssetBalanceOnChain
            + HashMap.getOrDefaultUint256(assetsInPerChain, abi.encode(chainId), 0)
            - HashMap.getOrDefaultUint256(assetsOutPerChain, abi.encode(chainId), 0);

        if (netPaymentAssetBalanceOnChain < maxCost) {
            revert UnableToConstructPaycall(paymentTokenSymbol, maxCost);
        }
    }

    /**
     * @dev Tracks how much of each asset is entering and leaving an account on each chain for an action.
     *      This function writes the amounts directly into the two HashMaps (`assetsInPerChain` and `assetsOutPerChain`)
     */
    function trackAssetsInAndOut(
        HashMap.Map memory assetsInPerChain,
        HashMap.Map memory assetsOutPerChain,
        Actions.Action memory action,
        Accounts.ChainAccounts[] memory chainAccountsList,
        string memory paymentTokenSymbol,
        address account
    ) internal pure {
        // Depending on the action type, update the `assetsInPerChain` and/or `assetsOutPerChain` maps
        if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_BRIDGE)) {
            Actions.BridgeActionContext memory bridgeActionContext =
                abi.decode(action.actionContext, (Actions.BridgeActionContext));
            // For Across, we're treating the output token as ETH since we'll cover WETH in the `wrapAllEth` action, below.
            // N.B. We will still treat the in-asset as ETH and reduce that balance on the source chain.
            string memory outAssetSymbol = bridgeActionContext.assetSymbol;
            if (
                Strings.stringEqIgnoreCase(outAssetSymbol, "WETH")
                    && Strings.stringEqIgnoreCase(bridgeActionContext.bridgeType, Actions.BRIDGE_TYPE_ACROSS)
            ) {
                outAssetSymbol = "ETH";
            }

            if (Strings.stringEqIgnoreCase(outAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain,
                    abi.encode(bridgeActionContext.destinationChainId),
                    bridgeActionContext.outputAmount
                );
            }
            if (Strings.stringEqIgnoreCase(bridgeActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(bridgeActionContext.chainId), bridgeActionContext.inputAmount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_BORROW)) {
            Actions.BorrowActionContext memory borrowActionContext =
                abi.decode(action.actionContext, (Actions.BorrowActionContext));
            if (Strings.stringEqIgnoreCase(borrowActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain, abi.encode(borrowActionContext.chainId), borrowActionContext.amount
                );
            }

            for (uint256 j = 0; j < borrowActionContext.collateralAssetSymbols.length; ++j) {
                if (Strings.stringEqIgnoreCase(borrowActionContext.collateralAssetSymbols[j], paymentTokenSymbol)) {
                    HashMap.addOrPutUint256(
                        assetsOutPerChain,
                        abi.encode(borrowActionContext.chainId),
                        borrowActionContext.collateralAmounts[j]
                    );
                }
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_MORPHO_BORROW)) {
            Actions.MorphoBorrowActionContext memory borrowActionContext =
                abi.decode(action.actionContext, (Actions.MorphoBorrowActionContext));
            if (Strings.stringEqIgnoreCase(borrowActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain, abi.encode(borrowActionContext.chainId), borrowActionContext.amount
                );
            }
            if (Strings.stringEqIgnoreCase(borrowActionContext.collateralAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(borrowActionContext.chainId), borrowActionContext.collateralAmount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_CLAIM_REWARDS)) {
            Actions.ClaimRewardsActionContext memory claimRewardActionContext =
                abi.decode(action.actionContext, (Actions.ClaimRewardsActionContext));
            if (Strings.stringEqIgnoreCase(claimRewardActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain, abi.encode(claimRewardActionContext.chainId), claimRewardActionContext.amount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_MORPHO_CLAIM_REWARDS)) {
            Actions.MorphoClaimRewardsActionContext memory claimRewardActionContext =
                abi.decode(action.actionContext, (Actions.MorphoClaimRewardsActionContext));
            for (uint256 j = 0; j < claimRewardActionContext.assetSymbols.length; ++j) {
                if (Strings.stringEqIgnoreCase(claimRewardActionContext.assetSymbols[j], paymentTokenSymbol)) {
                    HashMap.addOrPutUint256(
                        assetsInPerChain,
                        abi.encode(claimRewardActionContext.chainId),
                        claimRewardActionContext.amounts[j]
                    );
                }
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_MORPHO_REPAY)) {
            Actions.MorphoRepayActionContext memory morphoRepayActionContext =
                abi.decode(action.actionContext, (Actions.MorphoRepayActionContext));
            if (Strings.stringEqIgnoreCase(morphoRepayActionContext.assetSymbol, paymentTokenSymbol)) {
                uint256 repayAmount;
                if (morphoRepayActionContext.amount == type(uint256).max) {
                    repayAmount = morphoRepayMaxAmount(
                        chainAccountsList,
                        morphoRepayActionContext.chainId,
                        morphoRepayActionContext.token,
                        morphoRepayActionContext.collateralToken,
                        account
                    );
                } else {
                    repayAmount = morphoRepayActionContext.amount;
                }
                HashMap.addOrPutUint256(assetsOutPerChain, abi.encode(morphoRepayActionContext.chainId), repayAmount);
            }
            if (Strings.stringEqIgnoreCase(morphoRepayActionContext.collateralAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain,
                    abi.encode(morphoRepayActionContext.chainId),
                    morphoRepayActionContext.collateralAmount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_REPAY)) {
            Actions.RepayActionContext memory cometRepayActionContext =
                abi.decode(action.actionContext, (Actions.RepayActionContext));
            if (Strings.stringEqIgnoreCase(cometRepayActionContext.assetSymbol, paymentTokenSymbol)) {
                uint256 repayAmount;
                if (cometRepayActionContext.amount == type(uint256).max) {
                    repayAmount = cometRepayMaxAmount(
                        chainAccountsList, cometRepayActionContext.chainId, cometRepayActionContext.comet, account
                    );
                } else {
                    repayAmount = cometRepayActionContext.amount;
                }
                HashMap.addOrPutUint256(assetsOutPerChain, abi.encode(cometRepayActionContext.chainId), repayAmount);
            }

            for (uint256 j = 0; j < cometRepayActionContext.collateralAssetSymbols.length; ++j) {
                if (Strings.stringEqIgnoreCase(cometRepayActionContext.collateralAssetSymbols[j], paymentTokenSymbol)) {
                    HashMap.addOrPutUint256(
                        assetsInPerChain,
                        abi.encode(cometRepayActionContext.chainId),
                        cometRepayActionContext.collateralAmounts[j]
                    );
                }
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_SUPPLY)) {
            Actions.SupplyActionContext memory cometSupplyActionContext =
                abi.decode(action.actionContext, (Actions.SupplyActionContext));
            if (Strings.stringEqIgnoreCase(cometSupplyActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(cometSupplyActionContext.chainId), cometSupplyActionContext.amount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_MORPHO_VAULT_SUPPLY)) {
            Actions.MorphoVaultSupplyActionContext memory morphoVaultSupplyActionContext =
                abi.decode(action.actionContext, (Actions.MorphoVaultSupplyActionContext));
            if (Strings.stringEqIgnoreCase(morphoVaultSupplyActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain,
                    abi.encode(morphoVaultSupplyActionContext.chainId),
                    morphoVaultSupplyActionContext.amount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_SWAP)) {
            Actions.SwapActionContext memory swapActionContext =
                abi.decode(action.actionContext, (Actions.SwapActionContext));
            if (Strings.stringEqIgnoreCase(swapActionContext.inputAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(swapActionContext.chainId), swapActionContext.inputAmount
                );
            }
            if (Strings.stringEqIgnoreCase(swapActionContext.outputAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain, abi.encode(swapActionContext.chainId), swapActionContext.outputAmount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_RECURRING_SWAP)) {
            Actions.RecurringSwapActionContext memory recurringSwapActionContext =
                abi.decode(action.actionContext, (Actions.RecurringSwapActionContext));
            if (Strings.stringEqIgnoreCase(recurringSwapActionContext.inputAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain,
                    abi.encode(recurringSwapActionContext.chainId),
                    recurringSwapActionContext.inputAmount
                );
            }
            if (Strings.stringEqIgnoreCase(recurringSwapActionContext.outputAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain,
                    abi.encode(recurringSwapActionContext.chainId),
                    recurringSwapActionContext.outputAmount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_TRANSFER)) {
            Actions.TransferActionContext memory transferActionContext =
                abi.decode(action.actionContext, (Actions.TransferActionContext));
            if (Strings.stringEqIgnoreCase(transferActionContext.assetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(transferActionContext.chainId), transferActionContext.amount
                );
            }
        } else if (
            Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_UNWRAP)
                || Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_WRAP)
        ) {
            Actions.WrapOrUnwrapActionContext memory wrapOrUnwrapActionContext =
                abi.decode(action.actionContext, (Actions.WrapOrUnwrapActionContext));
            if (Strings.stringEqIgnoreCase(wrapOrUnwrapActionContext.toAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsInPerChain, abi.encode(wrapOrUnwrapActionContext.chainId), wrapOrUnwrapActionContext.amount
                );
            }
            if (Strings.stringEqIgnoreCase(wrapOrUnwrapActionContext.fromAssetSymbol, paymentTokenSymbol)) {
                HashMap.addOrPutUint256(
                    assetsOutPerChain, abi.encode(wrapOrUnwrapActionContext.chainId), wrapOrUnwrapActionContext.amount
                );
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_WITHDRAW)) {
            Actions.WithdrawActionContext memory withdrawActionContext =
                abi.decode(action.actionContext, (Actions.WithdrawActionContext));
            if (Strings.stringEqIgnoreCase(withdrawActionContext.assetSymbol, paymentTokenSymbol)) {
                // If withdrawing max, we need to calculate the approximate amount that will be withdrawn
                uint256 withdrawAmount = withdrawActionContext.amount == type(uint256).max
                    ? cometWithdrawMaxAmount(
                        chainAccountsList, withdrawActionContext.chainId, withdrawActionContext.comet, account
                    )
                    : withdrawActionContext.amount;
                HashMap.addOrPutUint256(assetsInPerChain, abi.encode(withdrawActionContext.chainId), withdrawAmount);
            }
        } else if (Strings.stringEqIgnoreCase(action.actionType, Actions.ACTION_TYPE_MORPHO_VAULT_WITHDRAW)) {
            Actions.MorphoVaultWithdrawActionContext memory withdrawActionContext =
                abi.decode(action.actionContext, (Actions.MorphoVaultWithdrawActionContext));
            if (Strings.stringEqIgnoreCase(withdrawActionContext.assetSymbol, paymentTokenSymbol)) {
                // If withdrawing max, we need to calculate the approximate amount that will be withdrawn
                uint256 withdrawAmount = withdrawActionContext.amount == type(uint256).max
                    ? morphoWithdrawMaxAmount(
                        chainAccountsList, withdrawActionContext.chainId, withdrawActionContext.assetSymbol, account
                    )
                    : withdrawActionContext.amount;
                HashMap.addOrPutUint256(assetsInPerChain, abi.encode(withdrawActionContext.chainId), withdrawAmount);
            }
        } else {
            revert InvalidActionType();
        }
    }

    function getWrapperCounterpartBalance(
        string memory assetSymbol,
        uint256 chainId,
        Accounts.ChainAccounts[] memory chainAccountsList
    ) internal pure returns (uint256) {
        if (TokenWrapper.hasWrapperContract(chainId, assetSymbol)) {
            // Add counterpart balance to balanceOnChain
            return Accounts.getBalanceOnChain(
                TokenWrapper.getWrapperCounterpartSymbol(chainId, assetSymbol), chainId, chainAccountsList
            );
        }

        revert MissingWrapperCounterpart();
    }

    function getBalanceOnChainIncludingCounterpart(
        string memory assetSymbol,
        uint256 chainId,
        Accounts.ChainAccounts[] memory chainAccountsList
    ) internal pure returns (uint256) {
        uint256 balanceOnChain = Accounts.getBalanceOnChain(assetSymbol, chainId, chainAccountsList);

        // If there exists a counterpart token, try to wrap/unwrap first before attempting to bridge
        if (TokenWrapper.hasWrapperContract(chainId, assetSymbol)) {
            // TODO: This won't work for wrapper contracts that are not 1:1 with the underlying (e.g. wstETH vs stETH)
            uint256 counterpartBalance = getWrapperCounterpartBalance(assetSymbol, chainId, chainAccountsList);
            balanceOnChain += counterpartBalance;
        }

        return balanceOnChain;
    }

    function getAmountNeededOnChain(
        string memory assetSymbol,
        uint256 amount,
        uint256 chainId,
        PaymentInfo.Payment memory payment
    ) internal pure returns (uint256) {
        // If action and payment token are the same, then add the payment cost for the target chain to the amount needed
        uint256 amountNeededOnChain = amount;
        if (Strings.stringEqIgnoreCase(payment.currency, assetSymbol)) {
            amountNeededOnChain += PaymentInfo.findCostForChain(payment, chainId);
        }

        return amountNeededOnChain;
    }

    // Stub to ensure that unused errors make it in the ABI
    function includeErrors() external pure returns (uint256) {
        if (true) {
            return 0;
        } else {
            revert Errors.BridgeAmountTooLow();
        }
    }
}
