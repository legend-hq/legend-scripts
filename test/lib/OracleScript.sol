// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {TStoracle} from "../../src/TStoracle.sol";
import {Counter} from "test/lib/Counter.sol";

/**
 * @title Oracle Script for Testing
 * @author Legend Labs, Inc.
 */
contract OracleScript {
    /**
     * @notice Increments a counter based on the value from tStoracle
     * @param tStoracle TStoracle contract to read from
     * @param counter Counter to increment
     */
    function incrementCounter(TStoracle tStoracle, Counter counter) external {
        uint256 amount = abi.decode(tStoracle.get("amount"), (uint256));
        counter.increment(amount);
    }
}
