// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {Errors} from "src/builder/Errors.sol";
import {List} from "src/builder/List.sol";
import {HashMap} from "src/builder/HashMap.sol";

library HashMap2D {
    struct Entry {
        bytes key;
        HashMap.Map value;
    }

    struct Map {
        List.DynamicArray entries;
    }

    function newMap() internal pure returns (Map memory) {
        return Map(List.newList());
    }

    function get(Map memory map, bytes memory key1, bytes memory key2) internal pure returns (bytes memory) {
        HashMap.Map memory innerMap = getInnerMap(map, key1);
        return HashMap.get(innerMap, key2);
    }

    function getInnerMap(Map memory map, bytes memory key1) internal pure returns (HashMap.Map memory) {
        for (uint256 i = 0; i < map.entries.length; ++i) {
            Entry memory entry = abi.decode(List.get(map.entries, i), (Entry));
            if (keccak256(entry.key) == keccak256(key1)) {
                return entry.value;
            }
        }
        revert Errors.KeyNotFound();
    }

    function getOrDefault(Map memory map, bytes memory key1, bytes memory key2, bytes memory fallbackValue)
        internal
        pure
        returns (bytes memory)
    {
        if (contains(map, key1, key2)) {
            return get(map, key1, key2);
        } else {
            return fallbackValue;
        }
    }

    function contains(Map memory map, bytes memory key1, bytes memory key2) internal pure returns (bool) {
        for (uint256 i = 0; i < map.entries.length; ++i) {
            Entry memory entry = abi.decode(List.get(map.entries, i), (Entry));
            if (keccak256(entry.key) == keccak256(key1)) {
                return HashMap.contains(entry.value, key2);
            }
        }
        return false;
    }

    function put(Map memory map, bytes memory key1, bytes memory key2, bytes memory value)
        internal
        pure
        returns (Map memory)
    {
        HashMap.Map memory innerMap;

        for (uint256 i = 0; i < map.entries.length; ++i) {
            Entry memory entry = abi.decode(List.get(map.entries, i), (Entry));
            if (keccak256(entry.key) == keccak256(key1)) {
                innerMap = entry.value;
                // Update existing inner map
                innerMap = HashMap.put(innerMap, key2, value);
                Entry memory updatedEntry = Entry({key: key1, value: innerMap});
                map.entries.bytesArray[i] = abi.encode(updatedEntry);
                return map;
            }
        }

        innerMap = HashMap.newMap();
        innerMap = HashMap.put(innerMap, key2, value);
        Entry memory newEntry = Entry({key: key1, value: innerMap});
        List.addItem(map.entries, abi.encode(newEntry));
        return map;
    }

    // ========= Helper functions for common keys/values types =========

    function get(Map memory map, string memory key1, uint256 key2) internal pure returns (bytes memory) {
        return get(map, abi.encode(key1), abi.encode(key2));
    }

    function getUint256(Map memory map, string memory key1, uint256 key2) internal pure returns (uint256) {
        return abi.decode(get(map, key1, key2), (uint256));
    }

    function getOrDefaultUint256(Map memory map, string memory key1, uint256 key2, uint256 fallbackValue)
        internal
        pure
        returns (uint256)
    {
        return abi.decode(getOrDefault(map, abi.encode(key1), abi.encode(key2), abi.encode(fallbackValue)), (uint256));
    }

    function contains(Map memory map, string memory key1, uint256 key2) internal pure returns (bool) {
        return contains(map, abi.encode(key1), abi.encode(key2));
    }

    function put(Map memory map, string memory key1, uint256 key2, bytes memory value)
        internal
        pure
        returns (Map memory)
    {
        return put(map, abi.encode(key1), abi.encode(key2), value);
    }

    function putUint256(Map memory map, string memory key1, uint256 key2, uint256 value)
        internal
        pure
        returns (Map memory)
    {
        return put(map, key1, key2, abi.encode(value));
    }

    function addOrPutUint256(Map memory map, string memory key1, uint256 key2, uint256 value)
        internal
        pure
        returns (Map memory)
    {
        uint256 existingValue = getOrDefaultUint256(map, key1, key2, 0);
        return putUint256(map, key1, key2, existingValue + value);
    }
}
