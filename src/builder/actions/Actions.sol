// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {console} from "src/builder/console.sol";

import {Accounts} from "src/builder/Accounts.sol";
import {Across, BridgeRoutes, CCTP} from "src/builder/BridgeRoutes.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {Math} from "src/lib/Math.sol";
import {PriceFeeds} from "src/builder/PriceFeeds.sol";
import {Strings} from "src/builder/Strings.sol";
import {UniswapRouter} from "src/builder/UniswapRouter.sol";

import {
    ApproveAndSwap,
    CometRepayAndWithdrawMultipleAssets,
    CometClaimRewards as CometClaimRewardsActions,
    CometSupplyActions,
    CometSupplyMultipleAssetsAndBorrow,
    CometWithdrawActions,
    TransferActions
} from "src/DeFiScripts.sol";
import {Math} from "src/lib/Math.sol";
import {MorphoActions, MorphoRewardsActions, MorphoVaultActions} from "src/MorphoScripts.sol";
import {QuotePay} from "src/QuotePay.sol";
import {RecurringSwap} from "src/RecurringSwap.sol";
import {WrapperActions} from "src/WrapperScripts.sol";
import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";
import {IMorpho, Position} from "src/interfaces/IMorpho.sol";
import {FFI} from "src/builder/FFI.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {List} from "src/builder/List.sol";

