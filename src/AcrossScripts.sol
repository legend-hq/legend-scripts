// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";

import {IAcrossV3SpokePool} from "./interfaces/IAcrossV3SpokePool.sol";

contract AcrossActions {
    // To handle non-standard ERC20 tokens (i.e. USDT)
    using SafeERC20 for IERC20;

    error BridgeFeeTooHigh(uint256 bridgeFee, uint256 maxBridgeFee);

    // @notice The parameters required for bridging an asset via Across V3
    struct DepositV3Params {
        // @notice The account credited with the deposit.
        address depositor;
        // @notice The account receiving funds on the destination chain. Can be an EOA or a contract.
        // If the output token is the wrapped native token for the chain, then the recipient will receive
        // native token if an EOA or wrapped native token if a contract.
        address recipient;
        // @notice The token pulled from the caller's account and locked into this contract to initiate the deposit.
        // If this is equal to the wrapped native token then the caller can optionally pass in native token as msg.value,
        // as long as msg.value = inputTokenAmount.
        address inputToken;
        // @notice The token that the relayer will send to the recipient on the destination chain. Must be an ERC20.
        // @dev This should be the same asset as the `inputToken`. See the dev note for `maxFee`.
        address outputToken;
        // @notice The amount of input tokens to pull from the caller's account and lock into this contract.
        uint256 inputAmount;
        // @notice The amount of output tokens that the relayer will send to the recipient on the destination.
        uint256 outputAmount;
        // @notice The maximum fee that can be charged for the bridge.
        // @dev This value is in terms of the `outputToken` and is only valid when the input and output tokens are the same asset.
        uint256 maxFee;
        // @notice The destination chain identifier.
        uint256 destinationChainId;
        // @notice The relayer that will be exclusively allowed to fill this deposit before the exclusivity deadline timestamp.
        // This must be a valid, non-zero address if the exclusivity deadline is greater than the current block.timestamp.
        // If the exclusivity deadline is < currentTime, then this must be address(0), and vice versa if this is address(0).
        address exclusiveRelayer;
        // @notice The HubPool timestamp that is used to determine the system fee paid by the depositor.
        // This must be set to some time between [currentTime - depositQuoteTimeBuffer, currentTime]
        // where currentTime is block.timestamp on this chain or this transaction will revert.
        uint32 quoteTimestamp;
        // @notice The deadline for the relayer to fill the deposit. After this destination chain timestamp,
        // the fill will revert on the destination chain. Must be set between [currentTime, currentTime + fillDeadlineBuffer]
        // where currentTime is block.timestamp on this chain or this transaction will revert.
        uint32 fillDeadline;
        // @notice The deadline for the exclusive relayer to fill the deposit. After this destination chain timestamp,
        // anyone can fill this deposit on the destination chain. If exclusiveRelayer is set to address(0),
        // then this also must be set to 0, (and vice versa), otherwise this must be set >= current time.
        uint32 exclusivityDeadline;
        // @notice The message to send to the recipient on the destination chain if the recipient is a contract.
        // If the message is not empty, the recipient contract must implement handleV3AcrossMessage() or the fill will revert.
        bytes message;
    }

    // @notice The delimiter used to separate the deposit transaction calldata from the unique identifier
    bytes constant UNIQUE_IDENTIFIER_DELIMITER = hex"1dc0de";

    /**
     * @notice Bridge an asset to the destination chain by depositing it into the Across v3 SpokePool
     * @param spokePool The address of the Across v3 SpokePool contract
     * @param params The parameters required for bridging an asset with Across V3
     * @param uniqueIdentifier The unique identifier given to integrators to track the origination source for deposits
     * @param useNativeToken Whether or not the native token (e.g. ETH) should be used as the input token
     */
    function depositV3(
        address spokePool,
        DepositV3Params memory params,
        bytes calldata uniqueIdentifier,
        bool useNativeToken
    ) external payable {
        if (params.inputAmount == type(uint256).max) {
            params.inputAmount = IERC20(params.inputToken).balanceOf(address(this));
        }
        IERC20(params.inputToken).forceApprove(spokePool, params.inputAmount);

        uint256 bridgeFee = params.inputAmount - params.outputAmount;
        if (bridgeFee > params.maxFee) {
            revert BridgeFeeTooHigh(bridgeFee, params.maxFee);
        }

        // Encode the function call with all parameters
        bytes memory callData = abi.encodeWithSelector(
            IAcrossV3SpokePool.depositV3.selector,
            params.depositor,
            params.recipient,
            params.inputToken,
            params.outputToken,
            params.inputAmount,
            params.outputAmount,
            params.destinationChainId,
            params.exclusiveRelayer,
            params.quoteTimestamp,
            params.fillDeadline,
            params.exclusivityDeadline,
            params.message
        );

        // Append the delimiter and identifier
        bytes memory callDataWithIdentifier = bytes.concat(callData, UNIQUE_IDENTIFIER_DELIMITER, uniqueIdentifier);

        (bool success, bytes memory returnData) =
            spokePool.call{value: useNativeToken ? params.inputAmount : 0}(callDataWithIdentifier);

        if (!success) {
            assembly {
                revert(add(returnData, 0x20), mload(returnData))
            }
        }
    }
}
