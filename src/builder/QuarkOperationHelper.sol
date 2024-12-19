// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {console} from "src/builder/console.sol";

import {IQuarkWallet} from "quark-core/src/interfaces/IQuarkWallet.sol";

import {Multicall} from "src/Multicall.sol";

import {Actions} from "src/builder/actions/Actions.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {Errors} from "src/builder/Errors.sol";
import {PaycallWrapper} from "src/builder/PaycallWrapper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {QuotecallWrapper} from "src/builder/QuotecallWrapper.sol";
import {List} from "src/builder/List.sol";
import {HashMap} from "src/builder/HashMap.sol";
import {Strings} from "src/builder/Strings.sol";

// Helper library to for transforming Quark Operations
library QuarkOperationHelper {
    /* ===== Main Implementation ===== */

    function mergeSameChainOperations(
        IQuarkWallet.QuarkOperation[] memory quarkOperations,
        Actions.Action[] memory actions
    ) internal pure returns (IQuarkWallet.QuarkOperation[] memory, Actions.Action[] memory) {
        if (quarkOperations.length != actions.length) revert Errors.BadData();

        // Group operations and actions by chain id
        HashMap.Map memory groupedQuarkOperations = HashMap.newMap();
        HashMap.Map memory groupedActions = HashMap.newMap();

        // Group operations by chain
        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            uint256 chainId = actions[i].chainId;
            if (!HashMap.contains(groupedQuarkOperations, chainId)) {
                HashMap.putDynamicArray(groupedQuarkOperations, chainId, List.newList());
            }
            if (!HashMap.contains(groupedActions, chainId)) {
                HashMap.putDynamicArray(groupedActions, chainId, List.newList());
            }

            HashMap.putDynamicArray(
                groupedQuarkOperations,
                chainId,
                List.addQuarkOperation(HashMap.getDynamicArray(groupedQuarkOperations, chainId), quarkOperations[i])
            );
            HashMap.putDynamicArray(
                groupedActions, chainId, List.addAction(HashMap.getDynamicArray(groupedActions, chainId), actions[i])
            );
        }

        // Create new arrays for merged operations and actions
        uint256[] memory chainIds = HashMap.keysUint256(groupedQuarkOperations);
        uint256 uniqueChainCount = chainIds.length;
        IQuarkWallet.QuarkOperation[] memory mergedQuarkOperations = new IQuarkWallet.QuarkOperation[](uniqueChainCount);
        Actions.Action[] memory mergedActions = new Actions.Action[](uniqueChainCount);

        // Merge operations for each unique chain
        for (uint256 i = 0; i < uniqueChainCount; ++i) {
            List.DynamicArray memory groupedQuarkOperationsList =
                HashMap.getDynamicArray(groupedQuarkOperations, chainIds[i]);
            List.DynamicArray memory groupedActionsList = HashMap.getDynamicArray(groupedActions, chainIds[i]);
            if (groupedQuarkOperationsList.length == 1) {
                // If there's only one operation for this chain, we don't need to merge
                mergedQuarkOperations[i] = List.getQuarkOperation(groupedQuarkOperationsList, 0);
                mergedActions[i] = List.getAction(groupedActionsList, 0);
            } else {
                // Merge multiple operations for this chain
                (mergedQuarkOperations[i], mergedActions[i]) = mergeOperations(
                    List.toQuarkOperationArray(groupedQuarkOperationsList), List.toActionArray(groupedActionsList)
                );
            }
        }

        return (mergedQuarkOperations, mergedActions);
    }

    // Note: Assumes all the quark operations are for the same quark wallet.
    function mergeOperations(IQuarkWallet.QuarkOperation[] memory quarkOperations, Actions.Action[] memory actions)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Actions.Action memory)
    {
        address[] memory callContracts = new address[](quarkOperations.length);
        bytes[] memory callDatas = new bytes[](quarkOperations.length);
        // We add an extra space for the Multicall script source
        bytes[] memory scriptSources = new bytes[](quarkOperations.length + 1);

        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            callContracts[i] = quarkOperations[i].scriptAddress;
            callDatas[i] = quarkOperations[i].scriptCalldata;
            // Note: For simplicity, we assume there is one script source per quark operation for now
            scriptSources[i] = quarkOperations[i].scriptSources[0];
        }
        scriptSources[quarkOperations.length] = type(Multicall).creationCode;

        bytes memory multicallCalldata = abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas);

        // Construct Quark Operation and Action
        // Note: We give precedence to the last operation and action for now because any earlier operations
        // are auxiliary (e.g. wrapping an asset). However, if the last action is a quote pay, we'll take the
        // second to last action instead when the list of actions has more than one action in it.
        IQuarkWallet.QuarkOperation memory primaryQuarkOperation;
        Actions.Action memory primaryAction;
        if (
            actions.length > 1
                && Strings.stringEq(actions[actions.length - 1].actionType, Actions.ACTION_TYPE_QUOTE_PAY)
        ) {
            primaryQuarkOperation = quarkOperations[quarkOperations.length - 2];
            primaryAction = actions[actions.length - 2];
        } else {
            primaryQuarkOperation = quarkOperations[quarkOperations.length - 1];
            primaryAction = actions[actions.length - 1];
        }
        // Find and attach a QuotePay action context if one is found
        for (uint256 i = 0; i < actions.length; ++i) {
            if (Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_QUOTE_PAY)) {
                primaryAction.quotePayActionContext = actions[i].actionContext;
                break;
            }
        }
        IQuarkWallet.QuarkOperation memory mergedQuarkOperation = IQuarkWallet.QuarkOperation({
            nonce: primaryQuarkOperation.nonce,
            isReplayable: primaryQuarkOperation.isReplayable,
            scriptAddress: CodeJarHelper.getCodeAddress(type(Multicall).creationCode),
            scriptCalldata: multicallCalldata,
            scriptSources: scriptSources,
            expiry: primaryQuarkOperation.expiry
        });

        return (mergedQuarkOperation, primaryAction);
    }

    function wrapOperationsWithTokenPayment(
        IQuarkWallet.QuarkOperation[] memory quarkOperations,
        Actions.Action[] memory actions,
        PaymentInfo.Payment memory payment
    ) internal pure returns (IQuarkWallet.QuarkOperation[] memory) {
        IQuarkWallet.QuarkOperation[] memory wrappedQuarkOperations =
            new IQuarkWallet.QuarkOperation[](quarkOperations.length);
        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            wrappedQuarkOperations[i] = PaycallWrapper.wrap(
                quarkOperations[i],
                actions[i].chainId,
                payment.currency,
                PaymentInfo.findCostForChain(payment, actions[i].chainId)
            );
        }
        return wrappedQuarkOperations;
    }
}
