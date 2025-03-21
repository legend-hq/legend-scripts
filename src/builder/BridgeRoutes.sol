// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {AcrossActions} from "src/AcrossScripts.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {Errors} from "src/builder/Errors.sol";
import {HashMap} from "src/builder/HashMap.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";

import "src/builder/Strings.sol";

library BridgeRoutes {
    function canBridge(uint256 srcChainId, uint256 dstChainId, string memory assetSymbol)
        internal
        pure
        returns (bool)
    {
        return
            CCTP.canBridge(srcChainId, dstChainId, assetSymbol) || Across.canBridge(srcChainId, dstChainId, assetSymbol);
    }
}

library CCTP {
    error NoKnownDomainId(string bridgeType, uint256 dstChainId);

    struct CCTPChain {
        uint256 chainId;
        uint32 domainId;
        address bridge;
    }

    // @dev Source: TokenMessenger contract from https://developers.circle.com/stablecoins/evm-smart-contracts
    function knownChains() internal pure returns (CCTPChain[] memory) {
        CCTPChain[] memory chains = new CCTPChain[](7);
        // Mainnet
        chains[0] = CCTPChain({chainId: 1, domainId: 0, bridge: 0xBd3fa81B58Ba92a82136038B25aDec7066af3155});
        // Base
        chains[1] = CCTPChain({chainId: 8453, domainId: 6, bridge: 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962});
        // Arbitrum
        chains[2] = CCTPChain({chainId: 42161, domainId: 3, bridge: 0x19330d10D9Cc8751218eaf51E8885D058642E08A});
        // Sepolia
        chains[3] = CCTPChain({chainId: 11155111, domainId: 0, bridge: 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5});
        // Base Sepolia
        chains[4] = CCTPChain({chainId: 84532, domainId: 6, bridge: 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5});
        // Arbitrum Sepolia
        chains[5] = CCTPChain({chainId: 421614, domainId: 3, bridge: 0x9f3B8679c73C2Fef8b59B4f3444d4e156fb70AA5});
        // Optimism
        chains[6] = CCTPChain({chainId: 10, domainId: 10, bridge: 0x2B4069517957735bE00ceE0fadAE88a26365528f});
        return chains;
    }

    function knownChain(uint256 chainId) internal pure returns (CCTPChain memory found) {
        CCTPChain[] memory cctpChains = knownChains();
        for (uint256 i = 0; i < cctpChains.length; ++i) {
            if (cctpChains[i].chainId == chainId) {
                return found = cctpChains[i];
            }
        }
    }

    function canBridge(uint256 srcChainId, uint256 dstChainId, string memory assetSymbol)
        internal
        pure
        returns (bool)
    {
        return Strings.stringEqIgnoreCase(assetSymbol, "USDC") && knownChain(srcChainId).bridge != address(0)
            && knownChain(dstChainId).chainId == dstChainId;
    }

    function knownDomainId(uint256 dstChainId) internal pure returns (uint32) {
        CCTPChain memory chain = knownChain(dstChainId);
        if (chain.chainId != 0) {
            return chain.domainId;
        } else {
            revert NoKnownDomainId("CCTP", dstChainId);
        }
    }

    function knownBridge(uint256 srcChainId) internal pure returns (address) {
        CCTPChain memory chain = knownChain(srcChainId);
        if (chain.bridge != address(0)) {
            return chain.bridge;
        } else {
            revert Errors.NoKnownBridge("CCTP", srcChainId);
        }
    }

    function bridgeScriptSource() internal pure returns (bytes memory) {
        return type(CCTPBridgeActions).creationCode;
    }

    function encodeBridgeUSDC(
        uint256 srcChainId,
        uint256 dstChainId,
        uint256 amount,
        address recipient,
        address usdcAddress,
        bool cappedMax
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            CCTPBridgeActions.bridgeUSDC.selector,
            knownBridge(srcChainId),
            amount,
            knownDomainId(dstChainId),
            bytes32(uint256(uint160(recipient))),
            usdcAddress,
            cappedMax
        );
    }
}

