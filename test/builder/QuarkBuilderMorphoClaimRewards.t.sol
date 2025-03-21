// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Arrays} from "src/builder/lib/Arrays.sol";
import {Accounts, PaymentInfo, QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {TransferActions} from "src/DeFiScripts.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {MorphoRewardsActions} from "src/MorphoScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {List} from "src/builder/List.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {MorphoActionsBuilder} from "src/builder/actions/MorphoActionsBuilder.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderMorphoClaimRewardsTest is Test, QuarkBuilderTest {
    address constant CLAIMER = address(0xa11ce);
    address[] FIXTURE_DISTRIBUTORS =
        [0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb, 0x330eefa8a787552DC5cAd3C3cA644844B1E61Ddb];
    address[] FIXTURE_ACCOUNTS = [address(0xa11ce), address(0xa11ce)];
    string[] FIXTURE_REWARD_ASSET_SYMBOLS = ["USDC", "WETH"];
    address[] FIXTURE_REWARDS = [usdc_(1), weth_(1)];
    uint256[] FIXTURE_CLAIMABLES = [100e6, 2e18];
    bytes32[][] FIXTURE_PROOFS = [
        [
            bytes32(0xce63a4c1fabb68437d0e5edc21b732c5a215f1c5a9ed6a52902f0415e148cc0a),
            bytes32(0x23b2ad869c44ff4946d49f0e048edd1303f0cef3679d3e21143c4cfdcde97f20),
            bytes32(0x937a82a4d574f809052269e6d4a5613fa4ce333064d012e96e9cc3c04fee7a9c),
            bytes32(0xf93fea78509a3b4fe28d963d965ab8819bbf6c08f5789bddde16127e98e6f696),
            bytes32(0xbb53cefdee57ab5a04a7be61a15c1ea00beacd0a4adb132dd2e046582eafbec8),
            bytes32(0x3dcb507af99e19c829fc2f5a8f57418258230818d4db8dc3080e5cafff5bfd3c),
            bytes32(0xca3e0c0cc07c55a02cbc21313bbd9a4d27dae6a28580fbd7dfad74216d4edac3),
            bytes32(0x59bdab6ff3d8cd5c682ff241da1d56e9bba6f5c0a739c28629c10ffab8bb9c95),
            bytes32(0x56a6fd126541d4a6b4902b78125db2c92b3b9cfb3249bbe3681cc2ccf9a6aa2c),
            bytes32(0xfcfad3b73969b50e0369e94db6fcd9301b5e776784620a09c0b52a5cf3326f2b),
            bytes32(0x7ee3c650dc15c36a6a0284c40b61391f7ac07f57d50802d92d2ccb7a19ff9dbb)
        ],
        [
            bytes32(0x7ac5a364f8e3d902a778e6f22d9800304bce9a24108a6b375e9d7afffa586648),
            bytes32(0xd0e2f9d70a7c8ddfe74cf2e922067421f06af4c16da32c13d13e6226aff54772),
            bytes32(0x8417ffe0c1e153c75ad3bf85f8d52b22ebc5370deda637231cb7fef3238d60b7),
            bytes32(0x99baa8011e519a6650c7f8887edde764c9198973be390dfad9a43e8af4603326),
            bytes32(0x7db554929334c43f06c93b0917a22765ba0b27684eb3bdbb09eefaad665cf51f),
            bytes32(0xd35638edfe77f64712acd397cfddd12da5ba480d05d77b52fa5f9f930b8c4a11),
            bytes32(0xee0010ba447e3edda1a034acc142e66ce5c772dc9cbbdf86044e5ee760d4159f),
            bytes32(0xedca6a5e9ba49d334eebdc4167e1730fcce5c7e4bbc17638c1cb6b4c42e85e9b),
            bytes32(0xfd8786de55c7c2e69c4ede4fe80b5d696875621b7aea7f29736451d3ea667427),
            bytes32(0xff695c9c3721e77a593d67cf0cbea7d495d0120ed51e31ab1428a7251665ce37),
            bytes32(0x487b38c91a22d77f124819ab4d40eea67b11683459c458933cae385630c90816)
        ]
    ];

    function morphoClaimRewardsIntent_(string memory paymentAssetSymbol)
        internal
        pure
        returns (QuarkBuilderBase.MorphoRewardsClaimIntent memory)
    {
        return QuarkBuilderBase.MorphoRewardsClaimIntent({
            blockTimestamp: BLOCK_TIMESTAMP,
            claimer: CLAIMER,
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function testMorphoClaimRewards() public {
        MorphoRewardPortfolio[] memory morphoRewardPortfolios = new MorphoRewardPortfolio[](2);
        morphoRewardPortfolios[0] = MorphoRewardPortfolio({
            assetSymbol: FIXTURE_REWARD_ASSET_SYMBOLS[0],
            claimable: FIXTURE_CLAIMABLES[0],
            distributor: FIXTURE_DISTRIBUTORS[0],
            proof: FIXTURE_PROOFS[0]
        });
        morphoRewardPortfolios[1] = MorphoRewardPortfolio({
            assetSymbol: FIXTURE_REWARD_ASSET_SYMBOLS[1],
            claimable: FIXTURE_CLAIMABLES[1],
            distributor: FIXTURE_DISTRIBUTORS[1],
            proof: FIXTURE_PROOFS[1]
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: morphoRewardPortfolios
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoClaimRewards(
            morphoClaimRewardsIntent_("USD"),
            chainAccountsFromChainPortfolios(chainPortfolios), // user has no assets
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            CodeJarHelper.getCodeAddress(type(MorphoRewardsActions).creationCode),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                MorphoRewardsActions.claimAll,
                (FIXTURE_DISTRIBUTORS, FIXTURE_ACCOUNTS, FIXTURE_REWARDS, FIXTURE_CLAIMABLES, FIXTURE_PROOFS)
            ),
            "calldata is MorphoRewardsActions.claimAll(fixtureDistributors, fixtureAccounts, fixtureRewards, fixtureClaimables, fixtureProofs);"
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
        assertEq(result.actions[0].actionType, "MORPHO_CLAIM_REWARDS", "action type is 'MORPHO_CLAIM_REWARDS'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");

        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoClaimRewardsActionContext({
                    amounts: FIXTURE_CLAIMABLES,
                    assetSymbols: FIXTURE_REWARD_ASSET_SYMBOLS,
                    chainId: 1,
                    prices: Arrays.uintArray(USDC_PRICE, WETH_PRICE),
                    tokens: FIXTURE_REWARDS
                })
            ),
            "action context encoded from MorphoClaimRewardsActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoClaimRewardsPayWithReward() public {
        MorphoRewardPortfolio[] memory morphoRewardPortfolios = new MorphoRewardPortfolio[](2);
        morphoRewardPortfolios[0] = MorphoRewardPortfolio({
            assetSymbol: FIXTURE_REWARD_ASSET_SYMBOLS[0],
            claimable: FIXTURE_CLAIMABLES[0],
            distributor: FIXTURE_DISTRIBUTORS[0],
            proof: FIXTURE_PROOFS[0]
        });
        morphoRewardPortfolios[1] = MorphoRewardPortfolio({
            assetSymbol: FIXTURE_REWARD_ASSET_SYMBOLS[1],
            claimable: FIXTURE_CLAIMABLES[1],
            distributor: FIXTURE_DISTRIBUTORS[1],
            proof: FIXTURE_PROOFS[1]
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_(),
            morphoRewardPortfolios: morphoRewardPortfolios
        });

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](3);
        networkOperationFees[0] = Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 1e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 1e8});
        networkOperationFees[2] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 7777, price: 1e8});

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoClaimRewards(
            morphoClaimRewardsIntent_("USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios), // user has no assets
            quote_(networkOperationFees)
        );

        address morphoRewardsActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoRewardsActions).creationCode);
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
        callContracts[0] = morphoRewardsActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(
            MorphoRewardsActions.claimAll,
            (FIXTURE_DISTRIBUTORS, FIXTURE_ACCOUNTS, FIXTURE_REWARDS, FIXTURE_CLAIMABLES, FIXTURE_PROOFS)
        );
        callDatas[1] = abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoRewardsActionsAddress, quotePayAddress], [MorphoRewardsActions.claimAll(fixtureDistributors, fixtureAccounts, fixtureRewards, fixtureClaimables, fixtureProofs), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 1e6, QUOTE_ID)]);"
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
                    actionTypes: Arrays.stringArray(Actions.ACTION_TYPE_MORPHO_CLAIM_REWARDS, Actions.ACTION_TYPE_QUOTE_PAY),
                    actionContexts: Arrays.bytesArray(
                        abi.encode(
                            Actions.MorphoClaimRewardsActionContext({
                                amounts: FIXTURE_CLAIMABLES,
                                assetSymbols: FIXTURE_REWARD_ASSET_SYMBOLS,
                                chainId: 1,
                                prices: Arrays.uintArray(USDC_PRICE, WETH_PRICE),
                                tokens: FIXTURE_REWARDS
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

    function testMorphoClaimRewardsMaxCostTooHigh() public {
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
        builder.morphoClaimRewards(
            morphoClaimRewardsIntent_("USDC"), chainAccountsList_(2e6), quote_(networkOperationFees)
        );
    }
}
