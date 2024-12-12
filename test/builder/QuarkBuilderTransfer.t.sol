// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {QuarkBuilderTest} from "test/builder/lib/QuarkBuilderTest.sol";

import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {TransferActions} from "src/DeFiScripts.sol";
import {WrapperActions} from "src/WrapperScripts.sol";
import {TransferActionsBuilder} from "src/builder/actions/TransferActionsBuilder.sol";
import {Actions} from "src/builder/actions/Actions.sol";
import {Accounts} from "src/builder/Accounts.sol";
import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";
import {PaymentInfo} from "src/builder/PaymentInfo.sol";
import {QuarkBuilder} from "src/builder/QuarkBuilder.sol";
import {QuarkBuilderBase} from "src/builder/QuarkBuilderBase.sol";
import {QuotePay} from "src/QuotePay.sol";
import {Quotes} from "src/builder/Quotes.sol";

contract QuarkBuilderTransferTest is Test, QuarkBuilderTest {
    function transferUsdc_(uint256 chainId, uint256 amount, address recipient, uint256 blockTimestamp)
        internal
        pure
        returns (TransferActionsBuilder.TransferIntent memory)
    {
        return transferToken_("USDC", chainId, amount, recipient, blockTimestamp);
    }

    function transferUsdc_(uint256 chainId, uint256 amount, address sender, address recipient, uint256 blockTimestamp)
        internal
        pure
        returns (TransferActionsBuilder.TransferIntent memory)
    {
        return transferToken_("USDC", chainId, amount, sender, recipient, blockTimestamp);
    }

    function transferEth_(uint256 chainId, uint256 amount, address recipient, uint256 blockTimestamp)
        internal
        pure
        returns (TransferActionsBuilder.TransferIntent memory)
    {
        return transferToken_("ETH", chainId, amount, recipient, blockTimestamp);
    }

    function transferWeth_(uint256 chainId, uint256 amount, address recipient, uint256 blockTimestamp)
        internal
        pure
        returns (TransferActionsBuilder.TransferIntent memory)
    {
        return transferToken_("WETH", chainId, amount, recipient, blockTimestamp);
    }

    function transferToken_(
        string memory assetSymbol,
        uint256 chainId,
        uint256 amount,
        address recipient,
        uint256 blockTimestamp
    ) internal pure returns (TransferActionsBuilder.TransferIntent memory) {
        return transferToken_({
            chainId: chainId,
            sender: address(0xa11ce),
            recipient: recipient,
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: blockTimestamp
        });
    }

    function transferToken_(
        string memory assetSymbol,
        uint256 chainId,
        uint256 amount,
        address sender,
        address recipient,
        uint256 blockTimestamp
    ) internal pure returns (TransferActionsBuilder.TransferIntent memory) {
        return TransferActionsBuilder.TransferIntent({
            chainId: chainId,
            sender: sender,
            recipient: recipient,
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: blockTimestamp,
            preferAcross: false,
            paymentAssetSymbol: "USDC"
        });
    }

    function transferToken_(
        string memory assetSymbol,
        uint256 chainId,
        uint256 amount,
        address sender,
        address recipient,
        uint256 blockTimestamp,
        bool preferAcross,
        string memory paymentAssetSymbol
    ) internal pure returns (TransferActionsBuilder.TransferIntent memory) {
        return TransferActionsBuilder.TransferIntent({
            chainId: chainId,
            sender: sender,
            recipient: recipient,
            amount: amount,
            assetSymbol: assetSymbol,
            blockTimestamp: blockTimestamp,
            preferAcross: preferAcross,
            paymentAssetSymbol: paymentAssetSymbol
        });
    }

    function testTransferInsufficientFunds() public {
        TransferActionsBuilder.TransferIntent memory intent = transferUsdc_(1, 10e6, address(0xc0b), BLOCK_TIMESTAMP); // transfer 10 USDC on chain 1 to 0xc0b
        intent.paymentAssetSymbol = "USD";

        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 10e6, 0e6));
        builder.transfer(
            intent, // transfer 10 USDC on chain 1 to 0xc0b
            chainAccountsList_(0e6), // but we are holding 0 USDC in total across 1, 8453
            quote_()
        );
    }

    function testTransferMaxCostTooHigh() public {
        QuarkBuilder builder = new QuarkBuilder();
        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                QuarkBuilderBase.GenerateQuotePayStatus.ImpossibleToConstruct,
                "USDC",
                1_000e6
            )
        );
        builder.transfer(
            transferUsdc_(1, 1e6, address(0xc0b), BLOCK_TIMESTAMP), // transfer 1 USDC on chain 1 to 0xc0b
            chainAccountsList_(2e6), // holding 2 USDC in total across 1, 8453
            quote_(1, 1_000e8) // but costs $1,000
        );
    }

    function testTransferFundsOnUnbridgeableChains() public {
        TransferActionsBuilder.TransferIntent memory intent = transferUsdc_(7777, 2e6, address(0xc0b), BLOCK_TIMESTAMP); // transfer 2 USDC on chain 7777 to 0xc0b
        intent.paymentAssetSymbol = "USD";

        QuarkBuilder builder = new QuarkBuilder();
        // FundsUnavailable("USDC", 2e6, 0e6): Requested 2e6, Available 0e6
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 2e6, 0e6));
        builder.transfer(
            // there is no bridge to chain 7777, so we cannot get to our funds
            intent,
            chainAccountsList_(3e6), // holding 3 USDC in total across chains 1, 8453
            quote_()
        );
    }

    function testTransferFundsUnavailableErrorGivesSuggestionForAvailableFunds() public {
        QuarkBuilder builder = new QuarkBuilder();
        // The 100e6 is the suggested amount (total available funds) to transfer
        vm.expectRevert(
            abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 105e6, 100e6)
        );
        builder.transfer(
            transferUsdc_(1, 105e6, address(0xc0b), BLOCK_TIMESTAMP), // transfer 100 USDC on chain 1 to 0xc0b
            chainAccountsList_(200e6), // holding 200 USDC in total across 1, 8453
            quote_(1, 3e8)
        );
    }

    function testTransferUnableToConstructQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();
        // User has enough to transfer, but not enough for the QuotePay because no quote is given on chain 8453 and all
        // the funds are used on chain 1 for the transfer
        vm.expectRevert(
            abi.encodeWithSelector(
                QuarkBuilderBase.UnableToConstructActionIntent.selector,
                false,
                "",
                0,
                QuarkBuilderBase.GenerateQuotePayStatus.UnableToConstruct,
                "USDC",
                3e6
            )
        );
        builder.transfer(
            transferUsdc_(1, 100e6, address(0xc0b), BLOCK_TIMESTAMP), // transfer 100 USDC on chain 1 to 0xc0b
            chainAccountsList_(200e6), // holding 200 USDC in total across 1, 8453
            quote_(1, 3e8) // but costs $3
        );
    }

    function testSimpleLocalTransferSucceeds() public {
        TransferActionsBuilder.TransferIntent memory intent = transferUsdc_(1, 1e6, address(0xceecee), BLOCK_TIMESTAMP); // transfer 1 USDC on chain 1 to 0xceecee
        intent.paymentAssetSymbol = "USD";

        QuarkBuilder builder = new QuarkBuilder();
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            intent,
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
                                keccak256(type(TransferActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address is correct given the code jar address on mainnet"
        );
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeCall(TransferActions.transferERC20Token, (usdc_(1), address(0xceecee), 1e6)),
            "calldata is TransferActions.transferERC20Token(USDC_1, address(0xceecee), 1e6);"
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
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 1e6,
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testSimpleBridgeTransferSucceeds() public {
        QuarkBuilder builder = new QuarkBuilder();
        // Note: There are 3e6 USDC on each chain, so the Builder should attempt to bridge 2 USDC to chain 8453
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferToken_({
                assetSymbol: "USDC",
                chainId: 8453,
                amount: 5e6,
                sender: address(0xb0b),
                recipient: address(0xceecee),
                blockTimestamp: BLOCK_TIMESTAMP,
                preferAcross: false,
                paymentAssetSymbol: "USD"
            }), // transfer 5 USDC on chain 8453 to 0xceecee
            chainAccountsList_(6e6), // holding 6 USDC in total across chains 1, 8453
            quote_()
        );

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
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
            "script address for bridge action is correct given the code jar address"
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
                                keccak256(type(TransferActions).creationCode)
                            )
                        )
                    )
                )
            ),
            "script address for transfer is correct given the code jar address"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeCall(TransferActions.transferERC20Token, (usdc_(8453), address(0xceecee), 5e6)),
            "calldata is TransferActions.transferERC20Token(USDC_8453, address(0xceecee), 5e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
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
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[1].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 5e6,
                    price: USDC_PRICE,
                    token: USDC_8453,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    // DONE AND PASSES!
    function testSimpleBridgeTransferWithQuotePaySucceeds() public {
        Quotes.NetworkOperationFee memory networkOperationFeeBase =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 0.1e8});

        Quotes.NetworkOperationFee memory networkOperationFeeMainnet =
            Quotes.NetworkOperationFee({chainId: 1, opType: Quotes.OP_TYPE_BASELINE, price: 0.5e8});

        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] = networkOperationFeeBase;
        networkOperationFees[1] = networkOperationFeeMainnet;

        QuarkBuilder builder = new QuarkBuilder();
        // Note: There are 3e6 USDC on each chain, so the Builder should attempt to bridge 2 USDC to chain 8453.
        //       It would then pay for the quotes for chains 1 and 8453 (total of 6e5) on chain 1.
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferToken_({
                assetSymbol: "USDC",
                chainId: 8453,
                amount: 5e6,
                sender: address(0xb0b),
                recipient: address(0xceecee),
                blockTimestamp: BLOCK_TIMESTAMP
            }), // transfer 5 USDC on chain 8453 to 0xceecee
            chainAccountsList_(6e6), // holding 6 USDC in total across chains 1, 8453
            quote_(networkOperationFees)
        );
        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
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
            2e6,
            6,
            bytes32(uint256(uint160(0xb0b))),
            usdc_(1)
        );
        callDatas[1] = abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 6e5, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 2e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1)), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 6e5, QUOTE_ID)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        assertEq(
            result.quarkOperations[1].scriptAddress,
            transferActionsAddress,
            "script address[1] is the transfer actions address"
        );
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, usdc_(8453), address(0xceecee), 5e6),
            "calldata is TransferActions.transferERC20Token(USDC_8453, address(0xceecee), 5e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
        assertEq(result.actions.length, 2, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
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
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[1].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 5e6,
                    price: USDC_PRICE,
                    token: USDC_8453,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );
        assertEq(
            result.actions[0].quotePayActionContext,
            abi.encode(
                Actions.QuotePayActionContext({
                    amount: 0.6e6,
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

    function testSimpleLocalTransferMax() public {
        QuarkBuilder builder = new QuarkBuilder();
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList_(1, address(0xa11ce), uint256(10e6)),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferUsdc_(1, type(uint256).max, address(0xceecee), BLOCK_TIMESTAMP), // transfer max
            chainAccountsList,
            quote_(1, 0.1e8)
        );

        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address[0] has been wrapped with multicall address"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = transferActionsAddress;
        callContracts[1] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            // Transfer max should be able to adjust to the right max amount to transfer all funds: 10e6 (holding) - 1e5 (max cost) = 9.9e6
            TransferActions.transferERC20Token.selector,
            usdc_(1),
            address(0xceecee),
            9.9e6
        );
        callDatas[1] = abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 1e5, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([transferActionsAddress, quotePayAddress], [TransferActions.transferERC20Token(USDC_1, address(0xceecee), 9.9e6), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 6e5, QUOTE_ID)]);"
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
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_CALL", "payment method is 'QUOTE_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 9.9e6,
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testSimpleBridgeTransferMax() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee memory networkOperationFeeBase =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 0.1e8});

        Quotes.NetworkOperationFee memory networkOperationFeeMainnet =
            Quotes.NetworkOperationFee({chainId: 1, opType: Quotes.OP_TYPE_BASELINE, price: 0.5e8});
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](2);
        networkOperationFees[0] = networkOperationFeeBase;
        networkOperationFees[1] = networkOperationFeeMainnet;
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](2);
        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList_(1, address(0xa11ce), 8e6),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });
        chainAccountsList[1] = Accounts.ChainAccounts({
            chainId: 8453,
            quarkSecrets: quarkSecrets_(address(0xb0b), bytes32(uint256(2))),
            assetPositionsList: assetPositionsList_(8453, address(0xb0b), 4e6),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        // Will transfer all available balance (balance - costs = 8e6 + 4e6 - 0.5e6 - 0.1e6 = 11.4e6)
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferToken_({
                assetSymbol: "USDC",
                chainId: 8453,
                amount: type(uint256).max,
                sender: address(0xb0b),
                recipient: address(0xceecee),
                blockTimestamp: BLOCK_TIMESTAMP
            }), // transfer max USDC on chain 8453 to 0xceecee
            chainAccountsList, // holding 8 USDC on chains 1, and 4 USDC on 8453
            quote_(networkOperationFees)
        );

        address cctpBridgeActionsAddress = CodeJarHelper.getCodeAddress(type(CCTPBridgeActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
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
            7.4e6, // 8e6 - 0.6e6 (quote costs) (holdings on mainnet)
            6,
            bytes32(uint256(uint160(0xb0b))),
            usdc_(1)
        );
        // TODO: should be 0xb0b
        callDatas[1] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.6e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([cctpBridgeActionsAddress, quotePayAddress], [CCTPBridgeActions.bridgeUSDC(address(0xBd3fa81B58Ba92a82136038B25aDec7066af3155), 7.4e6, 6, bytes32(uint256(uint160(0xb0b))), usdc_(1), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.6e6, QUOTE_ID)]);"
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

        assertEq(result.quarkOperations[1].scriptAddress, transferActionsAddress, "script address[1] is correct");
        assertEq(
            result.quarkOperations[1].scriptCalldata,
            // Transfermax should be able to adjust to the right max amount to transfer all funds: 4e6 (holdings on base) - 0.1e6 (max cost on base) + 7.5e6 (brdiged from mainnet)= 3.9e6 + 7.5e6 = 11.4e6
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, usdc_(8453), address(0xceecee), 11.4e6),
            "calldata is TransferActions.transferERC20Token(USDC_8453, address(0xceecee), 11.4e6);"
        );
        assertEq(
            result.quarkOperations[1].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[1].nonce, BOB_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[1].isReplayable, false, "isReplayable is false");

        // Check the actions
        assertEq(result.actions.length, 2, "one action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "BRIDGE", "action type is 'BRIDGE'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_CALL", "payment method is 'QUOTE_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.BridgeActionContext({
                    price: USDC_PRICE,
                    token: USDC_1,
                    assetSymbol: "USDC",
                    inputAmount: 7.4e6,
                    outputAmount: 7.4e6,
                    chainId: 1,
                    recipient: address(0xb0b),
                    destinationChainId: 8453,
                    bridgeType: Actions.BRIDGE_TYPE_CCTP
                })
            ),
            "action context encoded from BridgeActionContext"
        );
        assertEq(result.actions[1].chainId, 8453, "operation is on chainid 8453");
        assertEq(result.actions[1].quarkAccount, address(0xb0b), "0xb0b sends the funds");
        assertEq(result.actions[1].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[1].paymentMethod, "QUOTE_CALL", "payment method is 'QUOTE_CALL'");
        assertEq(result.actions[1].nonceSecret, BOB_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[1].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[1].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 11.4e6,
                    price: USDC_PRICE,
                    token: USDC_8453,
                    assetSymbol: "USDC",
                    chainId: 8453,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testBridgeTransferMaxFundUnavailableError() public {
        QuarkBuilder builder = new QuarkBuilder();
        Quotes.NetworkOperationFee memory networkOperationFeeRandom =
            Quotes.NetworkOperationFee({chainId: 7777, opType: Quotes.OP_TYPE_BASELINE, price: 0.1e8});
        Quotes.NetworkOperationFee memory networkOperationFeeBase =
            Quotes.NetworkOperationFee({chainId: 8453, opType: Quotes.OP_TYPE_BASELINE, price: 0.1e8});
        Quotes.NetworkOperationFee memory networkOperationFeeMainnet =
            Quotes.NetworkOperationFee({chainId: 1, opType: Quotes.OP_TYPE_BASELINE, price: 0.5e8});
        Quotes.NetworkOperationFee[] memory networkOperationFees = new Quotes.NetworkOperationFee[](3);
        networkOperationFees[0] = networkOperationFeeBase;
        networkOperationFees[1] = networkOperationFeeMainnet;
        networkOperationFees[2] = networkOperationFeeRandom;
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](3);
        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList_(1, address(0xa11ce), 8e6),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });
        chainAccountsList[1] = Accounts.ChainAccounts({
            chainId: 8453,
            quarkSecrets: quarkSecrets_(address(0xb0b), bytes32(uint256(2))),
            assetPositionsList: assetPositionsList_(8453, address(0xb0b), 4e6),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });
        chainAccountsList[2] = Accounts.ChainAccounts({
            chainId: 7777,
            quarkSecrets: quarkSecrets_(address(0xc0b), bytes32(uint256(2))),
            assetPositionsList: assetPositionsList_(7777, address(0xc0b), 5e6),
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        // User has total holding of 17 USDC, but only 12 USDC is available for transfer/bridge to 8453, and missing 5 USDC stuck in random L2 so will revert with FundsUnavailable error
        // Actual number re-adjusted with max cost gas fee so that the:
        // Request amount = 17 USDC - 0.5 USDC (max cost on main) - 0.1 USDC (max cost on Base) - 0.1 USDC (max cost on RandomL2) = 16.3 USDC
        // Actual amount = 8 USDC (available on main) + 4 USDC (available on Base) = 12 USDC
        // Missing amount = 16.3 USDC - 12 USDC = 14.3 USDC
        vm.expectRevert(
            abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 16.3e6, 12e6)
        );
        builder.transfer(
            transferUsdc_(8453, type(uint256).max, address(0xb0b), address(0xceecee), BLOCK_TIMESTAMP), // transfer max USDC on chain 8453 to 0xceecee
            chainAccountsList, // holding 8 USDC on chains 1, 4 USDC on 8453, 5 USDC on 7777
            quote_(networkOperationFees)
        );
    }

    function testTransferIgnoresChainIfMaxCostIsNotSpecified() public {
        QuarkBuilder builder = new QuarkBuilder();
        // Note: There are 3e6 USDC on each chain, so the Builder should attempt to bridge 2 USDC to chain 8453.
        // However, max cost is not specified for chain 1, so the Builder will ignore the chain and revert because
        // there will be insufficient funds for the transfer.

        // The `FundsAvailable` error tells us that 5 USDC was asked to be transferred, but only 3 USDC was available.
        vm.expectRevert(abi.encodeWithSelector(QuarkBuilderBase.BadInputInsufficientFunds.selector, "USDC", 5e6, 3e6));
        builder.transfer(
            transferUsdc_(8453, 5e6, address(0xceecee), BLOCK_TIMESTAMP), // transfer 5 USDC on chain 8453 to 0xceecee
            chainAccountsList_(6e6), // holding 6 USDC in total across chains 1, 8453
            quote_(8453, 0.1e8)
        );
    }

    function testTransferWithAutoUnwrapping() public {
        QuarkBuilder builder = new QuarkBuilder();
        address account = address(0xa11ce);
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        // Holding 10 USDC, 1ETH, and 1WETH on chain 1
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](3);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(1),
            symbol: "USDC",
            decimals: 6,
            usdPrice: 1_0000_0000,
            accountBalances: accountBalances_(account, 10e6)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(1),
            symbol: "WETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });

        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList,
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        TransferActionsBuilder.TransferIntent memory intent =
            transferEth_(1, 1.5e18, address(0xceecee), BLOCK_TIMESTAMP);
        intent.paymentAssetSymbol = "USD";

        // Transfer 1.5 ETH to 0xceecee on chain 1
        // Should unwrap up to 1.5 WETH to ETH to cover the amount (0.5 WETH will actually be unwrapped)
        QuarkBuilder.BuilderResult memory result = builder.transfer(intent, chainAccountsList, quote_());

        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = transferActionsAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] = abi.encodeWithSelector(
            WrapperActions.unwrapWETHUpTo.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1.5e18
        );
        callDatas[1] = abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(0xceecee), 1.5e18);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, transferActionsAddress], [WrapperActions.unwrapWETHUpTo(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1.5e18), TransferActions.transferNativeToken(address(0xceecee), 1.5e18)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "1 action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 1.5e18,
                    price: 3500e8,
                    token: eth_(),
                    assetSymbol: "ETH",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testTransferWithAutoUnwrappingWithQuotePay() public {
        QuarkBuilder builder = new QuarkBuilder();
        address account = address(0xa11ce);
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        // Holding 10 USDC, 1ETH, and 1WETH on chain 1
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](3);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(1),
            symbol: "USDC",
            decimals: 6,
            usdPrice: 1_0000_0000,
            accountBalances: accountBalances_(account, 10e6)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(1),
            symbol: "WETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });

        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList,
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        // Transfer 1.5 ETH to 0xceecee on chain 1
        // Should unwrap up to 1.5 WETH to ETH to cover the amount (0.5 WETH will actually be unwrapped)
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferEth_(1, 1.5e18, address(0xceecee), BLOCK_TIMESTAMP), chainAccountsList, quote_(1, 0.1e8)
        );

        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](3);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = transferActionsAddress;
        callContracts[2] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](3);
        callDatas[0] = abi.encodeWithSelector(
            WrapperActions.unwrapWETHUpTo.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1.5e18
        );
        callDatas[1] = abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(0xceecee), 1.5e18);
        callDatas[2] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, transferActionsAddress, quotePayAddress], [WrapperActions.unwrapWETHUpTo(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 1.5e18), TransferActions.transferNativeToken(address(0xceecee), 1.5e18), QuotePay.pay(Actions.QUOTE_PAY_RECIPIENT), USDC_1, 0.1e6, QUOTE_ID)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "1 action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "PAY_CALL", "payment method is 'PAY_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 1.5e18,
                    price: 3500e8,
                    token: eth_(),
                    assetSymbol: "ETH",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
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

    function testTransferMaxWithAutoUnwrapping() public {
        QuarkBuilder builder = new QuarkBuilder();
        address account = address(0xa11ce);
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        // Holding 10 USDC, 1ETH, and 1WETH on chain 1
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](3);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(1),
            symbol: "USDC",
            decimals: 6,
            usdPrice: 1_0000_0000,
            accountBalances: accountBalances_(account, 10e6)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(1),
            symbol: "WETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });

        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList,
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        // Transfer max (2) ETH to 0xceecee on chain 1
        // Should unwrap up to 2 WETH to ETH to cover the amount (1 WETH will actually be unwrapped)
        QuarkBuilder.BuilderResult memory result = builder.transfer(
            transferEth_(1, type(uint256).max, address(0xceecee), BLOCK_TIMESTAMP), chainAccountsList, quote_(1, 0.1e8)
        );

        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address quotePayAddress = CodeJarHelper.getCodeAddress(type(QuotePay).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USDC", "usdc currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](3);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = transferActionsAddress;
        callContracts[2] = quotePayAddress;
        bytes[] memory callDatas = new bytes[](3);
        callDatas[0] = abi.encodeWithSelector(
            WrapperActions.unwrapWETHUpTo.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 2e18
        );
        callDatas[1] = abi.encodeWithSelector(TransferActions.transferNativeToken.selector, address(0xceecee), 2e18);
        callDatas[2] =
            abi.encodeWithSelector(QuotePay.pay.selector, Actions.QUOTE_PAY_RECIPIENT, USDC_1, 0.1e6, QUOTE_ID);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, transferActionsAddress], [WrapperActions.unwrapWETHUpTo(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, 2e18), TransferActions.transferNativeToken(address(0xceecee), 2e18)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "1 action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "QUOTE_CALL", "payment method is 'QUOTE_CALL'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 2e18,
                    price: 3500e8,
                    token: eth_(),
                    assetSymbol: "ETH",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }

    function testTransferWithAutoWrapping() public {
        QuarkBuilder builder = new QuarkBuilder();
        address account = address(0xa11ce);
        Accounts.ChainAccounts[] memory chainAccountsList = new Accounts.ChainAccounts[](1);
        // Holding 10 USDC, 1ETH, and 1WETH on chain 1
        Accounts.AssetPositions[] memory assetPositionsList = new Accounts.AssetPositions[](3);
        assetPositionsList[0] = Accounts.AssetPositions({
            asset: usdc_(1),
            symbol: "USDC",
            decimals: 6,
            usdPrice: 1_0000_0000,
            accountBalances: accountBalances_(account, 10e6)
        });
        assetPositionsList[1] = Accounts.AssetPositions({
            asset: eth_(),
            symbol: "ETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });
        assetPositionsList[2] = Accounts.AssetPositions({
            asset: weth_(1),
            symbol: "WETH",
            decimals: 18,
            usdPrice: 3500_0000_0000,
            accountBalances: accountBalances_(account, 1e18)
        });

        chainAccountsList[0] = Accounts.ChainAccounts({
            chainId: 1,
            quarkSecrets: quarkSecrets_(address(0xa11ce), bytes32(uint256(12))),
            assetPositionsList: assetPositionsList,
            cometPositions: emptyCometPositions_(),
            morphoPositions: emptyMorphoPositions_(),
            morphoVaultPositions: emptyMorphoVaultPositions_()
        });

        TransferActionsBuilder.TransferIntent memory intent =
            transferWeth_(1, 1.75e18, address(0xceecee), BLOCK_TIMESTAMP);
        intent.paymentAssetSymbol = "USD";

        // Transfer 1.5ETH to 0xceecee on chain 1
        // Should able to have auto unwrapping 0.5 WETH to ETH to cover the amount
        QuarkBuilder.BuilderResult memory result = builder.transfer(intent, chainAccountsList, quote_());

        address transferActionsAddress = CodeJarHelper.getCodeAddress(type(TransferActions).creationCode);
        address wrapperActionsAddress = CodeJarHelper.getCodeAddress(type(WrapperActions).creationCode);
        address multicallAddress = CodeJarHelper.getCodeAddress(type(Multicall).creationCode);

        assertEq(result.paymentCurrency, "USD", "usd currency");

        // Check the quark operations
        assertEq(result.quarkOperations.length, 1, "one merged operation");
        assertEq(
            result.quarkOperations[0].scriptAddress,
            multicallAddress,
            "script address is correct given the code jar address on mainnet"
        );
        address[] memory callContracts = new address[](2);
        callContracts[0] = wrapperActionsAddress;
        callContracts[1] = transferActionsAddress;
        bytes[] memory callDatas = new bytes[](2);
        callDatas[0] =
            abi.encodeWithSelector(WrapperActions.wrapAllETH.selector, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        callDatas[1] =
            abi.encodeWithSelector(TransferActions.transferERC20Token.selector, WETH_1, address(0xceecee), 1.75e18);
        assertEq(
            result.quarkOperations[0].scriptCalldata,
            abi.encodeWithSelector(Multicall.run.selector, callContracts, callDatas),
            "calldata is Multicall.run([wrapperActionsAddress, transferActionsAddress], [WrapperActions.wrapAllETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2), TransferActions.transferERC20Token(WETH_1, address(0xceecee), 1.75e18)]);"
        );
        assertEq(
            result.quarkOperations[0].expiry, BLOCK_TIMESTAMP + 7 days, "expiry is current blockTimestamp + 7 days"
        );
        assertEq(result.quarkOperations[0].nonce, ALICE_DEFAULT_SECRET, "unexpected nonce");
        assertEq(result.quarkOperations[0].isReplayable, false, "isReplayable is false");

        // check the actions
        assertEq(result.actions.length, 1, "1 action");
        assertEq(result.actions[0].chainId, 1, "operation is on chainid 1");
        assertEq(result.actions[0].quarkAccount, address(0xa11ce), "0xa11ce sends the funds");
        assertEq(result.actions[0].actionType, "TRANSFER", "action type is 'TRANSFER'");
        assertEq(result.actions[0].paymentMethod, "OFFCHAIN", "payment method is 'OFFCHAIN'");
        assertEq(result.actions[0].nonceSecret, ALICE_DEFAULT_SECRET, "unexpected nonce secret");
        assertEq(result.actions[0].totalPlays, 1, "total plays is 1");
        assertEq(
            result.actions[0].actionContext,
            abi.encode(
                Actions.TransferActionContext({
                    amount: 1.75e18,
                    price: 3500e8,
                    token: weth_(1),
                    assetSymbol: "WETH",
                    chainId: 1,
                    recipient: address(0xceecee)
                })
            ),
            "action context encoded from TransferActionContext"
        );

        // TODO: Check the contents of the EIP712 data
        assertNotEq(result.eip712Data.digest, hex"", "non-empty digest");
        assertNotEq(result.eip712Data.domainSeparator, hex"", "non-empty domain separator");
        assertNotEq(result.eip712Data.hashStruct, hex"", "non-empty hashStruct");
    }
}
