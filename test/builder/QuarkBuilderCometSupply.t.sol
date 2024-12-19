// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {QuarkBuilderTest, Accounts, PaymentInfo, QuarkBuilder} from "test/builder/lib/QuarkBuilderTest.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {CometActionsBuilder} from "src/builder/actions/CometActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {CometSupplyActions, TransferActions} from "src/DeFiScripts.sol";
import {Paycall} from "src/Paycall.sol";
import {Multicall} from "src/Multicall.sol";
import {Quotecall} from "src/Quotecall.sol";
import {WrapperActions} from "src/WrapperScripts.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

import {Arrays} from "test/builder/lib/Arrays.sol";

contract QuarkBuilderCometSupplyTest is Test, QuarkBuilderTest {
    address constant COMET = address(0xc3d688B66703497DAA19211EEdff47f25384cdc3);
    address constant COMET_ETH = address(0xA17581A9E3356d9A858b789D68B4d866e593aE94);

    function cometWethSupply_(uint256 chainId, uint256 amount)
        internal
        pure
        returns (CometActionsBuilder.CometSupplyIntent memory)
    {
        return cometWethSupply_(chainId, amount);
    }

    function cometWethSupply_(uint256 chainId, uint256 amount, string memory paymentAssetSymbol)
        internal
        pure
        returns (CometActionsBuilder.CometSupplyIntent memory)
    {
        return CometActionsBuilder.CometSupplyIntent({
            amount: amount,
            assetSymbol: "WETH",
            blockTimestamp: BLOCK_TIMESTAMP,
            chainId: chainId,
            comet: COMET_ETH,
            sender: address(0xa11ce),
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function cometSupply_(uint256 chainId, uint256 amount)
        internal
        pure
        returns (CometActionsBuilder.CometSupplyIntent memory)
    {
        return cometSupply_(chainId, amount, address(0xa11ce), "USDC");
    }

    function cometSupply_(uint256 chainId, uint256 amount, string memory paymentAssetSymbol)
        internal
        pure
        returns (CometActionsBuilder.CometSupplyIntent memory)
    {
        return cometSupply_(chainId, amount, address(0xa11ce), paymentAssetSymbol);
    }

    function cometSupply_(uint256 chainId, uint256 amount, address sender, string memory paymentAssetSymbol)
        internal
        pure
        returns (CometActionsBuilder.CometSupplyIntent memory)
    {
        return CometActionsBuilder.CometSupplyIntent({
            amount: amount,
            assetSymbol: "USDC",
            blockTimestamp: BLOCK_TIMESTAMP,
            chainId: chainId,
            comet: COMET,
            sender: sender,
            preferAcross: false,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function testCometSupplyInsufficientFunds() public {
        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 2e6, 0e6));
        builder.cometSupply(
            cometSupply_(1, 2e6, "USD"),
            chainAccountsList_(0e6), // but we are holding 0 USDC in total across 1, 8453
            quote_()
        );
    }

    function testCometSupplyMaxCostTooHigh() public {
        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                "USDC",
                1_000.03001e6
            )
        );

        builder.cometSupply(
            cometSupply_(1, 1e6),
            chainAccountsList_(2e6), // holding 2 USDC in total across 1, 8453
            quote_({chainIds: Arrays.uintArray(1, 8453, 7777), prices: Arrays.uintArray(1_000e8, 0.03e8, 0.03e8)}) // but costs $1,000
        );
    }

    function testCometSupplyFundsUnavailable() public {
        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 2e6, 0));
        builder.cometSupply(
            // there is no bridge to chain 7777, so we cannot get to our funds
            cometSupply_(7777, 2e6, "USD"), // transfer 2 USDC on chain 7777 to 0xc0b
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
            quote_()
        );
    }

    function testSimpleCometSupply() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            cometSupply_(1, 1e6, "USD"),
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
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
                                keccak256(type(CometSupplyActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(1), 1e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc, 2);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testSimpleCometSupplyMax() public {
        QuarkBuilder builder = new QuarkBuilder();
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList_(1, address(0xa11ce), uint256(3e6)),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            cometSupply_(1, type(uint256).max, "USD"),
            chainAccountsList, // holding 3 USDC in total across chains 1, 8453
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
                                keccak256(type(CometSupplyActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(1), 3e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc, 3);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 3e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testSimpleCometSupplyWithAutoWrapper() public {
        QuarkBuilder builder = new QuarkBuilder();
        address account = address(0xa11ce);
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        // Custom setup to hold ETH (for auto wrap later when supply WETH to comet)
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](3);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: WETH_PRICE,
            accountBalances: accountBalances_(account, 1e18)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: weth_(1),
            symbol: "WETH",
            decimals: 18,
            usdPrice: WETH_PRICE,
            accountBalances: accountBalances_(account, 0)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: usdc_(1),
            symbol: "USDC",
            decimals: 6,
            usdPrice: USDC_PRICE,
            accountBalances: accountBalances_(account, 0e6)
        });
        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList,
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        QuarkBuilder.BuilderResult memory result =
            builder.cometSupply(cometWethSupply_(1, 1e18, "USD"), chainAccountsList, quote_());

        assertEq(result.paymentCurrency, "USD", "usd currency");

        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address cometSupplyActionsAddress = CodeJarHelper.getCodeAddress(type(CometSupplyActions).creationCode);
        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = cometSupplyActionsAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] =
            abi.encodeWithSelector(WrapperActions.wrapAllETH.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        callDatas[1] = abi.encodeCall(CometSupplyActions.supply, (COMET_ETH, weth_(1), 1e18));
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, cometSupplyActionsAddress], [WrapperActions.wrapAllETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), CometSupplyActions.supply(COMET_ETH, weth_(1), 1e18)"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 3 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 1e18,
                    assetSymbol: "WETH",
                    chainId: 1,
                    comet: COMET_ETH,
                    price: WETH_PRICE,
                    token: WETH_1
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometSupplyWithQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            cometSupply_(1, 1e6),
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
            quote_(1, 0.1e8)
        );

        address cometSupplyActionsAddress = CodeJarHelper.getCodeAddress(type(CometSupplyActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address[0] has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = cometSupplyActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(CometSupplyActions.supply.selector, COMET, usdc_(1), 1e6);
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cometSupplyActionsAddress, quotePayAddress], [CometSupplyActions.supply(COMET, USDC, 1e6), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CometSupplyActions).creationCode);
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
        assertEq(result.actions[0].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 1e6,
                    assetSymbol: "USDC",
                    chainId: 1,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_1
                })
            ),
            "action context encoded from SupplyActionContext"
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

    function testCometSupplyWithBridge() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            // We need to set Bob as the sender because only he has an account on chain 8453
            cometSupply_(8453, 5e6, address(0xb0b), "USD"),
            chainAccountsList_(6e6), // holding 6 USDC in total across chains 1, 8453
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        // first operation
        assertEq(result.quarkOperations.length, 2, "two operations");
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
                                keccak256(type(CCTPBridgeActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                CCTPBridgeActions.bridgeUSDC,
                (
                    address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155),
                    2e6,
                    6,
                    bytes32(uint256(uint160(0xb0b))),
                    usdc_(1)
                )
            ),
            "calldata is CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 2e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1)));"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(
            result.quarkOperations[1].scriptAddress,
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
                                keccak256(type(CometSupplyActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address for transfer is correct given the code jar address"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(8453), 5e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc, 5e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        // TODO: might need to adjust intent to supply with Bob
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // check the actions
        // first action
        assertEq(result.actions.length, 2, "two actions");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    inputAmount: 2e6,
                    outputAmount: 2e6,
                    chainId: 1,
                    recipient: address(0xb0b),
                    destinationChainId: 8453,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP
                })
            ),
            "action context encoded from BridgeActionContext"
        );

        // second action
        assertEq(result.actions[1].chainId, 8453, "second action is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[1].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 5e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_8453
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometSupplyMaxWithBridge() public {
        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            // We need to set Bob as the sender because only he has an account on chain 8453
            cometSupply_(8453, type(uint256).max, address(0xb0b), "USD"),
            chainAccountsList_(6e6), // holding 3 USDC in total across chains 1, 8453
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        // first operation
        assertEq(result.quarkOperations.length, 2, "two operations");
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
                                keccak256(type(CCTPBridgeActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(
                CCTPBridgeActions.bridgeUSDC,
                (
                    address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155),
                    3e6,
                    6,
                    bytes32(uint256(uint160(0xb0b))),
                    usdc_(1)
                )
            ),
            "calldata is CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 3e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1)));"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(
            result.quarkOperations[1].scriptAddress,
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
                                keccak256(type(CometSupplyActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address for transfer is correct given the code jar address"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(8453), 6e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc, 5e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // check the actions
        // first action
        assertEq(result.actions.length, 2, "two actions");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    inputAmount: 3e6,
                    outputAmount: 3e6,
                    chainId: 1,
                    recipient: address(0xb0b),
                    destinationChainId: 8453,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP
                })
            ),
            "action context encoded from BridgeActionContext"
        );

        // second action
        assertEq(result.actions[1].chainId, 8453, "second action is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[1].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 6e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_8453
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometSupplyMaxWithBridgeAndQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();

        // Note: There are 3e6 USDC on each chain, so the Builder should attempt to bridge 2 USDC to chain 8453
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            // We need to set Bob as the sender because only he has an account on chain 8453
            cometSupply_(8453, type(uint256).max, address(0xb0b), "USDC"),
            chainAccountsList_(6e6), // holding 3 USDC in total across chains 1, 8453
            quote_({chainIds: Arrays.uintArray(1, 8453, 7777), prices: Arrays.uintArray(0.5e8, 0.1e8, 0.1e8)})
        );

        address cometSupplyActionsAddress = CodeJarHelper.getCodeAddress(type(CometSupplyActions).creationCode);
        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 2, "two operations");
        // first operation
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
            2.4e6, // 3e6 - (0.5e6 + 0.1e6)
            6,
            bytes32(uint256(uint160(0xb0b))),
            usdc_(1)
        );
        // TODO: Should be 0xbob once multi account is supported
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.6e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 2.4e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.6e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CCTPBridgeActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(result.quarkOperations[1].scriptAddress, cometSupplyActionsAddress, "script address[1] is correct");
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(8453), 5.4e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc(8453), 5.4e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
        assertEq(result.actions.length, 2, "two actions");
        // first action
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    inputAmount: 2.4e6,
                    outputAmount: 2.4e6,
                    chainId: 1,
                    recipient: address(0xb0b),
                    destinationChainId: 8453,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP
                })
            ),
            "action context encoded from BridgeActionContext"
        );
        // second action
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[1].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 5.4e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_8453
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testCometSupplyWithBridgeAndQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee memory networkOperationFeeBase =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 0.1e8});
        Quotes.NetworkOperationFee memory networkOperationFeeMainnet =
            Quotes.NetworkOperationFee({chainId: 1, opType: Quotes.OP_TYPE_BASELINE, price: 0.5e8});
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] = networkOperationFeeBase;
        networkOperationFees[1] = networkOperationFeeMainnet;

        // Note: There are 3e6 USDC on each chain, so the Builder should attempt to bridge 2 USDC to chain 8453
        QuarkBuilder.BuilderResult memory result = builder.cometSupply(
            // We need to set Bob as the sender because only he has an account on chain 8453
            cometSupply_(8453, 5e6, address(0xb0b), "USDC"),
            chainAccountsList_(6e6), // holding 3 USDC in total across chains 1, 8453
            quote_(networkOperationFees)
        );

        address cometSupplyActionsAddress = CodeJarHelper.getCodeAddress(type(CometSupplyActions).creationCode);
        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 2, "two operations");
        // first operation
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
            2e6,
            6,
            bytes32(uint256(uint160(0xb0b))),
            usdc_(1)
        );
        // TODO: Should be 0xbob once multi account is supported
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.6e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 2e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.6e6, QUOTE_ID)]);"
        );
        assertEq(result.quarkOperations[0].scriptSources.length, 3);
        assertEq(result.quarkOperations[0].scriptSources[0], type(CCTPBridgeActions).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[1], type(QuotePay).creationCode);
        assertEq(result.quarkOperations[0].scriptSources[2], type(Multicall).creationCode);
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // second operation
        assertEq(result.quarkOperations[1].scriptAddress, cometSupplyActionsAddress, "script address[1] is correct");
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(CometSupplyActions.supply, (COMET, usdc_(8453), 5e6)),
            "calldata is CometSupplyActions.supply(COMET, usdc(8453), 5e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
        assertEq(result.actions.length, 2, "two actions");
        // first action
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    inputAmount: 2e6,
                    outputAmount: 2e6,
                    chainId: 1,
                    recipient: address(0xb0b),
                    destinationChainId: 8453,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP
                })
            ),
            "action context encoded from BridgeActionContext"
        );
        // second action
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "SUPPLY", "action type is 'SUPPLY'");
        assertEq(result.actions[1].paymentMethod, "QUOTE_PAY", "payment method is 'QUOTE_PAY'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.SupplyActionContext({
                    amount: 5e6,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    comet: COMET,
                    price: USDC_PRICE,
                    token: USDC_8453
                })
            ),
            "action context encoded from SupplyActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }
}
