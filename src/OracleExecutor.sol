// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {QuarkWallet} from "quark-core/src/QuarkWallet.sol";
import {TStoracle} from "src/TStoracle.sol";

/**
 * @title Oracle Executor for Quark Operations
 * @notice Allows submission of Quark Operations with offchain oracle data.
 * @notice Note: it's the responsibility of the running quark script to read and authenticate the oracle data.
 * @author Legend Labs, Inc.
 */
contract OracleExecutor {
    error InvalidOracleValues();

    /**
     * @notice Writes given values to the TStoracle and then executes a single quark operation.
     * @dev Note: TStoracle values are not themselves protected. The executed script must verify all data.
     * @param tStoracle Address of TStoracle to temporarily store input data.
     * @param oracleKeys List of keys to store in TStoracle.
     * @param oracleValues List of values to store in TStoracle, coupled with oracleKeys.
     * @param walletAddress The address of the quark wallet on which to execute the script.
     * @param op The QuarkOperation to execute on the wallet
     * @param signature A digital signature, e.g. EIP-712
     * @return bytes Return value of executing the operation
     */
    function executeSingle(
        TStoracle tStoracle,
        bytes[] calldata oracleKeys,
        bytes[] calldata oracleValues,
        QuarkWallet walletAddress,
        QuarkWallet.QuarkOperation calldata op,
        bytes calldata signature
    ) external returns (bytes memory) {
        require(oracleKeys.length == oracleValues.length, InvalidOracleValues());

        for (uint256 i = 0; i < oracleKeys.length; ++i) {
            tStoracle.put(oracleKeys[i], oracleValues[i]);
        }

        return QuarkWallet(walletAddress).executeQuarkOperation(op, signature);
    }

    /**
     * @notice Writes given values to the TStoracle and then executes a multi quark operation.
     * @dev Note: TStoracle values are not themselves protected. The executed script must verify all data.
     * @param tStoracle Address of TStoracle to temporarily store input data.
     * @param oracleKeys List of keys to store in TStoracle.
     * @param oracleValues List of values to store in TStoracle, coupled with oracleKeys.
     * @param walletAddress The address of the quark wallet on which to execute the script.
     * @param op The QuarkOperation to execute on the wallet
     * @param opDigests A list of EIP-712 digests for the operations in a MultiQuarkOperation
     * @param signature A digital signature, e.g. EIP-712
     * @return bytes Return value of executing the operation
     */
    function executeMulti(
        TStoracle tStoracle,
        bytes[] calldata oracleKeys,
        bytes[] calldata oracleValues,
        QuarkWallet walletAddress,
        QuarkWallet.QuarkOperation calldata op,
        bytes32[] calldata opDigests,
        bytes calldata signature
    ) external returns (bytes memory) {
        require(oracleKeys.length == oracleValues.length, InvalidOracleValues());

        for (uint256 i = 0; i < oracleKeys.length; ++i) {
            tStoracle.put(oracleKeys[i], oracleValues[i]);
        }

        return walletAddress.executeMultiQuarkOperation(op, opDigests, signature);
    }
}