library Actions {
    /* ===== Constants ===== */
    // TODO: (LHT-86) Rename ACTION_TYPE_BORROW to ACTION_TYPE_COMET_BORROW, as now we have more than one borrow market
    string constant ACTION_TYPE_BORROW = "BORROW";
    string constant ACTION_TYPE_MORPHO_BORROW = "MORPHO_BORROW";
    string constant ACTION_TYPE_BRIDGE = "BRIDGE";
    string constant ACTION_TYPE_COMET_CLAIM_REWARDS = "COMET_CLAIM_REWARDS";
    string constant ACTION_TYPE_MORPHO_CLAIM_REWARDS = "MORPHO_CLAIM_REWARDS";
    string constant ACTION_TYPE_DRIP_TOKENS = "DRIP_TOKENS";
    string constant ACTION_TYPE_RECURRING_SWAP = "RECURRING_SWAP";
    // TODO: (LHT-86) Rename ACTION_TYPE_REPAY to ACTION_TYPE_COMET_REPAY, as now we have more than one borrow market
    string constant ACTION_TYPE_REPAY = "REPAY";
    string constant ACTION_TYPE_MORPHO_REPAY = "MORPHO_REPAY";
    string constant ACTION_TYPE_COMET_SUPPLY = "COMET_SUPPLY";
    string constant ACTION_TYPE_SUPPLY = "SUPPLY";
    string constant ACTION_TYPE_MORPHO_VAULT_SUPPLY = "MORPHO_VAULT_SUPPLY";
    string constant ACTION_TYPE_SWAP = "SWAP";
    string constant ACTION_TYPE_TRANSFER = "TRANSFER";
    string constant ACTION_TYPE_COMET_WITHDRAW = "COMET_WITHDRAW";
    string constant ACTION_TYPE_WITHDRAW = "WITHDRAW";
    string constant ACTION_TYPE_MORPHO_VAULT_WITHDRAW = "MORPHO_VAULT_WITHDRAW";
    string constant ACTION_TYPE_WITHDRAW_AND_BORROW = "WITHDRAW_AND_BORROW";
    string constant ACTION_TYPE_WRAP = "WRAP";
    string constant ACTION_TYPE_UNWRAP = "UNWRAP";
    string constant ACTION_TYPE_QUOTE_PAY = "QUOTE_PAY";

    string constant EXECUTION_TYPE_IMMEDIATE = "IMMEDIATE";
    string constant EXECUTION_TYPE_DELAYED = "DELAYED";
    string constant EXECUTION_TYPE_RECURRENT = "RECURRENT";
    string constant EXECUTION_TYPE_CONTINGENT = "CONTINGENT";

    string constant BRIDGE_TYPE_ACROSS = "ACROSS";
    string constant BRIDGE_TYPE_CCTP = "CCTP";

    /* expiry buffers */
    uint256 constant STANDARD_EXPIRY_BUFFER = 7 days;

    uint256 constant BRIDGE_EXPIRY_BUFFER = 7 days;
    uint256 constant SWAP_EXPIRY_BUFFER = 3 days;
    uint256 constant TRANSFER_EXPIRY_BUFFER = 7 days;

    /* total plays */
    uint256 constant RECURRING_SWAP_TOTAL_PLAYS = 500;

    uint256 constant AVERAGE_BLOCK_TIME = 12 seconds;
    uint256 constant RECURRING_SWAP_MAX_SLIPPAGE = 1e17; // 1%
    uint256 constant RECURRING_SWAP_WINDOW_LENGTH = 1 days;

    // TODO: Move to BuilderPack
    address constant QUOTE_PAY_RECIPIENT = 0x7ea8d6119596016935543d90Ee8f5126285060A1;

    /* ===== Custom Errors ===== */

    error BridgingUnsupportedForAsset();
    error InvalidAssetForBridge();
    error InvalidAssetForWrappingAction();

    /* ===== Input Types ===== */

    struct BridgeAsset {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 srcChainId;
        uint256 srcBalance;
        address sender;
        uint256 destinationChainId;
        address recipient;
        uint256 blockTimestamp;
    }

    struct CometClaimRewards {
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 blockTimestamp;
        address claimer;
    }

    struct CometSupply {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 chainId;
        address comet;
        address sender;
        uint256 blockTimestamp;
    }

    struct CometWithdraw {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 chainId;
        address comet;
        address withdrawer;
        uint256 blockTimestamp;
    }

    struct WrapOrUnwrapAsset {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amountNeeded;
        uint256 balanceOnChain;
        uint256 chainId;
        address sender;
        uint256 blockTimestamp;
    }

    struct ZeroExSwap {
        Accounts.ChainAccounts[] chainAccountsList;
        address entryPoint;
        bytes swapData;
        address sellToken;
        string sellAssetSymbol;
        uint256 sellAmount;
        address buyToken;
        string buyAssetSymbol;
        uint256 buyAmount;
        address feeToken;
        string feeAssetSymbol;
        uint256 feeAmount;
        uint256 chainId;
        address sender;
        bool isExactOut;
        uint256 blockTimestamp;
    }

    struct RecurringSwapParams {
        Accounts.ChainAccounts[] chainAccountsList;
        address sellToken;
        string sellAssetSymbol;
        uint256 sellAmount;
        address buyToken;
        string buyAssetSymbol;
        uint256 buyAmount;
        bool isExactOut;
        bytes path;
        uint256 interval;
        uint256 chainId;
        address sender;
        uint256 blockTimestamp;
    }

    struct TransferAsset {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 chainId;
        address sender;
        address recipient;
        uint256 blockTimestamp;
    }

    struct CometBorrowInput {
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        address borrower;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        address comet;
    }

    struct CometRepayInput {
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        address comet;
        address repayer;
    }

    struct MorphoBorrow {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        address borrower;
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 chainId;
        uint256 collateralAmount;
        string collateralAssetSymbol;
    }

    struct MorphoRepay {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        uint256 chainId;
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 collateralAmount;
        string collateralAssetSymbol;
        address repayer;
    }

    struct MorphoVaultSupply {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 blockTimestamp;
        uint256 chainId;
        address sender;
    }

    struct MorphoVaultWithdraw {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 blockTimestamp;
        uint256 chainId;
        address withdrawer;
    }

    struct MorphoClaimRewards {
        Accounts.ChainAccounts[] chainAccountsList;
        uint256 blockTimestamp;
        address claimer;
    }

    struct QuotePayInfo {
        Accounts.ChainAccounts[] chainAccountsList;
        string assetSymbol;
        uint256 amount;
        uint256 chainId;
        address sender;
        uint256 blockTimestamp;
    }

    // Note: Mainly to avoid stack too deep errors
    struct BridgeOperationInfo {
        string assetSymbol;
        uint256 amountNeededOnDst;
        uint256 dstChainId;
        address recipient;
        uint256 blockTimestamp;
        bool preferAcross;
    }

    // Note: To avoid stack too deep errors
    struct RecurringSwapLocalVars {
        Accounts.ChainAccounts accounts;
        Accounts.AssetPositions sellTokenAssetPositions;
        Accounts.AssetPositions buyTokenAssetPositions;
        Accounts.QuarkSecret accountSecret;
    }

    /* ===== Output Types ===== */

    // With Action, we try to define fields that are as 1:1 as possible with
    // the simulate endpoint request schema.
    struct Action {
        uint256 chainId;
        address quarkAccount;
        string actionType;
        bytes actionContext;
        // The action context for a QuotePay, if one exists for this operation. Otherwise, empty bytes
        bytes quotePayActionContext;
        // One of the PaymentInfo.PAYMENT_METHOD_* constants.
        string paymentMethod;
        // The secret used to generate the hash chain for a replayable operation. For non-replayable
        // operations, the `nonce` will be the `nonceSecret` (the hash chain has a length of 1)
        bytes32 nonceSecret;
        // The number of times an operation can be played. For non-replayable operations, this will be 1
        uint256 totalPlays;
        // The execution type for the Quark operation (e.g. immediate, delayed, recurrent, contingent)
        string executionType;
    }

    struct BorrowActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        uint256[] collateralTokenPrices;
        address[] collateralTokens;
        address comet;
        uint256 price;
        address token;
    }

    struct BridgeActionContext {
        string assetSymbol;
        string bridgeType;
        uint256 chainId;
        uint256 destinationChainId;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 price;
        address recipient;
        address token;
    }

    struct CometClaimRewardsActionContext {
        uint256[] amounts;
        string[] assetSymbols;
        uint256 chainId;
        uint256[] prices;
        address[] tokens;
    }

    struct DripTokensActionContext {
        uint256 chainId;
    }

    struct RepayActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        uint256[] collateralTokenPrices;
        address[] collateralTokens;
        address comet;
        uint256 price;
        address token;
    }

    struct CometSupplyActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        address comet;
        uint256 price;
        address token;
    }

    struct MorphoVaultSupplyActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        address morphoVault;
        uint256 price;
        address token;
    }

    struct SwapActionContext {
        uint256 chainId;
        uint256 feeAmount;
        string feeAssetSymbol;
        address feeToken;
        uint256 feeTokenPrice;
        uint256 inputAmount;
        string inputAssetSymbol;
        address inputToken;
        uint256 inputTokenPrice;
        // Note: The output amount should be inclusive of the feeAmount
        uint256 outputAmount;
        string outputAssetSymbol;
        address outputToken;
        uint256 outputTokenPrice;
        bool isExactOut;
    }

    struct RecurringSwapActionContext {
        uint256 chainId;
        uint256 inputAmount;
        string inputAssetSymbol;
        address inputToken;
        uint256 inputTokenPrice;
        uint256 outputAmount;
        string outputAssetSymbol;
        address outputToken;
        uint256 outputTokenPrice;
        bool isExactOut;
        uint256 interval;
    }

    struct TransferActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256 price;
        address recipient;
        address token;
    }

    struct CometWithdrawActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        address comet;
        uint256 price;
        address token;
    }

    struct MorphoVaultWithdrawActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        address morphoVault;
        uint256 price;
        address token;
    }

    struct WithdrawAndBorrowActionContext {
        uint256 borrowAmount;
        uint256 chainId;
        uint256[] collateralAmounts;
        uint256[] collateralTokenPrices;
        address[] collateralTokens;
        address comet;
        uint256 price;
        address token;
        uint256 withdrawAmount;
    }

    struct WrapOrUnwrapActionContext {
        uint256 chainId;
        uint256 amount;
        address token;
        string fromAssetSymbol;
        string toAssetSymbol;
    }

    struct MorphoRepayActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256 collateralAmount;
        string collateralAssetSymbol;
        uint256 collateralTokenPrice;
        address collateralToken;
        address morpho;
        bytes32 morphoMarketId;
        uint256 price;
        address token;
    }

    struct MorphoBorrowActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256 collateralAmount;
        string collateralAssetSymbol;
        uint256 collateralTokenPrice;
        address collateralToken;
        address morpho;
        bytes32 morphoMarketId;
        uint256 price;
        address token;
    }

    struct MorphoClaimRewardsActionContext {
        uint256[] amounts;
        string[] assetSymbols;
        uint256 chainId;
        uint256[] prices;
        address[] tokens;
    }

    struct QuotePayActionContext {
        uint256 amount;
        string assetSymbol;
        uint256 chainId;
        uint256 price;
        address payee;
        bytes32 quoteId;
        address token;
    }

    function constructBridgeOperations(
        BridgeOperationInfo memory bridgeInfo,
        Accounts.ChainAccounts[] memory chainAccountsList,
        PaymentInfo.Payment memory payment
    ) internal pure returns (IQuarkWallet.QuarkOperation[] memory, Action[] memory, uint256, uint256) {
        /*
         * at most one bridge operation per non-destination chain,
         * and at most one transferIntent operation on the destination chain.
         *
         * therefore the upper bound is chainAccountsList.length.
         */
        List.DynamicArray memory actions = List.newList();
        List.DynamicArray memory quarkOperations = List.newList();
        IQuarkWallet.QuarkOperation memory wrapOrUnwrapOperation;
        Actions.Action memory wrapOrUnwrapAction;

        // Note: Assumes that the asset uses the same # of decimals on each chain
        uint256 balanceOnDstChain =
            Accounts.getBalanceOnChain(bridgeInfo.assetSymbol, bridgeInfo.dstChainId, chainAccountsList);
        uint256 amountLeftToBridge = bridgeInfo.amountNeededOnDst - balanceOnDstChain;

        // TODO: Need to augment with some logic to handle WETH/ETH if using Across. Also, we need to check if the counterpart token can/should be bridged
        // Check to see if there are counterpart tokens on the destination chain that can be used. If there are, subtract the balance from `amountLeftToBridge`
        if (TokenWrapper.hasWrapperContract(bridgeInfo.dstChainId, bridgeInfo.assetSymbol)) {
            string memory counterpartSymbol =
                TokenWrapper.getWrapperCounterpartSymbol(bridgeInfo.dstChainId, bridgeInfo.assetSymbol);
            uint256 counterpartBalanceOnDstChain =
                Accounts.getBalanceOnChain(counterpartSymbol, bridgeInfo.dstChainId, chainAccountsList);
            uint256 counterpartTokenAmountToUse =
                counterpartBalanceOnDstChain >= amountLeftToBridge ? amountLeftToBridge : counterpartBalanceOnDstChain;

            // NOTE: Only adjusts amountLeftToBridge, the real wrapping/unwrapping will be done outside of the construct bridge operation function
            // Update amountLeftToBridge
            amountLeftToBridge -= counterpartTokenAmountToUse;
        }

        uint256 totalBridgeFees = 0;
        // Iterate chainAccountList and find chains that can provide enough funds to bridge.
        // One optimization is to allow the client to provide optimal routes.
        for (uint256 i = 0; i < chainAccountsList.length; ++i) {
            // End loop if enough tokens have been bridged
            if (amountLeftToBridge == 0) {
                break;
            }

            Accounts.ChainAccounts memory srcChainAccounts = chainAccountsList[i];
            // Skip if the current chain is the target chain, since bridging is not possible
            if (srcChainAccounts.chainId == bridgeInfo.dstChainId) {
                continue;
            }

            // Skip if there is no bridge route for the current chain to the target chain
            if (!BridgeRoutes.canBridge(srcChainAccounts.chainId, bridgeInfo.dstChainId, bridgeInfo.assetSymbol)) {
                continue;
            }

            string memory counterpartSymbol =
                TokenWrapper.getWrapperCounterpartSymbol(srcChainAccounts.chainId, bridgeInfo.assetSymbol);

            Accounts.AssetPositions memory srcAssetPositions =
                Accounts.findAssetPositions(bridgeInfo.assetSymbol, srcChainAccounts.assetPositionsList);
            Accounts.AccountBalance[] memory srcAccountBalances = srcAssetPositions.accountBalances;

            Accounts.AssetPositions memory srcCounterpartAssetPositions =
                Accounts.findAssetPositions(counterpartSymbol, srcChainAccounts.assetPositionsList);
            Accounts.AccountBalance[] memory srcCounterpartAccountBalances =
                srcCounterpartAssetPositions.accountBalances;
            // TODO: Make logic smarter. Currently, this uses a greedy algorithm.
            // e.g. Optimize by trying to bridge with the least amount of bridge operations
            for (uint256 j = 0; j < srcAccountBalances.length; ++j) {
                uint256 counterpartBalance =
                    Accounts.balanceForAccount(srcCounterpartAccountBalances, srcAccountBalances[j].account);
                uint256 amountToBridge;

                if (srcAccountBalances[j].balance >= amountLeftToBridge) {
                    amountToBridge = amountLeftToBridge;
                } else {
                    if (counterpartBalance > 0) {
                        (wrapOrUnwrapOperation, wrapOrUnwrapAction) = Actions.wrapOrUnwrapAsset(
                            Actions.WrapOrUnwrapAsset({
                                chainAccountsList: chainAccountsList,
                                assetSymbol: counterpartSymbol,
                                amountNeeded: counterpartBalance > amountToBridge ? amountToBridge : counterpartBalance,
                                balanceOnChain: counterpartBalance,
                                chainId: srcChainAccounts.chainId,
                                sender: srcAccountBalances[j].account,
                                blockTimestamp: bridgeInfo.blockTimestamp
                            }),
                            payment,
                            false
                        );

                        List.addAction(actions, wrapOrUnwrapAction);
                        List.addQuarkOperation(quarkOperations, wrapOrUnwrapOperation);
                    }

                    amountToBridge = srcAccountBalances[j].balance + counterpartBalance >= amountLeftToBridge
                        ? amountLeftToBridge
                        : srcAccountBalances[j].balance + counterpartBalance;
                }

                if (amountToBridge > 0) {
                    (
                        IQuarkWallet.QuarkOperation memory operation,
                        Actions.Action memory action,
                        uint256 inputAmount,
                        uint256 outputAmount
                    ) = bridgeAsset(
                        BridgeAsset({
                            chainAccountsList: chainAccountsList,
                            assetSymbol: bridgeInfo.assetSymbol,
                            amount: amountToBridge,
                            // where it comes from
                            srcChainId: srcChainAccounts.chainId,
                            srcBalance: srcAccountBalances[j].balance + counterpartBalance,
                            sender: srcAccountBalances[j].account,
                            // where it goes
                            destinationChainId: bridgeInfo.dstChainId,
                            recipient: bridgeInfo.recipient,
                            blockTimestamp: bridgeInfo.blockTimestamp
                        }),
                        payment,
                        bridgeInfo.preferAcross
                    );

                    // We only want to append the quark operation and action if a non-zero amount is bridged
                    if (outputAmount > 0) {
                        amountLeftToBridge = Math.subtractFlooredAtZero(amountLeftToBridge, outputAmount);
                        totalBridgeFees += (inputAmount - outputAmount);

                        List.addAction(actions, action);
                        List.addQuarkOperation(quarkOperations, operation);
                    }
                }
            }
        }

        // Convert actions and quark operations to arrays
        return (
            List.toQuarkOperationArray(quarkOperations),
            List.toActionArray(actions),
            amountLeftToBridge,
            totalBridgeFees
        );
    }

    function bridgeAsset(BridgeAsset memory bridge, PaymentInfo.Payment memory payment, bool preferAcross)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory, uint256, uint256)
    {
        bool acrossCanBridge = Across.canBridge(bridge.srcChainId, bridge.destinationChainId, bridge.assetSymbol);
        bool cctpCanBridge = CCTP.canBridge(bridge.srcChainId, bridge.destinationChainId, bridge.assetSymbol);

        // Choose order of actions based on user bridge preference.
        if (preferAcross) {
            if (acrossCanBridge) {
                return bridgeAcross(bridge, payment);
            } else if (cctpCanBridge) {
                return bridgeCCTP(bridge, payment);
            }
        } else {
            if (cctpCanBridge) {
                return bridgeCCTP(bridge, payment);
            } else if (acrossCanBridge) {
                return bridgeAcross(bridge, payment);
            }
        }

        revert BridgingUnsupportedForAsset();
    }

    function bridgeCCTP(BridgeAsset memory bridge, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory, uint256, uint256)
    {
        console.log("Bridging via CCTP", bridge.assetSymbol);

        if (!Strings.stringEqIgnoreCase(bridge.assetSymbol, "USDC")) {
            revert InvalidAssetForBridge();
        }

        Accounts.ChainAccounts memory srcChainAccounts =
            Accounts.findChainAccounts(bridge.srcChainId, bridge.chainAccountsList);

        Accounts.AssetPositions memory srcUSDCPositions =
            Accounts.findAssetPositions("USDC", srcChainAccounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(bridge.sender, srcChainAccounts.quarkSecrets);

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(CCTP.bridgeScriptSource()),
            scriptCalldata: CCTP.encodeBridgeUSDC(
                bridge.srcChainId, bridge.destinationChainId, bridge.amount, bridge.recipient, srcUSDCPositions.asset
            ),
            scriptSources: new bytes[](0),
            expiry: bridge.blockTimestamp + BRIDGE_EXPIRY_BUFFER
        });

        // Construct Action
        BridgeActionContext memory bridgeActionContext = BridgeActionContext({
            price: srcUSDCPositions.usdPrice,
            token: srcUSDCPositions.asset,
            assetSymbol: srcUSDCPositions.symbol,
            inputAmount: bridge.amount,
            outputAmount: bridge.amount,
            chainId: bridge.srcChainId,
            recipient: bridge.recipient,
            destinationChainId: bridge.destinationChainId,
            bridgeType: BRIDGE_TYPE_CCTP
        });

        Action memory action = Actions.Action({
            chainId: bridge.srcChainId,
            quarkAccount: bridge.sender,
            actionType: ACTION_TYPE_BRIDGE,
            actionContext: abi.encode(bridgeActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action, bridge.amount, bridge.amount);
    }

    function bridgeAcross(BridgeAsset memory bridge, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (
            IQuarkWallet.QuarkOperation memory quarkOperation,
            Action memory action,
            uint256 inputAmount,
            uint256 outputAmount
        )
    {
        console.log("Bridging via Across", bridge.assetSymbol);
        console.log("Bridging from", bridge.srcChainId);
        console.log("Bridging to", bridge.destinationChainId);

        Accounts.ChainAccounts memory srcChainAccounts =
            Accounts.findChainAccounts(bridge.srcChainId, bridge.chainAccountsList);

        Accounts.ChainAccounts memory dstChainAccounts =
            Accounts.findChainAccounts(bridge.destinationChainId, bridge.chainAccountsList);

        Accounts.AssetPositions memory srcAssetPositions =
            Accounts.findAssetPositions(bridge.assetSymbol, srcChainAccounts.assetPositionsList);

        Accounts.AssetPositions memory dstAssetPositions =
            Accounts.findAssetPositions(bridge.assetSymbol, dstChainAccounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(bridge.sender, srcChainAccounts.quarkSecrets);

        // Across API requires setting the address of native ETH transfers to the WETH address
        // on the chain
        address srcAsset = srcAssetPositions.asset;
        if (Strings.stringEqIgnoreCase(srcAssetPositions.symbol, "ETH")) {
            srcAsset = TokenWrapper.getWrapperCounterpartAddress(srcChainAccounts.chainId, "ETH");
        }

        address dstAsset = dstAssetPositions.asset;
        if (Strings.stringEqIgnoreCase(dstAssetPositions.symbol, "ETH")) {
            dstAsset = TokenWrapper.getWrapperCounterpartAddress(dstChainAccounts.chainId, "ETH");
        }

        // Make FFI call to fetch a quote from Across API
        (uint256 gasFee, uint256 variableFeePct, uint256 minDeposit) =
            FFI.requestAcrossQuote(srcAsset, dstAsset, bridge.srcChainId, bridge.destinationChainId, bridge.amount);

        // The quote should consist of a fixed gas fee and variable fee. To calculate the input
        // amount, we scale the bridge.amount by the variable fee and add the fixed gas fee to it.
        inputAmount = bridge.amount * (1e18 + variableFeePct) / 1e18 + gasFee;
        outputAmount = bridge.amount;

        // If minDeposit is larger than the inputAmount, then set the inputAmount to be the minDeposit
        if (minDeposit > inputAmount) {
            inputAmount = minDeposit;
            outputAmount = minDeposit * (1e18 - variableFeePct) / 1e18 - gasFee;
        }

        // If inputAmount exceeds the balance on chain, set the inputAmount to be the balance on chain.
        // However, if the balance on chain is less than the minDeposit, this means that a bridge is not
        // possible on this chain so we should skip bridging from it.
        if (inputAmount > bridge.srcBalance) {
            if (minDeposit > bridge.srcBalance) {
                // Bridging is not possible
                return (quarkOperation, action, 0, 0);
            } else {
                inputAmount = bridge.srcBalance;
                outputAmount = bridge.srcBalance * (1e18 - variableFeePct) / 1e18 - gasFee;
            }
        }

        bool useNativeToken = Strings.stringEqIgnoreCase(srcAssetPositions.symbol, "ETH") ? true : false;

        // Construct QuarkOperation
        quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(Across.bridgeScriptSource()),
            scriptCalldata: Across.encodeBridgeAction(
                bridge.srcChainId,
                bridge.destinationChainId,
                srcAsset,
                dstAsset,
                inputAmount,
                outputAmount,
                bridge.sender,
                bridge.recipient,
                bridge.blockTimestamp,
                useNativeToken
            ),
            scriptSources: new bytes[](0),
            expiry: bridge.blockTimestamp + BRIDGE_EXPIRY_BUFFER
        });

        // Construct Action
        BridgeActionContext memory bridgeActionContext = BridgeActionContext({
            price: srcAssetPositions.usdPrice,
            token: srcAssetPositions.asset,
            assetSymbol: srcAssetPositions.symbol,
            chainId: bridge.srcChainId,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            recipient: bridge.recipient,
            destinationChainId: bridge.destinationChainId,
            bridgeType: BRIDGE_TYPE_ACROSS
        });

        action = Actions.Action({
            chainId: bridge.srcChainId,
            quarkAccount: bridge.sender,
            actionType: ACTION_TYPE_BRIDGE,
            actionContext: abi.encode(bridgeActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action, inputAmount, outputAmount);
    }

    function cometBorrow(CometBorrowInput memory borrowInput, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(borrowInput.chainId, borrowInput.chainAccountsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(borrowInput.borrower, accounts.quarkSecrets);

        Accounts.AssetPositions memory borrowAssetPositions =
            Accounts.findAssetPositions(borrowInput.assetSymbol, accounts.assetPositionsList);

        uint256[] memory collateralTokenPrices = new uint256[](borrowInput.collateralAssetSymbols.length);
        address[] memory collateralTokens = new address[](borrowInput.collateralAssetSymbols.length);

        for (uint256 i = 0; i < borrowInput.collateralAssetSymbols.length; ++i) {
            Accounts.AssetPositions memory assetPositions =
                Accounts.findAssetPositions(borrowInput.collateralAssetSymbols[i], accounts.assetPositionsList);
            collateralTokenPrices[i] = assetPositions.usdPrice;
            collateralTokens[i] = assetPositions.asset;
        }

        // XXX handle wrapping ETH?
        bytes memory scriptCalldata = abi.encodeWithSelector(
            CometSupplyMultipleAssetsAndBorrow.run.selector,
            borrowInput.comet,
            collateralTokens,
            borrowInput.collateralAmounts,
            borrowAssetPositions.asset,
            borrowInput.amount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(CometSupplyMultipleAssetsAndBorrow).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: borrowInput.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        BorrowActionContext memory borrowActionContext = BorrowActionContext({
            assetSymbol: borrowInput.assetSymbol,
            amount: borrowInput.amount,
            chainId: borrowInput.chainId,
            collateralAmounts: borrowInput.collateralAmounts,
            collateralTokenPrices: collateralTokenPrices,
            collateralTokens: collateralTokens,
            collateralAssetSymbols: borrowInput.collateralAssetSymbols,
            comet: borrowInput.comet,
            price: borrowAssetPositions.usdPrice,
            token: borrowAssetPositions.asset
        });
        Action memory action = Actions.Action({
            chainId: borrowInput.chainId,
            quarkAccount: borrowInput.borrower,
            actionType: ACTION_TYPE_BORROW,
            actionContext: abi.encode(borrowActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function cometClaimRewards(CometClaimRewards memory claimRewards, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation[] memory, Action[] memory)
    {
        List.DynamicArray memory quarkOperations = List.newList();
        List.DynamicArray memory actions = List.newList();
        // Iterate through each chain and construct a QuarkOperation to claim all rewards for each chain
        for (uint256 i = 0; i < claimRewards.chainAccountsList.length; ++i) {
            uint256 chainId = claimRewards.chainAccountsList[i].chainId;
            Accounts.QuarkSecret memory accountSecret =
                Accounts.findQuarkSecret(claimRewards.claimer, claimRewards.chainAccountsList[i].quarkSecrets);

            // Iterate over each CometPosition for the chain, which each have a list of CometReward
            for (uint256 j = 0; j < claimRewards.chainAccountsList[i].cometPositions.length; ++j) {
                // Collect parameters for claiming rewards for the current CometPosition
                CometClaimRewardsParams memory claimRewardsParams = collectClaimRewardsParams(
                    claimRewards.chainAccountsList[i].cometPositions[j].cometRewards,
                    claimRewards.chainAccountsList[i].cometPositions[j].comet
                );

                // Skip if no rewards to claim
                if (claimRewardsParams.rewardAssets.length == 0) continue;

                (string[] memory rewardsAssetSymbols, uint256[] memory rewardsPrices) = Accounts.getAssetInfo(
                    claimRewardsParams.rewardAssets, claimRewards.chainAccountsList[i].assetPositionsList
                );

                bytes memory scriptCalldata = abi.encodeWithSelector(
                    CometClaimRewardsActions.claim.selector,
                    claimRewardsParams.rewardContracts,
                    claimRewardsParams.comets,
                    claimRewardsParams.accounts
                );

                // Construct QuarkOperation
                IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
                    nonce: accountSecret.nonceSecret,
                    isReplayable: false,
                    scriptAddress: CodeJarHelper.getCodeAddress(type(CometClaimRewardsActions).creationCode),
                    scriptCalldata: scriptCalldata,
                    scriptSources: new bytes[](0),
                    expiry: claimRewards.blockTimestamp + STANDARD_EXPIRY_BUFFER
                });

                CometClaimRewardsActionContext memory claimRewardsActionContext = CometClaimRewardsActionContext({
                    amounts: claimRewardsParams.rewardsOwed,
                    assetSymbols: rewardsAssetSymbols,
                    chainId: chainId,
                    prices: rewardsPrices,
                    tokens: claimRewardsParams.rewardAssets
                });

                Action memory action = Actions.Action({
                    chainId: chainId,
                    quarkAccount: claimRewards.claimer,
                    actionType: ACTION_TYPE_COMET_CLAIM_REWARDS,
                    actionContext: abi.encode(claimRewardsActionContext),
                    quotePayActionContext: "",
                    paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
                    nonceSecret: accountSecret.nonceSecret,
                    totalPlays: 1,
                    executionType: EXECUTION_TYPE_IMMEDIATE
                });

                List.addQuarkOperation(quarkOperations, quarkOperation);
                List.addAction(actions, action);
            }
        }

        return (List.toQuarkOperationArray(quarkOperations), List.toActionArray(actions));
    }

    struct CometClaimRewardsParams {
        address[] accounts;
        address[] comets;
        address[] rewardAssets;
        address[] rewardContracts;
        uint256[] rewardsOwed;
    }

    function collectClaimRewardsParams(Accounts.CometReward[] memory cometRewards, address comet)
        internal
        pure
        returns (CometClaimRewardsParams memory)
    {
        List.DynamicArray memory cometRewardsList = List.newList();
        List.DynamicArray memory cometsList = List.newList();
        List.DynamicArray memory accountsList = List.newList();
        List.DynamicArray memory rewardsOwedList = List.newList();
        List.DynamicArray memory rewardAssetsList = List.newList();

        for (uint256 i = 0; i < cometRewards.length; ++i) {
            Accounts.CometReward memory cometReward = cometRewards[i];
            for (uint256 j = 0; j < cometReward.accounts.length; ++j) {
                // Only collect params if there are rewards owed for the account
                if (cometReward.rewardsOwed[j] == 0) continue;

                List.addAddress(cometRewardsList, cometReward.rewardContract);
                List.addAddress(cometsList, comet);
                List.addAddress(accountsList, cometReward.accounts[j]);
                List.addUint256(rewardsOwedList, cometReward.rewardsOwed[j]);
                List.addAddress(rewardAssetsList, cometReward.asset);
            }
        }

        return CometClaimRewardsParams({
            rewardContracts: List.toAddressArray(cometRewardsList),
            comets: List.toAddressArray(cometsList),
            accounts: List.toAddressArray(accountsList),
            rewardsOwed: List.toUint256Array(rewardsOwedList),
            rewardAssets: List.toAddressArray(rewardAssetsList)
        });
    }

    function cometRepay(CometRepayInput memory repayInput, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(repayInput.chainId, repayInput.chainAccountsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(repayInput.repayer, accounts.quarkSecrets);

        Accounts.AssetPositions memory repayAssetPositions =
            Accounts.findAssetPositions(repayInput.assetSymbol, accounts.assetPositionsList);

        uint256[] memory collateralTokenPrices = new uint256[](repayInput.collateralAssetSymbols.length);
        address[] memory collateralTokens = new address[](repayInput.collateralAssetSymbols.length);

        for (uint256 i = 0; i < repayInput.collateralAssetSymbols.length; ++i) {
            Accounts.AssetPositions memory assetPositions =
                Accounts.findAssetPositions(repayInput.collateralAssetSymbols[i], accounts.assetPositionsList);
            collateralTokenPrices[i] = assetPositions.usdPrice;
            collateralTokens[i] = assetPositions.asset;
        }

        // XXX handle wrapping ETH?
        bytes memory scriptCalldata = abi.encodeWithSelector(
            CometRepayAndWithdrawMultipleAssets.run.selector,
            repayInput.comet,
            collateralTokens,
            repayInput.collateralAmounts,
            repayAssetPositions.asset,
            repayInput.amount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: repayInput.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        RepayActionContext memory repayActionContext = RepayActionContext({
            amount: repayInput.amount,
            assetSymbol: repayInput.assetSymbol,
            chainId: repayInput.chainId,
            collateralAmounts: repayInput.collateralAmounts,
            collateralAssetSymbols: repayInput.collateralAssetSymbols,
            collateralTokenPrices: collateralTokenPrices,
            collateralTokens: collateralTokens,
            comet: repayInput.comet,
            price: repayAssetPositions.usdPrice,
            token: repayAssetPositions.asset
        });
        Action memory action = Actions.Action({
            chainId: repayInput.chainId,
            quarkAccount: repayInput.repayer,
            actionType: ACTION_TYPE_REPAY,
            actionContext: abi.encode(repayActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function cometSupplyAsset(CometSupply memory cometSupply, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(cometSupply.chainId, cometSupply.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(cometSupply.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(cometSupply.sender, accounts.quarkSecrets);

        bytes memory scriptCalldata;
        if (Strings.stringEqIgnoreCase(cometSupply.assetSymbol, "ETH")) {
            // XXX handle wrapping ETH
        } else {
            scriptCalldata = abi.encodeWithSelector(
                CometSupplyActions.supply.selector, cometSupply.comet, assetPositions.asset, cometSupply.amount
            );
        }
        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(CometSupplyActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: cometSupply.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        CometSupplyActionContext memory cometSupplyActionContext = CometSupplyActionContext({
            amount: cometSupply.amount,
            chainId: cometSupply.chainId,
            comet: cometSupply.comet,
            price: assetPositions.usdPrice,
            token: assetPositions.asset,
            assetSymbol: assetPositions.symbol
        });
        Action memory action = Actions.Action({
            chainId: cometSupply.chainId,
            quarkAccount: cometSupply.sender,
            actionType: ACTION_TYPE_COMET_SUPPLY,
            actionContext: abi.encode(cometSupplyActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function cometWithdrawAsset(CometWithdraw memory cometWithdraw, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(cometWithdraw.chainId, cometWithdraw.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(cometWithdraw.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(cometWithdraw.withdrawer, accounts.quarkSecrets);

        bytes memory scriptCalldata;
        if (Strings.stringEqIgnoreCase(cometWithdraw.assetSymbol, "ETH")) {
            // XXX handle unwrapping ETH
        } else {
            scriptCalldata = abi.encodeWithSelector(
                CometWithdrawActions.withdraw.selector, cometWithdraw.comet, assetPositions.asset, cometWithdraw.amount
            );
        }
        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(CometWithdrawActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: cometWithdraw.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        CometWithdrawActionContext memory cometWithdrawActionContext = CometWithdrawActionContext({
            amount: cometWithdraw.amount,
            assetSymbol: cometWithdraw.assetSymbol,
            chainId: cometWithdraw.chainId,
            comet: cometWithdraw.comet,
            price: assetPositions.usdPrice,
            token: assetPositions.asset
        });
        Action memory action = Actions.Action({
            chainId: cometWithdraw.chainId,
            quarkAccount: cometWithdraw.withdrawer,
            actionType: ACTION_TYPE_COMET_WITHDRAW,
            actionContext: abi.encode(cometWithdrawActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function transferAsset(TransferAsset memory transfer, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(transfer.chainId, transfer.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(transfer.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(transfer.sender, accounts.quarkSecrets);

        bytes memory scriptCalldata;
        if (Strings.stringEqIgnoreCase(transfer.assetSymbol, "ETH")) {
            // Native token transfer
            scriptCalldata = abi.encodeWithSelector(
                TransferActions.transferNativeToken.selector, transfer.recipient, transfer.amount
            );
        } else {
            // ERC20 transfer
            scriptCalldata = abi.encodeWithSelector(
                TransferActions.transferERC20Token.selector, assetPositions.asset, transfer.recipient, transfer.amount
            );
        }
        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(TransferActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: transfer.blockTimestamp + TRANSFER_EXPIRY_BUFFER
        });

        // Construct Action
        TransferActionContext memory transferActionContext = TransferActionContext({
            amount: transfer.amount,
            price: assetPositions.usdPrice,
            token: assetPositions.asset,
            assetSymbol: assetPositions.symbol,
            chainId: transfer.chainId,
            recipient: transfer.recipient
        });

        Action memory action = Actions.Action({
            chainId: transfer.chainId,
            quarkAccount: transfer.sender,
            actionType: ACTION_TYPE_TRANSFER,
            actionContext: abi.encode(transferActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function morphoBorrow(MorphoBorrow memory borrowInput, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(borrowInput.chainId, borrowInput.chainAccountsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(borrowInput.borrower, accounts.quarkSecrets);

        Accounts.AssetPositions memory borrowAssetPositions =
            Accounts.findAssetPositions(borrowInput.assetSymbol, accounts.assetPositionsList);

        Accounts.AssetPositions memory collateralAssetPositions =
            Accounts.findAssetPositions(borrowInput.collateralAssetSymbol, accounts.assetPositionsList);

        bytes memory scriptCalldata = abi.encodeWithSelector(
            MorphoActions.supplyCollateralAndBorrow.selector,
            MorphoInfo.getMorphoAddress(borrowInput.chainId),
            MorphoInfo.getMarketParams(borrowInput.chainId, borrowInput.collateralAssetSymbol, borrowInput.assetSymbol),
            borrowInput.collateralAmount,
            borrowInput.amount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: borrowInput.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        MorphoBorrowActionContext memory borrowActionContext = MorphoBorrowActionContext({
            assetSymbol: borrowInput.assetSymbol,
            amount: borrowInput.amount,
            chainId: borrowInput.chainId,
            collateralAmount: borrowInput.collateralAmount,
            collateralTokenPrice: collateralAssetPositions.usdPrice,
            collateralToken: collateralAssetPositions.asset,
            collateralAssetSymbol: borrowInput.collateralAssetSymbol,
            price: borrowAssetPositions.usdPrice,
            token: borrowAssetPositions.asset,
            morpho: MorphoInfo.getMorphoAddress(borrowInput.chainId),
            morphoMarketId: MorphoInfo.marketId(
                MorphoInfo.getMarketParams(borrowInput.chainId, borrowInput.collateralAssetSymbol, borrowInput.assetSymbol)
            )
        });
        Action memory action = Actions.Action({
            chainId: borrowInput.chainId,
            quarkAccount: borrowInput.borrower,
            actionType: ACTION_TYPE_MORPHO_BORROW,
            actionContext: abi.encode(borrowActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function morphoRepay(MorphoRepay memory repayInput, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(repayInput.chainId, repayInput.chainAccountsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(repayInput.repayer, accounts.quarkSecrets);

        Accounts.AssetPositions memory repayAssetPositions =
            Accounts.findAssetPositions(repayInput.assetSymbol, accounts.assetPositionsList);

        Accounts.AssetPositions memory collateralAssetPositions =
            Accounts.findAssetPositions(repayInput.collateralAssetSymbol, accounts.assetPositionsList);

        bytes memory scriptCalldata = abi.encodeWithSelector(
            MorphoActions.repayAndWithdrawCollateral.selector,
            MorphoInfo.getMorphoAddress(repayInput.chainId),
            MorphoInfo.getMarketParams(repayInput.chainId, repayInput.collateralAssetSymbol, repayInput.assetSymbol),
            repayInput.amount,
            repayInput.collateralAmount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: repayInput.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        MorphoRepayActionContext memory morphoRepayActionContext = MorphoRepayActionContext({
            amount: repayInput.amount,
            assetSymbol: repayInput.assetSymbol,
            chainId: repayInput.chainId,
            collateralAmount: repayInput.collateralAmount,
            collateralAssetSymbol: repayInput.collateralAssetSymbol,
            collateralTokenPrice: collateralAssetPositions.usdPrice,
            collateralToken: collateralAssetPositions.asset,
            price: repayAssetPositions.usdPrice,
            token: repayAssetPositions.asset,
            morpho: MorphoInfo.getMorphoAddress(repayInput.chainId),
            morphoMarketId: MorphoInfo.marketId(
                MorphoInfo.getMarketParams(repayInput.chainId, repayInput.collateralAssetSymbol, repayInput.assetSymbol)
            )
        });

        Action memory action = Actions.Action({
            chainId: repayInput.chainId,
            quarkAccount: repayInput.repayer,
            actionType: ACTION_TYPE_MORPHO_REPAY,
            actionContext: abi.encode(morphoRepayActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function morphoVaultSupply(MorphoVaultSupply memory vaultSupply, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(vaultSupply.chainId, vaultSupply.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(vaultSupply.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(vaultSupply.sender, accounts.quarkSecrets);

        bytes memory scriptCalldata = abi.encodeWithSelector(
            MorphoVaultActions.deposit.selector,
            MorphoInfo.getMorphoVaultAddress(vaultSupply.chainId, vaultSupply.assetSymbol),
            assetPositions.asset,
            vaultSupply.amount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: vaultSupply.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        MorphoVaultSupplyActionContext memory vaultSupplyActionContext = MorphoVaultSupplyActionContext({
            amount: vaultSupply.amount,
            assetSymbol: assetPositions.symbol,
            chainId: vaultSupply.chainId,
            morphoVault: MorphoInfo.getMorphoVaultAddress(vaultSupply.chainId, vaultSupply.assetSymbol),
            price: assetPositions.usdPrice,
            token: assetPositions.asset
        });

        Action memory action = Actions.Action({
            chainId: vaultSupply.chainId,
            quarkAccount: vaultSupply.sender,
            actionType: ACTION_TYPE_MORPHO_VAULT_SUPPLY,
            actionContext: abi.encode(vaultSupplyActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function morphoVaultWithdraw(MorphoVaultWithdraw memory vaultWithdraw, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(vaultWithdraw.chainId, vaultWithdraw.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(vaultWithdraw.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret =
            Accounts.findQuarkSecret(vaultWithdraw.withdrawer, accounts.quarkSecrets);

        bytes memory scriptCalldata = abi.encodeWithSelector(
            MorphoVaultActions.withdraw.selector,
            MorphoInfo.getMorphoVaultAddress(vaultWithdraw.chainId, vaultWithdraw.assetSymbol),
            vaultWithdraw.amount
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(MorphoVaultActions).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: vaultWithdraw.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        MorphoVaultWithdrawActionContext memory vaultWithdrawActionContext = MorphoVaultWithdrawActionContext({
            amount: vaultWithdraw.amount,
            assetSymbol: assetPositions.symbol,
            chainId: vaultWithdraw.chainId,
            morphoVault: MorphoInfo.getMorphoVaultAddress(vaultWithdraw.chainId, vaultWithdraw.assetSymbol),
            price: assetPositions.usdPrice,
            token: assetPositions.asset
        });

        Action memory action = Actions.Action({
            chainId: vaultWithdraw.chainId,
            quarkAccount: vaultWithdraw.withdrawer,
            actionType: ACTION_TYPE_MORPHO_VAULT_WITHDRAW,
            actionContext: abi.encode(vaultWithdrawActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function morphoClaimRewards(MorphoClaimRewards memory claimRewards, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation[] memory, Action[] memory)
    {
        List.DynamicArray memory quarkOperations = List.newList();
        List.DynamicArray memory actions = List.newList();
        // Iterate through each chain and construct a QuarkOperation to claim all rewards for each chain
        for (uint256 i = 0; i < claimRewards.chainAccountsList.length; ++i) {
            uint256 chainId = claimRewards.chainAccountsList[i].chainId;
            Accounts.QuarkSecret memory accountSecret =
                Accounts.findQuarkSecret(claimRewards.claimer, claimRewards.chainAccountsList[i].quarkSecrets);

            // Iterate over each MorphoRewardDistribution for the chain
            Accounts.MorphoRewardDistribution[] memory rewardDistributions =
                claimRewards.chainAccountsList[i].morphoRewardDistributions;
            // Collect parameters for claiming rewards for the current MorphoRewardDistribution
            address[] memory accounts = new address[](rewardDistributions.length);
            uint256[] memory claimables = new uint256[](rewardDistributions.length);
            address[] memory distributors = new address[](rewardDistributions.length);
            address[] memory rewardAssets = new address[](rewardDistributions.length);
            bytes32[][] memory proofs = new bytes32[][](rewardDistributions.length);
            for (uint256 j = 0; j < rewardDistributions.length; ++j) {
                accounts[j] = rewardDistributions[j].account;
                claimables[j] = rewardDistributions[j].claimable;
                distributors[j] = rewardDistributions[j].distributor;
                proofs[j] = rewardDistributions[j].proof;
                rewardAssets[j] = rewardDistributions[j].asset;
            }

            // Skip if no rewards to claim
            if (accounts.length == 0) continue;

            (string[] memory rewardsAssetSymbols, uint256[] memory rewardsPrices) =
                Accounts.getAssetInfo(rewardAssets, claimRewards.chainAccountsList[i].assetPositionsList);

            bytes memory scriptCalldata = abi.encodeWithSelector(
                MorphoRewardsActions.claimAll.selector, distributors, accounts, rewardAssets, claimables, proofs
            );

            // Construct QuarkOperation
            IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
                nonce: accountSecret.nonceSecret,
                isReplayable: false,
                scriptAddress: CodeJarHelper.getCodeAddress(type(MorphoRewardsActions).creationCode),
                scriptCalldata: scriptCalldata,
                scriptSources: new bytes[](0),
                expiry: claimRewards.blockTimestamp + STANDARD_EXPIRY_BUFFER
            });

            MorphoClaimRewardsActionContext memory claimRewardsActionContext = MorphoClaimRewardsActionContext({
                amounts: claimables,
                assetSymbols: rewardsAssetSymbols,
                chainId: chainId,
                prices: rewardsPrices,
                tokens: rewardAssets
            });

            Action memory action = Actions.Action({
                chainId: chainId,
                quarkAccount: claimRewards.claimer,
                actionType: ACTION_TYPE_MORPHO_CLAIM_REWARDS,
                actionContext: abi.encode(claimRewardsActionContext),
                quotePayActionContext: "",
                paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
                nonceSecret: accountSecret.nonceSecret,
                totalPlays: 1,
                executionType: EXECUTION_TYPE_IMMEDIATE
            });

            List.addQuarkOperation(quarkOperations, quarkOperation);
            List.addAction(actions, action);
        }

        return (List.toQuarkOperationArray(quarkOperations), List.toActionArray(actions));
    }

    function quotePay(QuotePayInfo memory quotePayInfo, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(quotePayInfo.chainId, quotePayInfo.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(quotePayInfo.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(quotePayInfo.sender, accounts.quarkSecrets);

        bytes memory scriptCalldata = abi.encodeWithSelector(
            QuotePay.pay.selector, QUOTE_PAY_RECIPIENT, assetPositions.asset, quotePayInfo.amount, payment.quoteId
        );
        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(QuotePay).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: quotePayInfo.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        QuotePayActionContext memory quotePayActionContext = QuotePayActionContext({
            amount: quotePayInfo.amount,
            price: assetPositions.usdPrice,
            token: assetPositions.asset,
            assetSymbol: assetPositions.symbol,
            chainId: quotePayInfo.chainId,
            quoteId: payment.quoteId,
            payee: QUOTE_PAY_RECIPIENT
        });

        Action memory action = Actions.Action({
            chainId: quotePayInfo.chainId,
            quarkAccount: quotePayInfo.sender,
            actionType: ACTION_TYPE_QUOTE_PAY,
            actionContext: abi.encode(quotePayActionContext),
            quotePayActionContext: abi.encode(quotePayActionContext),
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function wrapOrUnwrapAsset(
        WrapOrUnwrapAsset memory wrapOrUnwrap,
        PaymentInfo.Payment memory payment,
        bool isRecurring
    ) internal pure returns (IQuarkWallet.QuarkOperation memory, Action memory) {
        Accounts.ChainAccounts memory accounts =
            Accounts.findChainAccounts(wrapOrUnwrap.chainId, wrapOrUnwrap.chainAccountsList);

        Accounts.AssetPositions memory assetPositions =
            Accounts.findAssetPositions(wrapOrUnwrap.assetSymbol, accounts.assetPositionsList);

        Accounts.QuarkSecret memory accountSecret = Accounts.findQuarkSecret(wrapOrUnwrap.sender, accounts.quarkSecrets);
        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode),
            scriptCalldata: TokenWrapper.encodeActionToWrapOrUnwrap(
                wrapOrUnwrap.chainId, wrapOrUnwrap.assetSymbol, wrapOrUnwrap.amountNeeded
            ),
            scriptSources: new bytes[](0),
            expiry: wrapOrUnwrap.blockTimestamp + STANDARD_EXPIRY_BUFFER
        });

        // Construct Action
        WrapOrUnwrapActionContext memory wrapOrUnwrapActionContext = WrapOrUnwrapActionContext({
            chainId: wrapOrUnwrap.chainId,
            amount: TokenWrapper.calculateAmountToWrapOrUnwrap({
                chainId: wrapOrUnwrap.chainId,
                fromTokenSymbol: assetPositions.symbol,
                amountNeeded: wrapOrUnwrap.amountNeeded,
                chainAccountsList: wrapOrUnwrap.chainAccountsList
            }),
            token: assetPositions.asset,
            fromAssetSymbol: assetPositions.symbol,
            toAssetSymbol: TokenWrapper.getWrapperCounterpartSymbol(wrapOrUnwrap.chainId, assetPositions.symbol)
        });

        Action memory action = Actions.Action({
            chainId: wrapOrUnwrap.chainId,
            quarkAccount: wrapOrUnwrap.sender,
            actionType: TokenWrapper.isWrappedToken(wrapOrUnwrap.chainId, assetPositions.symbol)
                ? ACTION_TYPE_UNWRAP
                : ACTION_TYPE_WRAP,
            actionContext: abi.encode(wrapOrUnwrapActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: isRecurring}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function zeroExSwap(ZeroExSwap memory swap, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        Accounts.QuarkSecret memory accountSecret;
        SwapActionContext memory swapActionContext;
        // Local scope to avoid stack too deep
        {
            Accounts.ChainAccounts memory accounts = Accounts.findChainAccounts(swap.chainId, swap.chainAccountsList);

            Accounts.AssetPositions memory sellTokenAssetPositions =
                Accounts.findAssetPositions(swap.sellAssetSymbol, accounts.assetPositionsList);

            Accounts.AssetPositions memory buyTokenAssetPositions =
                Accounts.findAssetPositions(swap.buyAssetSymbol, accounts.assetPositionsList);

            Accounts.AssetPositions memory feeTokenAssetPositions =
                Accounts.findAssetPositions(swap.feeAssetSymbol, accounts.assetPositionsList);

            accountSecret = Accounts.findQuarkSecret(swap.sender, accounts.quarkSecrets);

            // Construct Action
            swapActionContext = SwapActionContext({
                chainId: swap.chainId,
                feeAmount: swap.feeAmount,
                feeAssetSymbol: swap.feeAssetSymbol,
                feeToken: swap.feeToken,
                feeTokenPrice: feeTokenAssetPositions.usdPrice,
                inputAmount: swap.sellAmount,
                inputAssetSymbol: swap.sellAssetSymbol,
                inputToken: swap.sellToken,
                inputTokenPrice: sellTokenAssetPositions.usdPrice,
                outputAmount: swap.buyAmount,
                outputAssetSymbol: swap.buyAssetSymbol,
                outputToken: swap.buyToken,
                outputTokenPrice: buyTokenAssetPositions.usdPrice,
                isExactOut: swap.isExactOut
            });
        }

        // TODO: Handle wrapping ETH? Do we need to?
        bytes memory scriptCalldata = abi.encodeWithSelector(
            ApproveAndSwap.run.selector,
            swap.entryPoint,
            swap.sellToken,
            swap.sellAmount,
            swap.buyToken,
            swap.buyAmount,
            swap.swapData
        );

        // Construct QuarkOperation
        IQuarkWallet.QuarkOperation memory quarkOperation = IQuarkWallet.QuarkOperation({
            nonce: accountSecret.nonceSecret,
            isReplayable: false,
            scriptAddress: CodeJarHelper.getCodeAddress(type(ApproveAndSwap).creationCode),
            scriptCalldata: scriptCalldata,
            scriptSources: new bytes[](0),
            expiry: swap.blockTimestamp + SWAP_EXPIRY_BUFFER
        });

        Action memory action = Actions.Action({
            chainId: swap.chainId,
            quarkAccount: swap.sender,
            actionType: ACTION_TYPE_SWAP,
            actionContext: abi.encode(swapActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: false}),
            nonceSecret: accountSecret.nonceSecret,
            totalPlays: 1,
            executionType: EXECUTION_TYPE_IMMEDIATE
        });

        return (quarkOperation, action);
    }

    function recurringSwap(RecurringSwapParams memory swap, PaymentInfo.Payment memory payment)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Action memory)
    {
        RecurringSwapLocalVars memory localVars;
        // Local scope to avoid stack too deep
        {
            Accounts.ChainAccounts memory accounts = Accounts.findChainAccounts(swap.chainId, swap.chainAccountsList);
            localVars = RecurringSwapLocalVars({
                accounts: accounts,
                accountSecret: Accounts.findQuarkSecret(swap.sender, accounts.quarkSecrets),
                sellTokenAssetPositions: Accounts.findAssetPositions(swap.sellAssetSymbol, accounts.assetPositionsList),
                buyTokenAssetPositions: Accounts.findAssetPositions(swap.buyAssetSymbol, accounts.assetPositionsList)
            });
        }

        RecurringSwap.SwapConfig memory swapConfig;
        // Local scope to avoid stack too deep
        {
            RecurringSwap.SwapWindow memory swapWindow = RecurringSwap.SwapWindow({
                startTime: swap.blockTimestamp - AVERAGE_BLOCK_TIME,
                interval: swap.interval,
                length: RECURRING_SWAP_WINDOW_LENGTH
            });
            RecurringSwap.SwapParams memory swapParams = RecurringSwap.SwapParams({
                uniswapRouter: UniswapRouter.knownRouter(swap.chainId),
                recipient: swap.sender,
                tokenIn: swap.sellToken,
                tokenOut: swap.buyToken,
                amount: swap.isExactOut ? swap.buyAmount : swap.sellAmount,
                isExactOut: swap.isExactOut,
                path: swap.path
            });
            (address[] memory priceFeeds, bool[] memory shouldInvert) = PriceFeeds.findPriceFeedPath({
                inputAssetSymbol: PriceFeeds.convertToPriceFeedSymbol(swap.sellAssetSymbol),
                outputAssetSymbol: PriceFeeds.convertToPriceFeedSymbol(swap.buyAssetSymbol),
                chainId: swap.chainId
            });
            RecurringSwap.SlippageParams memory slippageParams = RecurringSwap.SlippageParams({
                maxSlippage: RECURRING_SWAP_MAX_SLIPPAGE,
                priceFeeds: priceFeeds,
                shouldInvert: shouldInvert
            });
            swapConfig = RecurringSwap.SwapConfig({
                swapWindow: swapWindow,
                swapParams: swapParams,
                slippageParams: slippageParams
            });
        }

        IQuarkWallet.QuarkOperation memory quarkOperation;
        // Local scope to avoid stack too deep
        {
            // TODO: Handle wrapping ETH? Do we need to?
            bytes memory scriptCalldata = abi.encodeWithSelector(RecurringSwap.swap.selector, swapConfig);

            bytes32 nonce = generateNonceFromSecret(localVars.accountSecret.nonceSecret, RECURRING_SWAP_TOTAL_PLAYS);
            // Construct QuarkOperation
            quarkOperation = IQuarkWallet.QuarkOperation({
                nonce: nonce,
                isReplayable: true,
                scriptAddress: CodeJarHelper.getCodeAddress(type(RecurringSwap).creationCode),
                scriptCalldata: scriptCalldata,
                scriptSources: new bytes[](0),
                expiry: type(uint256).max
            });
        }

        // Construct Action
        RecurringSwapActionContext memory recurringSwapActionContext = RecurringSwapActionContext({
            chainId: swap.chainId,
            inputAmount: swap.sellAmount,
            inputAssetSymbol: swap.sellAssetSymbol,
            inputToken: swap.sellToken,
            inputTokenPrice: localVars.sellTokenAssetPositions.usdPrice,
            outputAmount: swap.buyAmount,
            outputAssetSymbol: swap.buyAssetSymbol,
            outputToken: swap.buyToken,
            outputTokenPrice: localVars.buyTokenAssetPositions.usdPrice,
            isExactOut: swap.isExactOut,
            interval: swap.interval
        });

        Action memory action = Actions.Action({
            chainId: swap.chainId,
            quarkAccount: swap.sender,
            actionType: ACTION_TYPE_RECURRING_SWAP,
            actionContext: abi.encode(recurringSwapActionContext),
            quotePayActionContext: "",
            paymentMethod: PaymentInfo.paymentMethodForPayment({payment: payment, isRecurring: true}),
            nonceSecret: localVars.accountSecret.nonceSecret,
            totalPlays: RECURRING_SWAP_TOTAL_PLAYS,
            executionType: EXECUTION_TYPE_RECURRENT
        });

        return (quarkOperation, action);
    }

    function isRecurringAction(string memory actionType) internal pure returns (bool) {
        return Strings.stringEqIgnoreCase(actionType, ACTION_TYPE_RECURRING_SWAP);
    }

    function findActionsOfType(Action[] memory actions, string memory actionType)
        internal
        pure
        returns (Action[] memory)
    {
        uint256 count = 0;
        Action[] memory result = new Action[](actions.length);
        for (uint256 i = 0; i < actions.length; ++i) {
            if (Strings.stringEqIgnoreCase(actions[i].actionType, actionType)) {
                result[count++] = actions[i];
            }
        }

        return truncate(result, count);
    }

    function findActionsNotOfType(Actions.Action[] memory actions, string memory actionType)
        internal
        pure
        returns (Actions.Action[] memory)
    {
        uint256 count = 0;
        Actions.Action[] memory result = new Actions.Action[](actions.length);
        for (uint256 i = 0; i < actions.length; ++i) {
            if (!Strings.stringEqIgnoreCase(actions[i].actionType, actionType)) {
                result[count++] = actions[i];
            }
        }

        return truncate(result, count);
    }

    function truncate(Action[] memory actions, uint256 length) internal pure returns (Action[] memory) {
        Action[] memory result = new Action[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = actions[i];
        }
        return result;
    }

    function truncate(IQuarkWallet.QuarkOperation[] memory operations, uint256 length)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation[] memory)
    {
        IQuarkWallet.QuarkOperation[] memory result = new IQuarkWallet.QuarkOperation[](length);
        for (uint256 i = 0; i < length; ++i) {
            result[i] = operations[i];
        }
        return result;
    }

    function generateNonceFromSecret(bytes32 secret, uint256 totalPlays) internal pure returns (bytes32) {
        uint256 replayCount = totalPlays - 1;
        assembly ("memory-safe") {
            let ptr := mload(0x40) // Get free memory pointer
            mstore(ptr, secret) // Store initial secret at ptr

            for { let i := 0 } lt(i, replayCount) { i := add(i, 1) } { mstore(ptr, keccak256(ptr, 32)) }

            secret := mload(ptr) // Load final result
        }
        return secret;
    }

    // These structs are mostly used internally and returned in serialized format as bytes: actionContext
    // The caller can then decode them back into their struct form.
    // These empty husk functions exist so that the structs make it into the abi so the clients can know how to decode them.
    function emptyBorrowActionContext() external pure returns (BorrowActionContext memory) {
        BorrowActionContext[] memory bs = new BorrowActionContext[](1);
        return bs[0];
    }

    function emptyMorphoBorrowActionContext() external pure returns (MorphoBorrowActionContext memory) {
        MorphoBorrowActionContext[] memory mb = new MorphoBorrowActionContext[](1);
        return mb[0];
    }

    function emptyBridgeActionContext() external pure returns (BridgeActionContext memory) {
        BridgeActionContext[] memory bs = new BridgeActionContext[](1);
        return bs[0];
    }

    function emptyCometClaimRewardsActionContext() external pure returns (CometClaimRewardsActionContext memory) {
        CometClaimRewardsActionContext[] memory cs = new CometClaimRewardsActionContext[](1);
        return cs[0];
    }

    function emptyDripTokensActionContext() external pure returns (DripTokensActionContext memory) {
        DripTokensActionContext[] memory ds = new DripTokensActionContext[](1);
        return ds[0];
    }

    function emptyRecurringSwapActionContext() external pure returns (RecurringSwapActionContext memory) {
        RecurringSwapActionContext[] memory rs = new RecurringSwapActionContext[](1);
        return rs[0];
    }

    function emptyRepayActionContext() external pure returns (RepayActionContext memory) {
        RepayActionContext[] memory rs = new RepayActionContext[](1);
        return rs[0];
    }

    function emptyMorphoRepayActionContext() external pure returns (MorphoRepayActionContext memory) {
        MorphoRepayActionContext[] memory mr = new MorphoRepayActionContext[](1);
        return mr[0];
    }

    function emptyCometSupplyActionContext() external pure returns (CometSupplyActionContext memory) {
        CometSupplyActionContext[] memory ss = new CometSupplyActionContext[](1);
        return ss[0];
    }

    function emptySwapActionContext() external pure returns (SwapActionContext memory) {
        SwapActionContext[] memory ss = new SwapActionContext[](1);
        return ss[0];
    }

    function emptyTransferActionContext() external pure returns (TransferActionContext memory) {
        TransferActionContext[] memory ts = new TransferActionContext[](1);
        return ts[0];
    }

    function emptyCometWithdrawActionContext() external pure returns (CometWithdrawActionContext memory) {
        CometWithdrawActionContext[] memory ws = new CometWithdrawActionContext[](1);
        return ws[0];
    }

    function emptyWithdrawAndBorrowActionContext() external pure returns (WithdrawAndBorrowActionContext memory) {
        WithdrawAndBorrowActionContext[] memory ws = new WithdrawAndBorrowActionContext[](1);
        return ws[0];
    }

    function emptyMorphoVaultSupplyActionContext() external pure returns (MorphoVaultSupplyActionContext memory) {
        MorphoVaultSupplyActionContext[] memory ms = new MorphoVaultSupplyActionContext[](1);
        return ms[0];
    }

    function emptyMorphoVaultWithdrawActionContext() external pure returns (MorphoVaultWithdrawActionContext memory) {
        MorphoVaultWithdrawActionContext[] memory mw = new MorphoVaultWithdrawActionContext[](1);
        return mw[0];
    }

    function emptyQuotePayActionContext() external pure returns (QuotePayActionContext memory) {
        QuotePayActionContext[] memory qp = new QuotePayActionContext[](1);
        return qp[0];
    }
}
