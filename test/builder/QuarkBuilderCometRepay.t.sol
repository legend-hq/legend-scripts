// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Arrays} from "test/builder/lib/Arrays.sol";
import {QuarkBuilderTest, Accounts, PaymentInfo, QuarkBuilder} from "test/builder/lib/QuarkBuilderTest.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {CometActionsBuilder} from "src/builder/actions/CometActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {CometRepayAndWithdrawMultipleAssets} from "src/DeFiScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {Paycall} from "src/Paycall.sol";
import {Strings} from "src/builder/Strings.sol";
import {WrapperActions} from "src/WrapperScripts.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderCometRepayTest is Test, QuarkBuilderTest {
    function repayIntent_(
        uint256 chainId,
        address comet,
        string memory assetSymbol,
        uint256 amount,
        string[] memory collateralAssetSymbols,
        uint256[] memory collateralAmounts
    ) internal pure returns (CometActionsBuilder.CometRepayIntent memory) {
        return CometActionsBuilder.CometRepayIntent({
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: BLOCK_TIMESTAMP,
            chainId: chainId,
            collateralAmounts: collateralAmounts,
            collateralAssetSymbols: collateralAssetSymbols,
            comet: comet,
            repayer: address(0xa11ce),
            preferAcross: false,
            paymentAssetSymbol: "USDC"
        });
    }

    function setRepayPaymentAsset_(
        string memory paymentAssetSymbol,
        CometActionsBuilder.CometRepayIntent memory repayIntent
    ) internal pure returns (CometActionsBuilder.CometRepayIntent memory) {
        repayIntent.paymentAssetSymbol = paymentAssetSymbol;
        return repayIntent;
    }

    function testCometRepayInvalidInput() public {
        uint256[] memory collateralAmounts = new uint256[](2);
        collateralAmounts[0] = 1e18;
        collateralAmounts[1] = 1e18;

        string[] memory collateralAssetSymbols = new string[](1);
        collateralAssetSymbols[0] = "LINK";

        QuarkBuilder builder = new QuarkBuilder();

        vm.expectRevert(QuarkBuilderBase.InvalidInput.selector);

        builder.cometRepay(
            repayIntent_(1, cometUsdc_(1), "USDC", 1e6, collateralAssetSymbols, collateralAmounts),
            chainAccountsList_(3e6),
            quote_()
        );
    }

    function testCometRepayFundsUnavailable() public {
        uint256[] memory collateralAmounts = new uint256[](0);
        string[] memory collateralAssetSymbols = new string[](0);

        QuarkBuilder builder = new QuarkBuilder();

        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 1e6, 0));
        builder.cometRepay(
            repayIntent_(1, cometUsdc_(1), "USDC", 1e6, collateralAssetSymbols, collateralAmounts), // attempting to repay 1 USDC
            chainAccountsList_(0e6), // but user has 0 USDC
            quote_()
        );
    }

    function testCometRepayNotEnoughPaymentToken() public {
        QuarkBuilder builder = new QuarkBuilder();

        uint256[] memory collateralAmounts = new uint256[](0);
        string[] memory collateralAssetSymbols = new string[](0);

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0.4e6, 0, 0, 1e18), // user does not have enough USDC
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        // Need 0.5e6 USDC to pay the quote but Alice only has 0.4e6 USDC
        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                QuarkBuilderBase.GenerateQuotePayStatus.ImpossibleToConstruct,
                "USDC",
                3e6
            )
        );
        builder.cometRepay(
            repayIntent_(1, cometWeth_(1), "WETH", 1e18, collateralAssetSymbols, collateralAmounts),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );
    }

    function testCometRepay() public {
        uint256[] memory collateralAmounts = new uint256[](1);
        collateralAmounts[0] = 1e18;

        string[] memory collateralAssetSymbols = new string[](1);
        collateralAssetSymbols[0] = "LINK";

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(2e6, 0, 0, 0), // has 2 USDC
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: bytes32(uint256(2)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            setRepayPaymentAsset_(
                "USD",
                repayIntent_(
                    1,
                    cometUsdc_(1),
                    "USDC",
                    1e6, // repaying 1 USDC
                    collateralAssetSymbols,
                    collateralAmounts // withdrawing 1 LINK
                )
            ),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                /* codeJar address */
                                address(CodeJarHelper.CODE_JAR_ADDRESS),
                                uint256(0),
                                /* script bytecode */
                                keccak256(type(CometRepayAndWithdrawMultipleAssets).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory collateralTokens = new address[](1);
        collateralTokens[0] = link_(1);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                CometRepayAndWithdrawMultipleAssets.run,
                (cometUsdc_(1), collateralTokens, collateralAmounts, usdc_(1), 1e6)
            ),
            "calldata is CometRepayAndWithdrawMultipleAssets.run(COMET_1_USDC, [LINK], [1e18], USDC, 1e6);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 1);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");

        uint256[] memory collateralTokenPrices = new uint256[](1);
        collateralTokenPrices[0] = LINK_PRICE;

        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    collateralAmounts: collateralAmounts,
                    collateralAssetSymbols: collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometUsdc_(1),
                    price: USDC_PRICE,
                    token: usdc_(1)
                })
            ),
            "action context encoded from RepayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometRepayWithAutoWrapper() public {
        uint256[] memory collateralAmounts = new uint256[](1);
        collateralAmounts[0] = 1e18;

        string[] memory collateralAssetSymbols = new string[](1);
        collateralAssetSymbols[0] = "LINK";

        address[] memory collateralTokens = new address[](1);
        collateralTokens[0] = link_(1);

        uint256[] memory collateralTokenPrices = new uint256[](1);
        collateralTokenPrices[0] = LINK_PRICE;

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "ETH", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 1e18, 0, 0), // has 1 ETH
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: bytes32(uint256(2)),
            assetSymbols: Arrays.stringArray("USDC", "ETH", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            setRepayPaymentAsset_(
                "USD",
                repayIntent_(
                    1,
                    cometWeth_(1),
                    "WETH",
                    1e18, // repaying 1 WETH
                    collateralAssetSymbols,
                    collateralAmounts // withdrawing 1 LINK
                )
            ),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address cometRepayAndWithdrawMultipleAssetsAddress =
            CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode);
        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = cometRepayAndWithdrawMultipleAssetsAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] =
            abi.encodeWithSelector(WrapperActions.wrapAllETH.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        callDatas[1] = abi.encodeCall(
            CometRepayAndWithdrawMultipleAssets.run,
            (cometWeth_(1), collateralTokens, collateralAmounts, weth_(1), 1e18)
        );

        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, cometRepayAndWithdrawMultipleAssetsAddress], [WrapperActions.wrapAllETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), CometRepayAndWithdrawMultipleAssets.run(COMET_1_WETH, collateralTokens, collateralAmounts, weth_(1), 1e18)"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(WrapperActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: 1e18,
                    assetSymbol: "WETH",
                    chainId: 1,
                    collateralAmounts: collateralAmounts,
                    collateralAssetSymbols: collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometWeth_(1),
                    price: WETH_PRICE,
                    token: weth_(1)
                })
            ),
            "action context encoded from RepayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    // pay for a transaction with funds currently supplied as collateral
    function testCometRepayPayFromWithdraw() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.5e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 0.1e8});

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 1e18),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: bytes32(uint256(2)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        CometActionsBuilder.CometRepayIntent memory repayIntent;
        // Local scope to avoid stack too deep
        {
            uint256[] memory collateralAmounts = new uint256[](1);
            collateralAmounts[0] = 1e6;

            string[] memory collateralAssetSymbols = new string[](1);
            collateralAssetSymbols[0] = "USDC";

            repayIntent = repayIntent_(
                1,
                cometWeth_(1),
                "WETH",
                1e18, // repaying 1 WETH
                collateralAssetSymbols,
                collateralAmounts // and withdrawing 1 USDC
            );
        }
        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            repayIntent,
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees) // user is paying with USDC that is currently supplied as collateral
        );

        address cometRepayAndWithdrawMultipleAssetsAddress =
            CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        address[] memory collateralTokens = new address[](1);
        collateralTokens[0] = usdc_(1);

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address[0] has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometRepayAndWithdrawMultipleAssetsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            CometRepayAndWithdrawMultipleAssets.run.selector,
            cometWeth_(1),
            collateralTokens,
            repayIntent.collateralAmounts,
            weth_(1),
            1e18
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.5e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometRepayAndWithdrawMultipleAssetsAddress, quotePayAddress], [CometRepayAndWithdrawMultipleAssets.run(cometWeth_(1), [USDC_1], [1e6], WETH_1, 1e18), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.5e6, QUOTE_ID)]);"
        );

        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");

        uint256[] memory collateralTokenPrices = new uint256[](1);
        collateralTokenPrices[0] = USDC_PRICE;

        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: 1e18,
                    assetSymbol: "WETH",
                    chainId: 1,
                    collateralAmounts: repayIntent.collateralAmounts,
                    collateralAssetSymbols: repayIntent.collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometWeth_(1),
                    price: WETH_PRICE,
                    token: weth_(1)
                })
            ),
            "action context encoded from RepayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometRepayWithBridge() public {
        QuarkBuilder builder = new QuarkBuilder();

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 0.2e8});

        string[] memory collateralAssetSymbols = new string[](1);
        collateralAssetSymbols[0] = "LINK";

        uint256[] memory collateralAmounts = new uint256[](1);
        collateralAmounts[0] = 1e18;

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(4e6, 0, 0, 0), // 4 USDC on mainnet
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(2)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0), // no assets on base
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            repayIntent_(
                8453,
                cometUsdc_(8453),
                "USDC", // repaying 2 USDC, bridged from mainnet to base
                2e6,
                collateralAssetSymbols,
                collateralAmounts
            ),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);
        address cometRepayAndWithdrawMultipleAssetsAddress =
            CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        // first operation
        assertEq(result.quarkOperations.length, 2, "two operations");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address[0] has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cctpBridgeActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            CCTPBridgeActions.bridgeUSDC.selector,
            address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155),
            2e6, // 2e6 repaid
            6,
            bytes32(uint256(uint160(0xa11ce))),
            usdc_(1)
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.3e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(0xBd3fa81B58Ba92a82136038B25aDec7066af3155, 2e6, 6, 0xa11ce, USDC_1), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.3e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CCTPBridgeActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(
            result.quarkOperations[1].scriptAddress,
            cometRepayAndWithdrawMultipleAssetsAddress,
            "script address[1] is correct"
        );

        address[] memory collateralTokens = new address[](1);
        collateralTokens[0] = link_(8453);

        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeWithSelector(
                CometRepayAndWithdrawMultipleAssets.run.selector,
                cometUsdc_(8453),
                collateralTokens,
                collateralAmounts,
                usdc_(8453),
                2e6
            ),
            "calldata is CometRepayAndWithdrawMultipleAssets.run(cometUsdc_(8453), [LINK_8453], [1e18], USDC_8453, 2e6);"
        );
        assertEq(result.quarkOperations[1].scriptSources.length, 1);
        assertEq(result.quarkOperations[1].scriptSources[0], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, chainPortfolios[1].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
        assertEq(result.actions.length, 2, "two actions");
        // first action
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    assetSymbol: "USDC",
                    inputAmount: 2e6,
                    outputAmount: 2e6,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP,
                    chainId: 1,
                    destinationChainId: 8453,
                    price: USDC_PRICE,
                    recipient: address(0xa11ce),
                    token: usdc_(1)
                })
            ),
            "action context encoded from BridgeActionContext"
        );
        // second action
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[1].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[1].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[1].nonceSecret, chainPortfolios[1].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");

        uint256[] memory collateralTokenPrices = new uint256[](1);
        collateralTokenPrices[0] = LINK_PRICE;

        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: 2e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    collateralAmounts: collateralAmounts,
                    collateralAssetSymbols: collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometUsdc_(8453),
                    price: USDC_PRICE,
                    token: usdc_(8453)
                })
            ),
            "action context encoded from RepayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometRepayMaxWithQuotePay() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        address[] memory collateralTokens = new address[](0);
        uint256[] memory collateralAmounts = new uint256[](0);
        string[] memory collateralAssetSymbols = new string[](0);

        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(1),
            baseSupplied: 0,
            baseBorrowed: 10e6, // currently borrowing 10 USDC
            collateralAssetSymbols: Arrays.stringArray("LINK"),
            collateralAssetBalances: Arrays.uintArray(0)
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(50e6, 0, 0, 0), // has 50 USDC
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            repayIntent_(
                1,
                cometUsdc_(1),
                "USDC",
                type(uint256).max, // repaying max (all 10 USDC)
                collateralAssetSymbols,
                collateralAmounts
            ),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        address cometRepayAndWithdrawMultipleAssetsAddress =
            CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometRepayAndWithdrawMultipleAssetsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            CometRepayAndWithdrawMultipleAssets.run.selector,
            cometUsdc_(1),
            collateralTokens,
            collateralAmounts,
            usdc_(1),
            type(uint256).max
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometRepayAndWithdrawMultipleAssetsAddress, quotePayAddress], [CometRepayAndWithdrawMultipleAssets.run(cometUsdc_(1), [], [], USDC_1, uint256.max), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );

        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");

        uint256[] memory collateralTokenPrices = new uint256[](0);

        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: type(uint256).max,
                    assetSymbol: "USDC",
                    chainId: 1,
                    collateralAmounts: collateralAmounts,
                    collateralAssetSymbols: collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometUsdc_(1),
                    price: USDC_PRICE,
                    token: usdc_(1)
                })
            ),
            "action context encoded from RepayActionContext"
        );
        assertEq(
            result.actions[0].quotePayActionContext,
            abi.encode(
                Actions.QuotePayActionContext({
                    amount: 0.1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    price: USDC_PRICE,
                    token: USDC_1,
                    payee: Actions.QUOTE_PAY_RECIPIENT,
                    quoteId: QUOTE_ID
                })
            ),
            "action context encoded from QuotePayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometRepayMaxWithBridge() public {
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});
        networkOperationFees[1] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 8453, price: 0.1e8});

        address[] memory collateralTokens = new address[](0);
        uint256[] memory collateralAmounts = new uint256[](0);
        string[] memory collateralAssetSymbols = new string[](0);

        CometPortfolio[] memory cometPortfolios = new CometPortfolio[](1);
        cometPortfolios[0] = CometPortfolio({
            comet: cometUsdc_(8453),
            baseSupplied: 0,
            baseBorrowed: 10e6, // currently borrowing 10 USDC on Base Comet
            collateralAssetSymbols: Arrays.stringArray("LINK"),
            collateralAssetBalances: Arrays.uintArray(0)
        });

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(50e6, 0, 0, 0), // has 50 USDC on mainnet
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xa11ce),
            nonceSecret: bytes32(uint256(12)),
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0), // has 0 USDC on base
            cometPortfolios: cometPortfolios,
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        // Alice needs to bridge ~10 USDC to chain 8453 to repay max, but will pay the quote for both chains on chain 1
        QuarkBuilder.BuilderResult memory result = builder.cometRepay(
            repayIntent_(
                8453,
                cometUsdc_(8453),
                "USDC",
                type(uint256).max, // repaying max (all 10 USDC)
                collateralAssetSymbols,
                collateralAmounts
            ),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);
        address cometRepayAndWithdrawMultipleAssetsAddress =
            CodeJarHelper.getCodeAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        // Check the quark operations
        // first operation
        assertEq(result.quarkOperations.length, 2, "two operations");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address[0] has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cctpBridgeActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            CCTPBridgeActions.bridgeUSDC.selector,
            address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155),
            10.01e6, // 10e6 repaid + .1% buffer
            6,
            bytes32(uint256(uint160(0xa11ce))),
            usdc_(1)
        );
        // Covers the quote for both chains
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.2e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(0xBd3fa81B58Ba92a82136038B25aDec7066af3155, 10.01e6, 6, 0xa11ce, USDC_1), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.2e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CCTPBridgeActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, chainPortfolios[0].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(
            result.quarkOperations[1].scriptAddress,
            cometRepayAndWithdrawMultipleAssetsAddress,
            "script address is repay action"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeWithSelector(
                CometRepayAndWithdrawMultipleAssets.run.selector,
                cometUsdc_(8453),
                collateralTokens,
                collateralAmounts,
                usdc_(8453),
                type(uint256).max
            ),
            "calldata is CometRepayAndWithdrawMultipleAssets.run(cometUsdc_(8453), [], [], USDC_8453, uint256.max);"
        );
        assertEq(result.quarkOperations[1].scriptSources.length, 1);
        assertEq(result.quarkOperations[1].scriptSources[0], type(CometRepayAndWithdrawMultipleAssets).creationCode);
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, chainPortfolios[1].nonceSecret, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // check the actions
        // first action
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, chainPortfolios[0].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    assetSymbol: "USDC",
                    inputAmount: 10.01e6,
                    outputAmount: 10.01e6,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP,
                    chainId: 1,
                    destinationChainId: 8453,
                    price: USDC_PRICE,
                    recipient: address(0xa11ce),
                    token: USDC_1
                })
            ),
            "action context encoded from BridgeActionContext"
        );

        // second action
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[1].actionType, "REPAY", "action type is 'REPAY'");
        assertEq(result.actions[1].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[1].nonceSecret, chainPortfolios[1].nonceSecret, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");

        uint256[] memory collateralTokenPrices = new uint256[](0);

        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.RepayActionContext({
                    amount: type(uint256).max,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    collateralAmounts: collateralAmounts,
                    collateralAssetSymbols: collateralAssetSymbols,
                    collateralTokenPrices: collateralTokenPrices,
                    collateralTokens: collateralTokens,
                    comet: cometUsdc_(8453),
                    price: USDC_PRICE,
                    token: usdc_(8453)
                })
            ),
            "action context encoded from RepayActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }
}
