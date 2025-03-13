// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >= 0.8.0;

/**
 * @title Transient Storage Oracle
 * @notice An on-chain oracle that stores values using `tstore` instead of `sstore`. First write wins.
 * @author Legend Labs, Inc.
 */
contract TStoracle {
    error KeyAlreadySet(bytes key);

    /**
     *  The layout of transient storage looks like:
     *
     *    hash(key)   -> bytesize(value)
     *    hash(key)+1 -> value{0..31}
     *    hash(key)+2 -> value{32..63}
     *    // ...
     */

    /**
     * @notice Sets a value on the oracle under a given key. Reverts if key already set.
     * @dev Note: storing a value of `hex""` allows the key to be written later.
     * @param key Key to store
     * @param value Value to store
     */
    function put(bytes memory key, bytes memory value) external {
        bytes32 digest = keccak256(key);
        require(loadByteSize(digest) == 0, KeyAlreadySet(key));
        uint256 byteSize = value.length;
        uint256 words = getWordCount(byteSize);

        // Note: when i=0, we are storing the byte size of the value.
        for (uint256 i = 0; i <= words; i++) {
            uint256 offset = i * 32;
            bytes32 subValue;

            // Store each sub value
            assembly {
                subValue := mload(add(value, offset))
                tstore(add(digest, i), subValue)
            }
        }
    }

    /**
     * @notice Returns the oracle value associated with the given key.
     * @param key Key to load
     * @return value The value or `hex""` if key not set.
     */
    function get(bytes memory key) external view returns (bytes memory value) {
        bytes32 digest = keccak256(key);
        uint256 byteSize = loadByteSize(digest);
        uint256 words = getWordCount(byteSize);
        value = new bytes(byteSize);

        // Note: we are skipping i=0, as we already read the byte size above.
        for (uint256 i = 1; i <= words; i++) {
            uint256 offset = i * 32;
            bytes32 subValue;
            assembly {
                subValue := tload(add(digest, i))
                mstore(add(value, offset), subValue)
            }
        }
    }

    // Returns the byte size of the current data for the given digest.
    // Returns 0 for unset value.
    function loadByteSize(bytes32 digest) internal view returns (uint256 byteSize) {
        assembly {
            byteSize := tload(digest)
        }
    }

    // Helper function get the minimum number words to include byteSize,
    // effectively being ⌈byteSize/32⌉.
    function getWordCount(uint256 byteSize) internal pure returns (uint256 wordCount) {
        return (byteSize + 31) / 32;
    }
}
