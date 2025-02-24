// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {HashMap} from "src/builder/HashMap.sol";

library BalanceChanges {
    /// @dev Tracks net asset balance changes.
    ///      Each entry maps an asset symbol, chain ID, account tuple to an amount:
    ///         map[symbol][chainId][wallet] → balance change
    struct Deltas {
        HashMap.Map map;
    }

    function newDeltas() internal pure returns (Deltas memory) {
        return Deltas(HashMap.newMap());
    }

    function get(Deltas memory changes, string memory assetSymbol, uint256 chainId, address account)
        internal
        pure
        returns (uint256)
    {
        HashMap.Map memory accountMap = getAccountMap(changes, assetSymbol, chainId);
        return abi.decode(HashMap.get(accountMap, account), (uint256));
    }

    function getOrDefault(
        Deltas memory changes,
        string memory assetSymbol,
        uint256 chainId,
        address account,
        uint256 fallbackValue
    ) internal pure returns (uint256) {
        if (contains(changes, assetSymbol, chainId, account)) {
            return get(changes, assetSymbol, chainId, account);
        } else {
            return fallbackValue;
        }
    }

    function contains(Deltas memory changes, string memory assetSymbol, uint256 chainId, address account)
        internal
        pure
        returns (bool)
    {
        if (HashMap.contains(changes.map, abi.encode(assetSymbol))) {
            HashMap.Map memory chainIdMap = getChainIdMap(changes, assetSymbol);
            if (HashMap.contains(chainIdMap, chainId)) {
                HashMap.Map memory accountMap = getAccountMap(changes, assetSymbol, chainId);
                if (HashMap.contains(accountMap, account)) {
                    return true;
                }
            }
        }
        return false;
    }

    function put(Deltas memory changes, string memory assetSymbol, uint256 chainId, address account, uint256 value)
        internal
        pure
        returns (Deltas memory)
    {
        HashMap.Map memory chainIdMap;
        if (HashMap.contains(changes.map, abi.encode(assetSymbol))) {
            chainIdMap = getChainIdMap(changes, assetSymbol);
        } else {
            chainIdMap = HashMap.newMap();
        }

        HashMap.Map memory accountMap;
        if (HashMap.contains(chainIdMap, chainId)) {
            accountMap = getAccountMap(changes, assetSymbol, chainId);
        } else {
            accountMap = HashMap.newMap();
        }

        accountMap = HashMap.putUint256(accountMap, abi.encode(account), value);
        chainIdMap = HashMap.put(chainIdMap, chainId, abi.encode(accountMap));
        changes.map = HashMap.put(changes.map, abi.encode(assetSymbol), abi.encode(chainIdMap));
        return changes;
    }

    function getChainIdMap(Deltas memory changes, string memory assetSymbol)
        internal
        pure
        returns (HashMap.Map memory)
    {
        return abi.decode(HashMap.get(changes.map, abi.encode(assetSymbol)), (HashMap.Map));
    }

    function getAccountMap(Deltas memory changes, string memory assetSymbol, uint256 chainId)
        internal
        pure
        returns (HashMap.Map memory)
    {
        HashMap.Map memory chainIdMap = getChainIdMap(changes, assetSymbol);
        return abi.decode(HashMap.get(chainIdMap, abi.encode(chainId)), (HashMap.Map));
    }

    function addOrPutUint256(
        Deltas memory changes,
        string memory assetSymbol,
        uint256 chainId,
        address account,
        uint256 value
    ) internal pure returns (Deltas memory) {
        HashMap.Map memory chainIdMap;
        if (HashMap.contains(changes.map, abi.encode(assetSymbol))) {
            chainIdMap = getChainIdMap(changes, assetSymbol);
        } else {
            chainIdMap = HashMap.newMap();
        }

        HashMap.Map memory accountMap;
        if (HashMap.contains(chainIdMap, chainId)) {
            accountMap = getAccountMap(changes, assetSymbol, chainId);
        } else {
            accountMap = HashMap.newMap();
        }

        accountMap = HashMap.addOrPutUint256(accountMap, abi.encode(account), value);
        chainIdMap = HashMap.put(chainIdMap, chainId, abi.encode(accountMap));
        changes.map = HashMap.put(changes.map, abi.encode(assetSymbol), abi.encode(chainIdMap));
        return changes;
    }

    function assetSymbols(Deltas memory changes) internal pure returns (string[] memory) {
        return HashMap.keysString(changes.map);
    }

    function chainIds(Deltas memory changes, string memory assetSymbol) internal pure returns (uint256[] memory) {
        HashMap.Map memory chainIdMap;
        if (HashMap.contains(changes.map, abi.encode(assetSymbol))) {
            chainIdMap = getChainIdMap(changes, assetSymbol);
        } else {
            chainIdMap = HashMap.newMap();
        }

        return HashMap.keysUint256(chainIdMap);
    }

    function accounts(Deltas memory changes, string memory assetSymbol, uint256 chainId)
        internal
        pure
        returns (address[] memory)
    {
        HashMap.Map memory chainIdMap;
        if (HashMap.contains(changes.map, abi.encode(assetSymbol))) {
            chainIdMap = getChainIdMap(changes, assetSymbol);
        } else {
            chainIdMap = HashMap.newMap();
        }

        HashMap.Map memory accountMap;
        if (HashMap.contains(chainIdMap, chainId)) {
            accountMap = getAccountMap(changes, assetSymbol, chainId);
        } else {
            accountMap = HashMap.newMap();
        }

        return HashMap.keysAddress(accountMap);
    }
}
