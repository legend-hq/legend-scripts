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

        // First see if there are any bridge operations since that will affect the `Action.executionType` later on
        bool hasBridgeOperation = containsBridgeOperation(actions);

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

            // Update the execution type based on the presence of bridge operations in the mix
            mergedActions[i].executionType =
                getExecutionType(List.toActionArray(groupedActionsList), hasBridgeOperation);
        }

        return (mergedQuarkOperations, mergedActions);
    }

    // Note: Assumes all the quark operations are for the same quark wallet.
    function mergeOperations(IQuarkWallet.QuarkOperation[] memory quarkOperations, Actions.Action[] memory actions)
        internal
        pure
        returns (IQuarkWallet.QuarkOperation memory, Actions.Action memory)
    {
        (address[] memory callContracts, bytes[] memory callDatas) = getOrderedCalls(quarkOperations, actions);

        bytes memory multicallCalldata = abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas);

        // Construct Quark Operation and Action
        IQuarkWallet.QuarkOperation memory primaryQuarkOperation = quarkOperations[quarkOperations.length - 1];
        Actions.Action memory primaryAction = actions[actions.length - 1];
        if (actions.length > 1) {
            string[] memory actionTypes = new string[](actions.length);
            bytes[] memory actionContexts = new bytes[](actions.length);
            for (uint256 i = 0; i < actions.length; ++i) {
                actionTypes[i] = actions[i].actionType;
                actionContexts[i] = actions[i].actionContext;
            }
            primaryAction.actionType = Actions.ACTION_TYPE_MULTI_ACTION;
            primaryAction.actionContext =
                abi.encode(Actions.MultiActionContext({actionTypes: actionTypes, actionContexts: actionContexts}));
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
            // We don't provide `scriptSources` to save on calldata
            scriptSources: new bytes[](0),
            expiry: primaryQuarkOperation.expiry
        });

        return (mergedQuarkOperation, primaryAction);
    }

    // Extracts the list of call contracts and calldatas from the QuarkOperations, while also re-ordering them if needed
    // Note: The re-ordering rules are as follows:
    //         - If a max supply is found and a QuotePay is found, insert the QuotePay call before the max supply to ensure tokens aren't
    //           all sent out before the QuotePay is executed
    //         - Otherwise, keep the QuotePay last to ensure it can be paid from funds entering the account (e.g. withdraw, swap)
    function getOrderedCalls(IQuarkWallet.QuarkOperation[] memory quarkOperations, Actions.Action[] memory actions)
        internal
        pure
        returns (address[] memory, bytes[] memory)
    {
        address[] memory callContracts = new address[](quarkOperations.length);
        bytes[] memory callDatas = new bytes[](quarkOperations.length);

        // Note: This assumes there is at most only a single QuotePay on a chain
        int256 quotePayIndex = -1;
        int256 maxActionIndex = -1;
        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            if (Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_QUOTE_PAY)) {
                quotePayIndex = int256(i);
                break;
            }
        }
        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            if (
                Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_COMET_SUPPLY)
                    || Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_MORPHO_VAULT_SUPPLY)
            ) {
                // TODO: We can sanity check further by verifying the script address matches the CREATE2 address of the script
                (,, uint256 amount) =
                    abi.decode(stripSelector(quarkOperations[i].scriptCalldata), (address, address, uint256));
                if (amount == type(uint256).max) {
                    maxActionIndex = int256(i);
                    break;
                }
            }
        }
        uint256 j = 0;
        for (uint256 i = 0; i < quarkOperations.length; ++i) {
            // Insert quote pay right before the max action
            if (int256(i) == maxActionIndex) {
                if (quotePayIndex != -1) {
                    callContracts[j] = quarkOperations[uint256(quotePayIndex)].scriptAddress;
                    callDatas[j] = quarkOperations[uint256(quotePayIndex)].scriptCalldata;
                    j++;
                }
            }

            // If a max action was found, we skip re-inserting the QuotePay again (it should have already been inserted)
            if (int256(i) == quotePayIndex && maxActionIndex != -1) continue;

            callContracts[j] = quarkOperations[i].scriptAddress;
            callDatas[j] = quarkOperations[i].scriptCalldata;
            j++;
        }

        return (callContracts, callDatas);
    }

    function containsBridgeOperation(Actions.Action[] memory actions) internal pure returns (bool) {
        bool hasBridge;
        for (uint256 i = 0; i < actions.length; ++i) {
            if (Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_BRIDGE)) {
                hasBridge = true;
                break;
            }
        }
        return hasBridge;
    }

    function getExecutionType(Actions.Action[] memory actions, bool existsBridgeOperation)
        internal
        pure
        returns (string memory)
    {
        bool existsLocalBridgeOperation;
        for (uint256 i = 0; i < actions.length; ++i) {
            if (Strings.stringEq(actions[i].actionType, Actions.ACTION_TYPE_BRIDGE)) {
                existsLocalBridgeOperation = true;
                break;
            }
        }
        return existsBridgeOperation && !existsLocalBridgeOperation
            ? Actions.EXECUTION_TYPE_CONTINGENT
            : actions[actions.length - 1].executionType;
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

    function stripSelector(bytes memory data) internal pure returns (bytes memory) {
        uint256 newLength = data.length - 4;
        bytes memory result = new bytes(newLength);
        for (uint256 i = 0; i < newLength; i++) {
            result[i] = data[i + 4];
        }
        return result;
    }
}
