// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.28;

import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title TStoracle
 * @notice An oracle that uses tstore
 * @author Legend Labs, Inc.
 */
contract TStoracle {
    bytes transient tData;

    /**
     * @notice Pay the payee the quoted amount of the payment token
     * @param payee The receiver of this payment
     * @param paymentToken The token used to pay for this transaction
     * @param quotedAmount The quoted network fee for this transaction, in units of the payment token
     * @param quoteId The identifier of the quote that is being paid
     */
    function store(bytes calldata data) external {
        tData = data;
    }

    function read() external view returns (bytes memory) {
        return tData;
    }
}