library Across {
    struct AcrossChain {
        uint256 chainId;
        address bridge; // SpokePool contract
    }

    /// @notice The unique ID given to Legend by the Across team to track the origination source of deposits
    bytes constant UNIQUE_IDENTIFIER = hex"0067";

    /// @notice The buffer to subtrace from the quote timestamp to ensure it isn't some time in
    ///         the future, which would cause the Across SpokePool contract to revert
    uint32 public constant QUOTE_TIMESTAMP_BUFFER = 30 seconds;

    /// @notice The amount of time that the bridge action has to be filled before timing out
    uint256 public constant FILL_DEADLINE_BUFFER = 10 minutes;

    // @dev Source: SpokePool contracts from https://docs.across.to/reference/contract-addresses
    function knownChains() internal pure returns (AcrossChain[] memory) {
        AcrossChain[] memory chains = new AcrossChain[](7);
        // Mainnet
        chains[0] = AcrossChain({chainId: 1, bridge: 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5});
        // Base
        chains[1] = AcrossChain({chainId: 8453, bridge: 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64});
        // Arbitrum
        chains[2] = AcrossChain({chainId: 42161, bridge: 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A});
        // Sepolia
        chains[3] = AcrossChain({chainId: 11155111, bridge: 0x5ef6C01E11889d86803e0B23e3cB3F9E9d97B662});
        // Base Sepolia
        chains[4] = AcrossChain({chainId: 84532, bridge: 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F});
        // Arbitrum Sepolia
        chains[5] = AcrossChain({chainId: 84532, bridge: 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A});
        // Optimism
        chains[6] = AcrossChain({chainId: 10, bridge: 0x6f26Bf09B1C792e3228e5467807a900A503c0281});
        return chains;
    }

    function knownChain(uint256 chainId) internal pure returns (AcrossChain memory found) {
        AcrossChain[] memory acrossChains = knownChains();
        for (uint256 i = 0; i < acrossChains.length; ++i) {
            if (acrossChains[i].chainId == chainId) {
                return found = acrossChains[i];
            }
        }
    }

    function canBridge(uint256 srcChainId, uint256 dstChainId, string memory assetSymbol)
        internal
        pure
        returns (bool)
    {
        return knownChain(srcChainId).bridge != address(0) && knownChain(dstChainId).chainId == dstChainId
            && (
                Strings.stringEqIgnoreCase(assetSymbol, "USDC") || Strings.stringEqIgnoreCase(assetSymbol, "WETH")
                    || Strings.stringEqIgnoreCase(assetSymbol, "ETH")
            );
    }

    function knownBridge(uint256 srcChainId) internal pure returns (address) {
        AcrossChain memory chain = knownChain(srcChainId);
        if (chain.bridge != address(0)) {
            return chain.bridge;
        } else {
            revert Errors.NoKnownBridge("Across", srcChainId);
        }
    }

    function bridgeScriptSource() internal pure returns (bytes memory) {
        return type(AcrossActions).creationCode;
    }

    function encodeBridgeAction(
        uint256 srcChainId,
        uint256 dstChainId,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        address sender,
        address recipient,
        uint256 blockTimestamp,
        bool useNativeToken,
        bool cappedMax
    ) internal pure returns (bytes memory) {
        return abi.encodeCall(
            AcrossActions.depositV3,
            (
                knownBridge(srcChainId), // spokePool
                AcrossActions.DepositV3Params({
                    depositor: sender,
                    recipient: recipient,
                    inputToken: inputToken,
                    outputToken: outputToken,
                    inputAmount: inputAmount,
                    outputAmount: outputAmount,
                    destinationChainId: dstChainId,
                    exclusiveRelayer: address(0),
                    quoteTimestamp: uint32(blockTimestamp) - QUOTE_TIMESTAMP_BUFFER,
                    fillDeadline: uint32(blockTimestamp + FILL_DEADLINE_BUFFER),
                    exclusivityDeadline: 0,
                    message: new bytes(0)
                }), // params
                UNIQUE_IDENTIFIER, // uniqueIdentifier
                useNativeToken, // useNativeToken
                cappedMax // cappedMax
            )
        );
    }
}
