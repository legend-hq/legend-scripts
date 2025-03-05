// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Arrays} from "src/builder/lib/Arrays.sol";
import {Accounts, PaymentInfo, QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {CometClaimRewards} from "src/DeFiScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {List} from "src/builder/List.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderCometClaimRewardsTest is Test, QuarkBuilderTest {
    address constant CLAIMER = address(0xa11ce);

    function cometClaimRewardsIntent_(string memory paymentAssetSymbol)
        internal
        pure
        returns (QuarkBuilderBase.CometClaimRewardsIntent memory)
    {
        return QuarkBuilderBase.CometClaimRewardsIntent({
            blockTimestamp: BLOCK_TIMESTAMP,
            claimer: CLAIMER,
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function testCometClaimRewards() public {
        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 0,
            baseBorrowed: 0,
            collateralAssetSymbols: new string[](0),
            collateralAssetBalances: new uint256[](0),
            rewardAssetSymbols: Arrays.stringArray("WETH"),
            rewardContracts: Arrays.addressArray(COMET_REWARDS_1),
            rewardsOwed: Arrays.uintArray(1e18)
        });
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: emptyMorphoRewardPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometClaimRewards(
            cometClaimRewardsIntent_({paymentAssetSymbol: "USD"}),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            CodeJarHelper.getCodeAddress(type(CometClaimRewards).creationCode),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                CometClaimRewards.claim,
                (Arrays.addressArray(COMET_REWARDS_1), Arrays.addressArray(cometUsdc_(1)), Arrays.addressArray(CLAIMER))
            ),
            "calldata is CometClaimRewards.claim([COMET_REWARDS_1], [COMET_1], [CLAIMER]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainId 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "COMET_CLAIM_REWARDS", "action type is 'COMET_CLAIM_REWARDS'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");

        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.CometClaimRewardsActionContext({
                    amounts: Arrays.uintArray(1e18),
                    assetSymbols: Arrays.stringArray("WETH"),
                    chainId: 1,
                    prices: Arrays.uintArray(WETH_PRICE),
                    tokens: Arrays.addressArray(WETH_1)
                })
            ),
            "action context encoded from CometClaimRewardsActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometClaimRewardsOnMultipleChains() public {
        CometPortfolio[] memory cometPortfolios_1 = new CometPortfolio[](1);
        cometPortfolios_1[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 0,
            baseBorrowed: 0,
            collateralAssetSymbols: new string[](0),
            collateralAssetBalances: new uint256[](0),
            rewardAssetSymbols: Arrays.stringArray("WETH"),
            rewardContracts: Arrays.addressArray(COMET_REWARDS_1),
            rewardsOwed: Arrays.uintArray(1e18)
        });
        CometPortfolio[] memory cometPortfolios_8453 = new CometPortfolio[](1);
        cometPortfolios_8453[0] = CometPortfolio({
            comet: cometUsdc_(8453),
            baseSupplied: 0,
            baseBorrowed: 0,
            collateralAssetSymbols: new string[](0),
            collateralAssetBalances: new uint256[](0),
            rewardAssetSymbols: Arrays.stringArray("WETH"),
            rewardContracts: Arrays.addressArray(COMET_REWARDS_8453),
            rewardsOwed: Arrays.uintArray(1e18)
        });
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios_1,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: emptyMorphoRewardPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios_8453,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: emptyMorphoRewardPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometClaimRewards(
            cometClaimRewardsIntent_({paymentAssetSymbol: "USD"}),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 2, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            CodeJarHelper.getCodeAddress(type(CometClaimRewards).creationCode),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                CometClaimRewards.claim,
                (Arrays.addressArray(COMET_REWARDS_1), Arrays.addressArray(cometUsdc_(1)), Arrays.addressArray(CLAIMER))
            ),
            "calldata is CometClaimRewards.claim([COMET_REWARDS_1], [COMET_1], [CLAIMER]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");
        assertEq(
            result.quarkOperations[1].scriptAddress,
            CodeJarHelper.getCodeAddress(type(CometClaimRewards).creationCode),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(
                CometClaimRewards.claim,
                (
                    Arrays.addressArray(COMET_REWARDS_8453),
                    Arrays.addressArray(cometUsdc_(8453)),
                    Arrays.addressArray(CLAIMER)
                )
            ),
            "calldata is CometClaimRewards.claim([COMET_REWARDS_8453], [COMET_8453], [CLAIMER]);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 2, "two actions");
        assertEq(result.actions[0].chainId, 1, "operation is on chainId 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "COMET_CLAIM_REWARDS", "action type is 'COMET_CLAIM_REWARDS'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.CometClaimRewardsActionContext({
                    amounts: Arrays.uintArray(1e18),
                    assetSymbols: Arrays.stringArray("WETH"),
                    chainId: 1,
                    prices: Arrays.uintArray(WETH_PRICE),
                    tokens: Arrays.addressArray(WETH_1)
                })
            ),
            "action context encoded from CometClaimRewardsActionContext"
        );
        assertEq(result.actions[1].chainId, 8453, "operation is on chainId 8453");
        assertEq(result.actions[1].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[1].actionType, "COMET_CLAIM_REWARDS", "action type is 'COMET_CLAIM_REWARDS'");
        assertEq(result.actions[1].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[1].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.CometClaimRewardsActionContext({
                    amounts: Arrays.uintArray(1e18),
                    assetSymbols: Arrays.stringArray("WETH"),
                    chainId: 8453,
                    prices: Arrays.uintArray(WETH_PRICE),
                    tokens: Arrays.addressArray(WETH_8453)
                })
            ),
            "action context encoded from CometClaimRewardsActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometClaimRewardsPayWithReward() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] = Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 1e8});

        // The user has no assets in their account, but has claimable reward assets
        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 0,
            baseBorrowed: 0,
            collateralAssetSymbols: new string[](0),
            collateralAssetBalances: new uint256[](0),
            rewardAssetSymbols: Arrays.stringArray("USDC"),
            rewardContracts: Arrays.addressArray(COMET_REWARDS_1),
            rewardsOwed: Arrays.uintArray(1e6)
        });
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: emptyMorphoRewardPortfolios_()
        });

        QuarkBuilder.BuilderResult memory result = builder.cometClaimRewards(
            cometClaimRewardsIntent_({paymentAssetSymbol: "USDC"}),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        address cometClaimRewardsAddress = CodeJarHelper.getCodeAddress(type(CometClaimRewards).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometClaimRewardsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(
            CometClaimRewards.claim,
            (Arrays.addressArray(COMET_REWARDS_1), Arrays.addressArray(cometUsdc_(1)), Arrays.addressArray(CLAIMER))
        );
        callDatas[1] = abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometClaimRewardsAddress, quotePayAddress], [CometClaimRewards.claim([COMET_REWARDS_1], [COMET_1], [CLAIMER]), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 1e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 0);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainId 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "MULTI_ACTION", "action type is 'MULTI_ACTION'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MultiActionContext({
                    actionTypes: Arrays.stringArray(Actions.ACTION_TYPE_COMET_CLAIM_REWARDS, Actions.ACTION_TYPE_QUOTE_PAY),
                    actionContexts: Arrays.bytesArray(
                        abi.encode(
                            Actions.CometClaimRewardsActionContext({
                                amounts: Arrays.uintArray(1e6),
                                assetSymbols: Arrays.stringArray("USDC"),
                                chainId: 1,
                                prices: Arrays.uintArray(USDC_PRICE),
                                tokens: Arrays.addressArray(USDC_1)
                            })
                        ),
                        abi.encode(
                            Actions.QuotePayActionContext({
                                amount: 1e6,
                                assetSymbol: "USDC",
                                chainId: 1,
                                price: USDC_PRICE,
                                token: USDC_1,
                                payee: Actions.QUOTE_PAY_RECIPIENT,
                                quoteId: QUOTE_ID
                            })
                        )
                    )
                })
            ),
            "action context encoded from MultiActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometClaimRewardsMaxCostTooHigh() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](3);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 100e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 100e8});
        networkOperationFees[2] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 7777, price: 100e8});

        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructQuotePay.selector, "IMPOSSIBLE_TO_CONSTRUCT", "USDC", 100e6
            )
        );
        builder.cometClaimRewards(
            cometClaimRewardsIntent_({paymentAssetSymbol: "USDC"}),
            chainAccountsList_(2e6),
            quote_(networkOperationFees)
        );
    }
}
