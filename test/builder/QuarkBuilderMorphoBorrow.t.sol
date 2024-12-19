// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {Arrays} from "test/builder/lib/Arrays.sol";
import {QuarkBuilderTest, Accounts, PaymentInfo, QuarkBuilder} from "test/builder/lib/QuarkBuilderTest.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {MorphoActionsBuilder} from "src/builder/actions/MorphoActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {MorphoActions} from "src/MorphoScripts.sol";
import {Strings} from "src/builder/Strings.sol";
import {Multicall} from "src/Multicall.sol";
import {WrapperActions} from "src/WrapperScripts.sol";
import {MorphoInfo} from "src/builder/MorphoInfo.sol";
import {TokenWrapper} from "src/builder/TokenWrapper.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderMorphoBorrowTest is Test, QuarkBuilderTest {
    function borrowIntent_(
        uint256 chainId,
        string memory assetSymbol,
        uint256 amount,
        string memory collateralAssetSymbol,
        uint256 collateralAmount,
        string memory paymentAssetSymbol
    ) internal pure returns (MorphoActionsBuilder.MorphoBorrowIntent memory) {
        return borrowIntent_({
            chainId: chainId,
            assetSymbol: assetSymbol,
            amount: amount,
            collateralAssetSymbol: collateralAssetSymbol,
            collateralAmount: collateralAmount,
            borrower: address(0xa11ce),
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function borrowIntent_(
        uint256 chainId,
        string memory assetSymbol,
        uint256 amount,
        string memory collateralAssetSymbol,
        uint256 collateralAmount,
        address borrower,
        string memory paymentAssetSymbol
    ) internal pure returns (MorphoActionsBuilder.MorphoBorrowIntent memory) {
        return MorphoActionsBuilder.MorphoBorrowIntent({
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: BLOCK_TIMESTAMP,
            borrower: borrower,
            chainId: chainId,
            collateralAmount: collateralAmount,
            collateralAssetSymbol: collateralAssetSymbol,
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function testMorphoBorrowInvalidMarketParams() public {
        QuarkBuilder builder = new QuarkBuilder();
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "WBTC", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 1e8, 1e18),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: BOB_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        // Pair not exist in known Morpho markets
        vm.expectRevert(MorphoInfo.MorphoMarketNotFound.selector);
        builder.morphoBorrow(
            borrowIntent_(1, "USDC", 1e6, "WETH", 1e18, "USD"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );
    }

    function testMorphoBorrowFundsUnavailable() public {
        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "WBTC", 1e8, 0));
        builder.morphoBorrow(
            borrowIntent_(1, "USDC", 1e6, "WBTC", 1e8, "USD"),
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
            quote_()
        );
    }

    function testMorphoBorrowSuccess() public {
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "WBTC", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 1e8, 0), // user has 1 WBTC
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: BOB_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoBorrow(
            borrowIntent_(1, "USDC", 1e6, "WBTC", 1e8, "USD"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );
        address MorphoActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode);
        // Check the quark operations
        assertEq(result.paymentCurrency, "USD", "usd currency");
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            MorphoActionsAddress,
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                MorphoActions.supplyCollateralAndBorrow,
                (MorphoInfo.getMorphoAddress(1), MorphoInfo.getMarketParams(1, "WBTC", "USDC"), 1e8, 1e6)
            ),
            "calldata is MorphoActions.supplyCollateralAndBorrow(MorphoInfo.getMorphoAddress(1), MorphoInfo.getMarketParams(1, WBTC, USDC), 1e8, 1e6, address(0xal1ce), address(0xal1ce));"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 1);
        assertEq(result.quarkOperations[0].scriptSources[0], type(MorphoActions).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "MORPHO_BORROW", "action type is 'MORPHO_BORROW'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoBorrowActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    collateralAmount: 1e8,
                    collateralTokenPrice: WBTC_PRICE,
                    collateralToken: wbtc_(1),
                    collateralAssetSymbol: "WBTC",
                    price: USDC_PRICE,
                    token: usdc_(1),
                    morpho: MorphoInfo.getMorphoAddress(1),
                    morphoMarketId: MorphoInfo.marketId(MorphoInfo.getMarketParams(1, "WBTC", "USDC"))
                })
            ),
            "action context encoded from MorphoBorrowActionContext"
        );

        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoBorrowWithAutoWrapper() public {
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xb0b),
            nonceSecret: BOB_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "ETH", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "ETH", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 10e18, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoBorrow(
            borrowIntent_(8453, "USDC", 1e6, "WETH", 1e18, "USD"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address MorphoActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode);
        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = MorphoActionsAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            WrapperActions.wrapAllETH.selector, TokenWrapper.getKnownWrapperTokenPair(8453, "WETH").wrapper
        );
        callDatas[1] = abi.encodeCall(
            MorphoActions.supplyCollateralAndBorrow,
            (MorphoInfo.getMorphoAddress(8453), MorphoInfo.getMarketParams(8453, "WETH", "USDC"), 1e18, 1e6)
        );

        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, MorphoActionsAddress], [WrapperActions.wrapAllETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), MorphoActions.supplyCollateralAndBorrow(MorphoInfo.getMorphoAddress(8453), MorphoInfo.getMarketParams(8453, WETH, USDC), 1e18, 1e6, address(0xa11ce), address(0xa11ce))"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(WrapperActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(MorphoActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "MORPHO_BORROW", "action type is 'MORPHO_BORROW'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoBorrowActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    collateralAmount: 1e18,
                    collateralTokenPrice: WETH_PRICE,
                    collateralToken: weth_(8453),
                    collateralAssetSymbol: "WETH",
                    price: USDC_PRICE,
                    token: usdc_(8453),
                    morpho: MorphoInfo.getMorphoAddress(8453),
                    morphoMarketId: MorphoInfo.marketId(MorphoInfo.getMarketParams(8453, "WETH", "USDC"))
                })
            ),
            "action context encoded from MorphoBorrowActionContext"
        );

        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoBorrowWithQuotePay() public {
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "WBTC", "WETH"),
            assetBalances: Arrays.uintArray(1e6, 0, 1e8, 0), // user has 1 WBTC and 1USDC for payment
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: BOB_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoBorrow(
            borrowIntent_(1, "USDC", 1e6, "WBTC", 1e8, "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        address morphoActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode);
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
        callContracts[0] = morphoActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(
            MorphoActions.supplyCollateralAndBorrow,
            (MorphoInfo.getMorphoAddress(1), MorphoInfo.getMarketParams(1, "WBTC", "USDC"), 1e8, 1e6)
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoActionsAddress, quotePayAddress], [MorphoActions.supplyCollateralAndBorrow(MorphoInfo.getMorphoAddress(1), MorphoInfo.getMarketParams(1, WBTC, USDC), 1e8, 1e6, address(0xa11ce), address(0xa11ce)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(MorphoActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "MORPHO_BORROW", "action type is 'MORPHO_BORROW'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoBorrowActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    collateralAmount: 1e8,
                    collateralTokenPrice: WBTC_PRICE,
                    collateralToken: wbtc_(1),
                    collateralAssetSymbol: "WBTC",
                    price: USDC_PRICE,
                    token: usdc_(1),
                    morpho: MorphoInfo.getMorphoAddress(1),
                    morphoMarketId: MorphoInfo.marketId(MorphoInfo.getMarketParams(1, "WBTC", "USDC"))
                })
            ),
            "action context encoded from MorphoBorrowActionContext"
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

        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoBorrowPayFromBorrow() public {
        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](2);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "WBTC", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 1e8, 0), // user has 1 WBTC but with 0 USDC
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });
        chainPortfolios[1] = ChainPortfolio({
            chainId: 8453,
            account: address(0xb0b),
            nonceSecret: BOB_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "LINK", "WETH"),
            assetBalances: Arrays.uintArray(0, 0, 0, 0),
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.1e8});

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.morphoBorrow(
            borrowIntent_(1, "USDC", 1e6, "WBTC", 1e8, "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );

        address morphoActionsAddress = CodeJarHelper.getCodeAddress(type(MorphoActions).creationCode);
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
        callContracts[0] = morphoActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeCall(
            MorphoActions.supplyCollateralAndBorrow,
            (MorphoInfo.getMorphoAddress(1), MorphoInfo.getMarketParams(1, "WBTC", "USDC"), 1e8, 1e6)
        );
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([morphoActionsAddress, quotePayAddress], [MorphoActions.supplyCollateralAndBorrow(MorphoInfo.getMorphoAddress(), MorphoInfo.getMarketParams(1, WBTC, USDC), 1e8, 1e6, address(0xa11ce), address(0xa11ce)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(MorphoActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "MORPHO_BORROW", "action type is 'MORPHO_MORPHO_BORROW'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.MorphoBorrowActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    collateralAmount: 1e8,
                    collateralTokenPrice: WBTC_PRICE,
                    collateralToken: wbtc_(1),
                    collateralAssetSymbol: "WBTC",
                    price: USDC_PRICE,
                    token: usdc_(1),
                    morpho: MorphoInfo.getMorphoAddress(1),
                    morphoMarketId: MorphoInfo.marketId(MorphoInfo.getMarketParams(1, "WBTC", "USDC"))
                })
            ),
            "action context encoded from MorphoBorrowActionContext"
        );

        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testMorphoBorrowMaxCostTooHigh() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](1);
        networkOperationFees[0] =
            Quotes.NetworkOperationFee({opType: Quotes.OP_TYPE_BASELINE, chainId: 1, price: 0.5e8}); // action costs .5 USDC

        ChainPortfolio[] memory chainPortfolios = new ChainPortfolio[](1);
        chainPortfolios[0] = ChainPortfolio({
            chainId: 1,
            account: address(0xa11ce),
            nonceSecret: ALICE_DEFAULT_SECRET,
            assetSymbols: Arrays.stringArray("USDC", "USDT", "WBTC", "WETH"),
            assetBalances: Arrays.uintArray(0.4e6, 0, 2e8, 1e18), // user does not have enough USDC
            cometPortfolios: emptyCometPortfolios_(),
            morphoPortfolios: emptyMorphoPortfolios_(),
            morphoVaultPortfolios: emptyMorphoVaultPortfolios_()
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                "USDC",
                0.5e6
            )
        );
        builder.morphoBorrow(
            borrowIntent_(1, "WETH", 1e18, "WBTC", 0, "USDC"),
            chainAccountsFromChainPortfolios(chainPortfolios),
            quote_(networkOperationFees)
        );
    }
}
