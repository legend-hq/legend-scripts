// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import {KnownAsset, KnownPriceFeed, Chain} from "./BuilderPack.2025-02-03+5167e582.sol";
import {Strings} from "./Strings.sol";

library BuilderPackHelper {
    function knownAssetAddress(string memory tokenSymbol, uint256 chainId)
        internal
        pure
        returns (string memory, address)
    {
        KnownAsset[] memory knownAssets = Chain.knownAssets(chainId);
        for (uint256 i = 0; i < knownAssets.length; ++i) {
            if (Strings.stringEqIgnoreCase(tokenSymbol, knownAssets[i].symbol)) {
                return (Strings.OK, knownAssets[i].assetAddress);
            }
        }

        return (Strings.ERROR, address(0));
    }

    function knownPriceFeedAddress(string memory symbolIn, string memory symbolOut, uint256 chainId)
        internal
        pure
        returns (string memory, address)
    {
        KnownPriceFeed[] memory knownPriceFeeds = Chain.knownPriceFeeds(chainId);

        for (uint256 i = 0; i < knownPriceFeeds.length; ++i) {
            if (
                Strings.stringEqIgnoreCase(symbolOut, knownPriceFeeds[i].symbolOut)
                    && Strings.stringEqIgnoreCase(symbolIn, knownPriceFeeds[i].symbolIn)
            ) {
                return (Strings.OK, knownPriceFeeds[i].priceFeed);
            }
        }

        return (Strings.ERROR, address(0));
    }
}
