// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {Accounts} from "src/builder/Accounts.sol";
import {BridgeRoutes} from "src/builder/BridgeRoutes.sol";
import {EIP712Helper} from "src/builder/EIP712Helper.sol";
import {Math} from "src/lib/Math.sol";
import {Strings} from "src/builder/Strings.sol";
import {PaycallWrapper} from "src/builder/PaycallWrapper.sol";
import {QuotecallWrapper} from "src/builder/QuotecallWrapper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {QuarkOperationHelper} from "src/builder/QuarkOperationHelper.sol";
import {Quotes} from "src/builder/Quotes.sol";
import {List} from "src/builder/List.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";

contract AaveActionsBuilder is QuarkBuilderBase {
    struct AaveRepayIntent {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        address pool;
        address repayer;
        bool preferAcross;
        string paymentAssetSymbol;
    }

    function aaveRepay(
        AaveRepayIntent memory repayIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */) {
        if (
            repayIntent.collateralAmounts.length !=
            repayIntent.collateralAssetSymbols.length
        ) {
            revert InvalidInput();
        }

        PaymentInfo.Payment memory payment = Quotes
            .getPaymentFromQuotesAndSymbol(
                chainAccountsList,
                quote,
                repayIntent.paymentAssetSymbol
            );

        // XXX confirm that the user is not withdrawing beyond their limits

        bool isMaxRepay = repayIntent.amount == type(uint256).max;

        uint256 repayAmount;
        if (isMaxRepay) {
            repayAmount = aaveRepayMaxAmount(
                chainAccountsList,
                repayIntent.chainId,
                repayIntent.pool,
                repayIntent.repayer
            );
        } else {
            repayAmount = repayIntent.amount;
        }

        (
            IQuarkWallet.QuarkOperation memory repayQuarkOperation,
            Actions.Action memory repayAction
        ) = Actions.aaveRepay(
                Actions.aaveRepayInput({
                    chainAccountsList: chainAccountsList,
                    assetSymbol: repayIntent.assetSymbol,
                    amount: repayIntent.amount,
                    chainId: repayIntent.chainId,
                    collateralAmounts: repayIntent.collateralAmounts,
                    collateralAssetSymbols: repayIntent.collateralAssetSymbols,
                    pool: repayIntent.pool,
                    blockTimestamp: repayIntent.blockTimestamp,
                    repayer: repayIntent.repayer
                }),
                payment
            );

        QuarkBuilderBase.ActionIntent memory actionIntent;
        // Note: Scope to avoid stack too deep errors
        {
            uint256[] memory amountOuts = new uint256[](1);
            amountOuts[0] = repayAmount;
            string[] memory assetSymbolOuts = new string[](1);
            assetSymbolOuts[0] = repayIntent.assetSymbol;
            actionIntent = QuarkBuilderBase.ActionIntent({
                actor: repayIntent.repayer,
                amountOuts: amountOuts,
                assetSymbolOuts: assetSymbolOuts,
                amountIns: repayIntent.collateralAmounts,
                assetSymbolIns: repayIntent.collateralAssetSymbols,
                blockTimestamp: repayIntent.blockTimestamp,
                chainId: repayIntent.chainId,
                preferAcross: repayIntent.preferAcross
            });
        }

        (
            IQuarkWallet.QuarkOperation[] memory quarkOperationsArray,
            Actions.Action[] memory actionsArray
        ) = QuarkBuilderBase.collectAssetsForAction({
                actionIntent: actionIntent,
                chainAccountsList: chainAccountsList,
                payment: payment,
                actionQuarkOperation: repayQuarkOperation,
                action: repayAction
            });

        return
            BuilderResult({
                version: VERSION,
                actions: actionsArray,
                quarkOperations: quarkOperationsArray,
                paymentCurrency: payment.currency,
                eip712Data: EIP712Helper.eip712DataForQuarkOperations(
                    quarkOperationsArray,
                    actionsArray
                )
            });
    }

    struct AaveBorrowIntent {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        address borrower;
        uint256 chainId;
        uint256[] collateralAmounts;
        string[] collateralAssetSymbols;
        address pool;
        bool preferAcross;
        string paymentAssetSymbol;
    }

    function aaveBorrow(
        AaveBorrowIntent memory borrowIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */) {
        PaymentInfo.Payment memory payment = Quotes
            .getPaymentFromQuotesAndSymbol(
                chainAccountsList,
                quote,
                borrowIntent.paymentAssetSymbol
            );

        if (
            borrowIntent.collateralAmounts.length !=
            borrowIntent.collateralAssetSymbols.length
        ) {
            revert InvalidInput();
        }

        (
            IQuarkWallet.QuarkOperation memory borrowQuarkOperation,
            Actions.Action memory borrowAction
        ) = Actions.aaveBorrow(
                Actions.AaveBorrowInput({
                    chainAccountsList: chainAccountsList,
                    amount: borrowIntent.amount,
                    assetSymbol: borrowIntent.assetSymbol,
                    blockTimestamp: borrowIntent.blockTimestamp,
                    borrower: borrowIntent.borrower,
                    chainId: borrowIntent.chainId,
                    collateralAmounts: borrowIntent.collateralAmounts,
                    collateralAssetSymbols: borrowIntent.collateralAssetSymbols,
                    pool: borrowIntent.pool
                }),
                payment
            );

        QuarkBuilderBase.ActionIntent memory actionIntent;
        // Note: Scope to avoid stack too deep errors
        {
            uint256[] memory amountIns = new uint256[](1);
            amountIns[0] = borrowIntent.amount;
            string[] memory assetSymbolIns = new string[](1);
            assetSymbolIns[0] = borrowIntent.assetSymbol;
            actionIntent = QuarkBuilderBase.ActionIntent({
                actor: borrowIntent.borrower,
                amountIns: amountIns,
                assetSymbolIns: assetSymbolIns,
                amountOuts: borrowIntent.collateralAmounts,
                assetSymbolOuts: borrowIntent.collateralAssetSymbols,
                blockTimestamp: borrowIntent.blockTimestamp,
                chainId: borrowIntent.chainId,
                preferAcross: borrowIntent.preferAcross
            });
        }

        (
            IQuarkWallet.QuarkOperation[] memory quarkOperationsArray,
            Actions.Action[] memory actionsArray
        ) = QuarkBuilderBase.collectAssetsForAction({
                actionIntent: actionIntent,
                chainAccountsList: chainAccountsList,
                payment: payment,
                actionQuarkOperation: borrowQuarkOperation,
                action: borrowAction
            });

        return
            BuilderResult({
                version: VERSION,
                actions: actionsArray,
                quarkOperations: quarkOperationsArray,
                paymentCurrency: payment.currency,
                eip712Data: EIP712Helper.eip712DataForQuarkOperations(
                    quarkOperationsArray,
                    actionsArray
                )
            });
    }

    struct AaveSupplyIntent {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        uint256 chainId;
        address pool;
        address sender;
        bool preferAcross;
        string paymentAssetSymbol;
    }

    function cometSupply(
        CometSupplyIntent memory cometSupplyIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory /* builderResult */) {
        PaymentInfo.Payment memory payment = Quotes
            .getPaymentFromQuotesAndSymbol(
                chainAccountsList,
                quote,
                cometSupplyIntent.paymentAssetSymbol
            );

        // Initialize comet supply max flag
        bool isMaxSupply = cometSupplyIntent.amount == type(uint256).max;
        // Convert cometSupplyIntent to user aggregated balance
        if (isMaxSupply) {
            cometSupplyIntent.amount = Accounts.totalAvailableAsset(
                cometSupplyIntent.assetSymbol,
                chainAccountsList,
                payment
            );
        }

        (
            IQuarkWallet.QuarkOperation memory supplyQuarkOperation,
            Actions.Action memory supplyAction
        ) = Actions.cometSupplyAsset(
                Actions.CometSupply({
                    chainAccountsList: chainAccountsList,
                    assetSymbol: cometSupplyIntent.assetSymbol,
                    amount: cometSupplyIntent.amount,
                    chainId: cometSupplyIntent.chainId,
                    comet: cometSupplyIntent.comet,
                    sender: cometSupplyIntent.sender,
                    blockTimestamp: cometSupplyIntent.blockTimestamp
                }),
                payment
            );

        IQuarkWallet.QuarkOperation[] memory quarkOperationsArray;
        Actions.Action[] memory actionsArray;
        // Note: Scope to avoid stack too deep errors
        {
            uint256[] memory amountOuts = new uint256[](1);
            amountOuts[0] = cometSupplyIntent.amount;
            string[] memory assetSymbolOuts = new string[](1);
            assetSymbolOuts[0] = cometSupplyIntent.assetSymbol;
            uint256[] memory amountIns = new uint256[](0);
            string[] memory assetSymbolIns = new string[](0);

            (quarkOperationsArray, actionsArray) = QuarkBuilderBase
                .collectAssetsForAction({
                    actionIntent: QuarkBuilderBase.ActionIntent({
                        actor: cometSupplyIntent.sender,
                        amountIns: amountIns,
                        assetSymbolIns: assetSymbolIns,
                        amountOuts: amountOuts,
                        assetSymbolOuts: assetSymbolOuts,
                        blockTimestamp: cometSupplyIntent.blockTimestamp,
                        chainId: cometSupplyIntent.chainId,
                        preferAcross: cometSupplyIntent.preferAcross
                    }),
                    chainAccountsList: chainAccountsList,
                    payment: payment,
                    actionQuarkOperation: supplyQuarkOperation,
                    action: supplyAction
                });
        }

        return
            BuilderResult({
                version: VERSION,
                actions: actionsArray,
                quarkOperations: quarkOperationsArray,
                paymentCurrency: payment.currency,
                eip712Data: EIP712Helper.eip712DataForQuarkOperations(
                    quarkOperationsArray,
                    actionsArray
                )
            });
    }

    struct CometWithdrawIntent {
        uint256 amount;
        string assetSymbol;
        uint256 blockTimestamp;
        uint256 chainId;
        address comet;
        address withdrawer;
        bool preferAcross;
        string paymentAssetSymbol;
    }

    function cometWithdraw(
        CometWithdrawIntent memory cometWithdrawIntent,
        Accounts.ChainAccounts[] memory chainAccountsList,
        Quotes.Quote memory quote
    ) external pure returns (BuilderResult memory) {
        // XXX confirm that you actually have the amount to withdraw
        bool isMaxWithdraw = cometWithdrawIntent.amount == type(uint256).max;

        PaymentInfo.Payment memory payment = Quotes
            .getPaymentFromQuotesAndSymbol(
                chainAccountsList,
                quote,
                cometWithdrawIntent.paymentAssetSymbol
            );

        uint256 actualWithdrawAmount = cometWithdrawIntent.amount;
        if (isMaxWithdraw) {
            // When doing a max withdraw, we need to find the actual approximate amount instead of using uint256 max
            actualWithdrawAmount = cometWithdrawMaxAmount(
                chainAccountsList,
                cometWithdrawIntent.chainId,
                cometWithdrawIntent.comet,
                cometWithdrawIntent.withdrawer
            );
        }

        (
            IQuarkWallet.QuarkOperation memory cometWithdrawQuarkOperation,
            Actions.Action memory cometWithdrawAction
        ) = Actions.cometWithdrawAsset(
                Actions.CometWithdraw({
                    chainAccountsList: chainAccountsList,
                    assetSymbol: cometWithdrawIntent.assetSymbol,
                    amount: cometWithdrawIntent.amount,
                    chainId: cometWithdrawIntent.chainId,
                    comet: cometWithdrawIntent.comet,
                    withdrawer: cometWithdrawIntent.withdrawer,
                    blockTimestamp: cometWithdrawIntent.blockTimestamp
                }),
                payment
            );
        IQuarkWallet.QuarkOperation[] memory quarkOperationsArray;
        Actions.Action[] memory actionsArray;
        // Note: Scope to avoid stack too deep errors
        {
            uint256[] memory amountIns = new uint256[](1);
            amountIns[0] = actualWithdrawAmount;
            string[] memory assetSymbolIns = new string[](1);
            assetSymbolIns[0] = cometWithdrawIntent.assetSymbol;
            uint256[] memory amountOuts = new uint256[](0);
            string[] memory assetSymbolOuts = new string[](0);

            (quarkOperationsArray, actionsArray) = QuarkBuilderBase
                .collectAssetsForAction({
                    actionIntent: QuarkBuilderBase.ActionIntent({
                        actor: cometWithdrawIntent.withdrawer,
                        amountIns: amountIns,
                        assetSymbolIns: assetSymbolIns,
                        amountOuts: amountOuts,
                        assetSymbolOuts: assetSymbolOuts,
                        blockTimestamp: cometWithdrawIntent.blockTimestamp,
                        chainId: cometWithdrawIntent.chainId,
                        preferAcross: cometWithdrawIntent.preferAcross
                    }),
                    chainAccountsList: chainAccountsList,
                    payment: payment,
                    actionQuarkOperation: cometWithdrawQuarkOperation,
                    action: cometWithdrawAction
                });
        }

        return
            BuilderResult({
                version: VERSION,
                actions: actionsArray,
                quarkOperations: quarkOperationsArray,
                paymentCurrency: payment.currency,
                eip712Data: EIP712Helper.eip712DataForQuarkOperations(
                    quarkOperationsArray,
                    actionsArray
                )
            });
    }
}
