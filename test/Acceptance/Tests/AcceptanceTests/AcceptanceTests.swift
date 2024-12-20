@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation
import SwiftKeccak
import Testing

@testable import Acceptance

let allTests: [AcceptanceTest] = [
    .init(
        name: "Alice transfers 10 USDC to Bob on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.10, .usdc), payee: .stax, quote: .basic),
                ])))
    ),
    .init(
        name: "Alice transfers 10 USDC to Bob on Arbitrum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .arbitrum),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.04, .usdc), payee: .stax, quote: .basic),
                ])))
    ),
    .init(
        name: "Alice attempts transfers MAX USDC to Bob on Arbitrum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                Token.usdc.symbol,
                0,
                "UNABLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.04, .usdc).amount
            )
        )
    ),
    .init(
        name: "Alice attempts to transfers perceived MAX USDC to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum),
        expect: .revert(
            .unableToConstructActionIntent(
                true,
                Token.usdc.symbol,
                TokenAmount.amt(1.5, .usdc).amount,
                "UNABLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.06, .usdc).amount
            )
        )
    ),
    .init(
        name: "Alice transfers MAX USDC (with uint256.max) to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .max(.usdc), on: .arbitrum),
        expect: .success(
            .multi([
                .bridge(
                    bridge: "Across",
                    srcNetwork: .base,
                    destinationNetwork: .arbitrum,
                    tokenAmount: .amt(50, .usdc)
                ),
                .multicall([
                    .transferErc20(tokenAmount: .amt(98.44, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),
    .init(
        name: "Alice bridges sumSrcBalance via Across when inputAmount > sumSrcBalance",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(99, .usdc), on: .arbitrum),
        expect: .revert(
            .unableToConstructActionIntent(
                true,
                Token.usdc.symbol,
                TokenAmount.amt(1.5, .usdc).amount,
                "UNABLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.06, .usdc).amount
            )
        )
    ),
    .init(
        name:
            "Alice attempts to transfers 75 USDC to Bob on Arbitrum via Bridge but doesn't have all the quotes",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [
                        .arbitrum: 0.04
                    ]
                )
            ),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(75, .usdc), on: .arbitrum),
        expect: .revert(
            .maxCostMissingForChain(BigUInt(Network.base.chainId))
        )
    ),
    .init(
        name: "Alice transfers USDC to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(98, .usdc), on: .arbitrum),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .base,
                        destinationNetwork: .arbitrum,
                        tokenAmount: .amt(49.48, .usdc)
                    ),
                    .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                ]),
                .transferErc20(tokenAmount: .amt(98, .usdc), recipient: .bob),
            ])
        )
    ),
    .init(
        name: "Alice supplies 0.5 WETH to cUSDCv3 on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(1.0, .weth), .ethereum),
            .quote(.basic),
        ],
        when: .payWith(
            currency: .weth,
            .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(0.5, .weth), on: .ethereum)
        ),
        expect: .success(
            .single(
                .multicall([
                    .supplyToComet(
                        tokenAmount: .amt(0.5, .weth), market: .cusdcv3, network: .ethereum),
                    .quotePay(
                        payment: .amt(0.000025000000000062, .weth), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    // @skip: Alice cannot supply ETH to comet because Actions.cometSupply doesn't wrap ETH
    .init(
        name: "Alice supplies 0.5 ETH to cUSDCv3 on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(1.0, .eth), .ethereum),
            .quote(.basic),
        ],
        when: .payWith(
            currency: .eth,
            .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(0.5, .eth), on: .ethereum)
        ),
        expect: .success(
            .single(
                .multicall([
                    .supplyToComet(
                        tokenAmount: .amt(0.5, .eth), market: .cusdcv3, network: .ethereum),
                    .quotePay(payment: .amt(0.000025, .eth), payee: .stax, quote: .basic),
                ])
            )
        ),
        skip: true
    ),
    .init(
        name:
            "WIP: Alice repays 75 USDC of a 100 USDC borrow against 0.3 WETH on cUSDCv3 on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(0.5, .weth), .ethereum),
            .cometSupply(.alice, .amt(0.3, .weth), .cusdcv3, .ethereum),
            .cometBorrow(.alice, .amt(100, .usdc), .cusdcv3, .ethereum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(50, .usdc), on: .arbitrum),
        // FIXME: this should not revert! borrowed funds should be added to token balance
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(50, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),
    .init(
        name:
            "Alice supplies, but does not allow enough for quote pay (testCometSupplyInsufficientFunds)",
        given: [.quote(.basic)],
        when: .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(2, .usdc), on: .ethereum),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(2, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),
    .init(
        name: "Alice supplies, but cannot cover operation cost (testCometSupplyMaxCostTooHigh)",
        given: [
            .tokenBalance(.alice, .amt(1.0, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1.0, .usdc), .base),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: [Token.usdc: 1.0],
                    fees: [
                        Network.ethereum: 1000,
                        Network.base: 0.03,
                    ]
                )
            ),
        ],
        when: .payWith(
            currency: .usdc,
            .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum)
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(1000.03001, .usdc).amount
            )
        )
    ),
    .init(
        name: "Alice supplies to Comet (testSimpleCometSupply)",
        given: [
            .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1.5, .usdc), .base),
            .quote(.basic),
        ],
        when: .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .supplyToComet(
                        tokenAmount: .amt(1, .usdc), market: .cusdcv3, network: .ethereum),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    .init(
        name: "Alice supplies max to Comet (testSimpleCometSupplyMax)",
        given: [
            .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .cometSupply(from: .alice, market: .cusdcv3, amount: .max(.usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .supplyToComet(
                        tokenAmount: .amt(2.9, .usdc), market: .cusdcv3, network: .ethereum),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )

        )
    ),
    .init(
        name: "Alice supplies to Comet, paying via Quote Pay (testCometSupplyWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1.5, .usdc), .base),
            .quote(.basic),
        ],
        when: .cometSupply(from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .supplyToComet(
                        tokenAmount: .amt(1, .usdc), market: .cusdcv3, network: .ethereum),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )

        )
    ),
    .init(
        name: "testCometRepay",
        given: [
            .tokenBalance(.alice, .amt(2, .usdc), .ethereum),
            .cometSupply(.alice, .amt(1, .link), .cusdcv3, .ethereum),
            .quote(.basic)
        ],
        when: .cometRepay(
            from: .alice,
            market: .cusdcv3,
            repayAmount: .amt(1, .usdc),
            collateralAmounts: [.amt(1, .link)],
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .repayAndWithdrawMultipleAssetsFromComet(
                        repayAmount: .amt(1, .usdc),
                        collateralAmounts: [.amt(1, .link)],
                        market: .cusdcv3,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    .init(
        name: "testCometRepayFundsUnavailable",
        given: [.quote(.basic)],
        when: .cometRepay(
            from: .alice,
            market: .cusdcv3,
            repayAmount: .amt(1, .usdc),
            collateralAmounts: [],
            on: .ethereum
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(1, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),
    .init(
        name: "testCometRepayNotEnoughPaymentToken",
        given: [
            .tokenBalance(.alice, .amt(0.4, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1, .weth), .ethereum),
            .quote(
                .custom(
                    quoteId: Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 0.5]
                )
            )
        ],
        when: .cometRepay(
            from: .alice,
            market: .cwethv3,
            repayAmount: .amt(1, .weth),
            collateralAmounts: [],
            on: .ethereum
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.5, .usdc).amount
            )
        )
    ),
    // no wrapper actions yet
    // .init(
    //     name: "testCometRepayWithAutoWrapper",
    //     given: [
    //         .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
    //         .tokenBalance(.alice, .amt(1, .eth), .ethereum),
    //         .quote(.basic)
    //     ],
    //     when: .cometRepay(
    //         from: .alice,
    //         market: .cwethv3,
    //         repayAmount: .amt(1, .weth),
    //         collateralAmounts: [.amt(1, .link)],
    //         on: .ethereum
    //     ),
    //     expect: .success(
    //         .single(
    //             .multicall([
    //                 .repayAndWithdrawMultipleAssetsFromComet(
    //                     repayAmount: .amt(1, .usdc),
    //                     collateralAmounts: [.amt(1, .link)],
    //                     market: .cusdcv3,
    //                     network: .ethereum
    //                 ),
    //                 .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
    //             ])
    //         )
    //     ),
    //     only: true
    // )
    .init(
        name: "testCometRepayPayFromWithdraw",
        given: [
            .tokenBalance(.alice, .amt(1, .weth), .ethereum),
            .quote(.basic)
        ],
        when: .cometRepay(
            from: .alice,
            market: .cwethv3,
            repayAmount: .amt(1, .weth),
            collateralAmounts: [.amt(1, .usdc)],
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .repayAndWithdrawMultipleAssetsFromComet(
                        repayAmount: .amt(1, .weth),
                        collateralAmounts: [.amt(1, .usdc)],
                        market: .cwethv3,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )

    ),
    // Panic!
    // .init(
    //     name: "testCometRepayWithBridge",
    //     given: [
    //         .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
    //         .quote(.basic),
    //         .acrossQuote(.amt(1, .usdc), 0.01),
    //     ],
    //     when: .cometRepay(
    //         from: .alice,
    //         market: .cusdcv3,
    //         repayAmount: .amt(2, .usdc),
    //         collateralAmounts: [.amt(1, .link)],
    //         on: .base
    //     ),
    //     expect: .success(
    //         .single(
    //             .multicall([
    //                 .repayAndWithdrawMultipleAssetsFromComet(
    //                     repayAmount: .amt(1, .weth),
    //                     collateralAmounts: [.amt(1, .usdc)],
    //                     market: .cwethv3,
    //                     network: .ethereum
    //                 ),
    //                 .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
    //             ])
    //         )
    //     ),
    //     only: true
    // ),
    // return uint256max + 1 in QuarkBuilder result
    // .init(
    //     name: "testCometRepayMaxWithQuotePay",
    //     given: [
    //         .tokenBalance(.alice, .amt(50, .usdc), .ethereum),
    //         .cometBorrow(.alice, .amt(10, .usdc), .cusdcv3, .ethereum),
    //         .quote(.basic)
    //     ],
    //     when: .cometRepay(
    //         from: .alice,
    //         market: .cusdcv3,
    //         repayAmount: .max(.usdc),
    //         collateralAmounts: [],
    //         on: .ethereum
    //     ),
    //     expect: .success(
    //         .single(
    //             .multicall([
    //                 .repayAndWithdrawMultipleAssetsFromComet(
    //                     repayAmount: .max(.usdc),
    //                     collateralAmounts: [],
    //                     market: .cusdcv3,
    //                     network: .ethereum
    //                 ),
    //                 .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
    //             ])
    //         )
    //     ),
    //     only: true
    // ),
    // testCometRepayMaxWithBridge
    // noSuchFFI
    // .init(
    //     name: "testCometRepayMaxWithBridge",
    //     given: [
    //         .tokenBalance(.alice, .amt(50, .usdc), .ethereum),
    //         .cometBorrow(.alice, .amt(10, .usdc), .cusdcv3, .base),
    //         .quote(.basic)
    //     ],
    //     when: .cometRepay(
    //         from: .alice,
    //         market: .cusdcv3,
    //         repayAmount: .max(.usdc),
    //         collateralAmounts: [],
    //         on: .base
    //     ),
    //     expect: .success(
    //         .single(
    //             .multicall([
    //                 .repayAndWithdrawMultipleAssetsFromComet(
    //                     repayAmount: .max(.usdc),
    //                     collateralAmounts: [],
    //                     market: .cusdcv3,
    //                     network: .base
    //                 ),
    //                 .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
    //             ])
    //         )
    //     )
    // ),
]

let tests = allTests.filter { !$0.skip }
let filteredTests = tests.contains { $0.only } ? tests.filter { $0.only } : tests

enum Call: CustomStringConvertible, Equatable {
    case bridge(
        bridge: String, srcNetwork: Network, destinationNetwork: Network, tokenAmount: TokenAmount)
    case transferErc20(tokenAmount: TokenAmount, recipient: Account)
    case supplyToComet(tokenAmount: TokenAmount, market: Comet, network: Network)
    case repayAndWithdrawMultipleAssetsFromComet(
        repayAmount: TokenAmount,
        collateralAmounts: [TokenAmount],
        market: Comet,
        network: Network
    )
    case quotePay(payment: TokenAmount, payee: Account, quote: Quote)
    case multicall(_ calls: [Call])
    case unknownFunctionCall(String, String, ABI.Value)
    case unknownScriptCall(EthAddress, Hex)

    static let allFunctions: [(String, Hex, [ABI.Function])] = [
        ("AcrossActions", AcrossActions.creationCode, AcrossActions.functions),
        ("TransferActions", TransferActions.creationCode, TransferActions.functions),
        ("Multicall", Multicall.creationCode, Multicall.functions),
        ("QuotePay", QuotePay.creationCode, QuotePay.functions),
    ]

    static func tryDecodeCall(scriptAddress: EthAddress, calldata: Hex, network: Network) -> Call {
        if scriptAddress == getScriptAddress(AcrossActions.creationCode) {
            if let (
                _,
                _,
                _,
                inputToken,
                _,
                inputAmount,
                _,
                destinationChainId,
                _,
                _,
                _,
                _,
                _,
                _
            ) = try? AcrossActions.depositV3Decode(input: calldata) {
                return .bridge(
                    bridge: "Across",
                    srcNetwork: network,
                    destinationNetwork: Network.fromChainId(BigInt(destinationChainId)),
                    tokenAmount: Token.getTokenAmount(
                        amount: inputAmount,
                        network: network,
                        address: inputToken
                    )
                )
            }
        }

        if scriptAddress == getScriptAddress(TransferActions.creationCode) {
            if let (token, recipient, amount) = try? TransferActions.transferERC20TokenDecode(
                input: calldata)
            {
                return .transferErc20(
                    tokenAmount: Token.getTokenAmount(
                        amount: amount, network: network, address: token),
                    recipient: Account.from(address: recipient))
            }
        }

        if scriptAddress == getScriptAddress(QuotePay.creationCode) {
            if let (payee, paymentToken, quotedAmount, quoteId) = try? QuotePay.payDecode(
                input: calldata)
            {
                return .quotePay(
                    payment: Token.getTokenAmount(
                        amount: quotedAmount, network: network, address: paymentToken),
                    payee: Account.from(address: payee),
                    quote: Quote.findQuote(quoteId: quoteId, prices: [:], fees: [:]))
            }
        }

        if scriptAddress == getScriptAddress(Multicall.creationCode) {
            if let (callContracts, callDatas) = try? Multicall.runDecode(input: calldata) {
                let calls = zip(callContracts, callDatas).map {
                    Call.tryDecodeCall(scriptAddress: $0, calldata: $1, network: network)
                }
                return .multicall(calls)
            }
        }

        if scriptAddress == getScriptAddress(CometSupplyActions.creationCode) {
            if let (comet, asset, amount) = try? CometSupplyActions.supplyDecode(input: calldata) {
                return .supplyToComet(
                    tokenAmount: Token.getTokenAmount(
                        amount: amount, network: network, address: asset),
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            } else if let (comet, to, asset, amount) = try? CometSupplyActions.supplyToDecode(
                input: calldata)
            {
                print("supplyTo(\(comet) to: \(to) \(asset) \(amount))")
            } else if let (comet, from, to, asset, amount) =
                try? CometSupplyActions.supplyFromDecode(input: calldata)
            {
                print("supplyFrom(\(comet) from: \(from) to: \(to) \(asset) \(amount))")
            } else if let (comet, assets, amounts) =
                try? CometSupplyActions.supplyMultipleAssetsDecode(input: calldata)
            {
                print("supplyMultipleAssets(\(comet) \(assets) \(amounts))")
            }
        }

        if scriptAddress == getScriptAddress(CometRepayAndWithdrawMultipleAssets.creationCode) {
            if let (comet, assets, amounts, baseAsset, repayAmount) = try? CometRepayAndWithdrawMultipleAssets.runDecode(input: calldata) {

                let collateralAmounts = zip(amounts, assets).map {
                    Token.getTokenAmount(
                        amount: $0,
                        network: network,
                        address: $1
                    )
                }

                return repayAndWithdrawMultipleAssetsFromComet(
                    repayAmount: Token.getTokenAmount(amount: repayAmount, network: network, address: baseAsset),
                    collateralAmounts: collateralAmounts,
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            }
        }

        for (name, creationCode, functions) in Call.allFunctions {
            if scriptAddress == getScriptAddress(creationCode) {
                for function in functions {
                    if let value = try? function.decodeInput(input: calldata) {
                        return .unknownFunctionCall(name, function.name, value)
                    }
                }
            }
        }
        return .unknownScriptCall(scriptAddress, calldata)
    }

    var description: String {
        switch self {
        case let .bridge(bridge, chainId, destinationChainId, tokenAmount):
            return
                "bridge(\(bridge), \(tokenAmount.amount) \(tokenAmount.token.symbol) from \(chainId.description) to \(destinationChainId.description))"
        case let .transferErc20(tokenAmount, recipient):
            return
                "transferErc20(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(recipient.description))"
        case let .quotePay(payment, payee, quoteId):
            return
                "quotePay(\(payment.amount) \(payment.token.symbol) to \(payee.description), quoteId: \(quoteId))"
        case let .supplyToComet(tokenAmount, market, network):
            return
                "supplyToComet(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(market.description) on \(network.description))"
        case let .repayAndWithdrawMultipleAssetsFromComet(
            repayAmount,
            collateralAmounts,
            market,
            network
        ):
            let withdrawString = collateralAmounts.map {collateralAmount in
                "\(collateralAmount.amount) \(collateralAmount.token.symbol)"
            }.joined(separator: ",")
            return "repayAndWithdrawMultipleAssetsFromComet(repay \(repayAmount.amount) \(repayAmount.token.symbol), withdraw [\(withdrawString)]  to \(market.description) on \(network.description))"
        case let .multicall(calls):
            return "multicall(\(calls.map { $0.description }.joined(separator: ", ")))"
        case let .unknownFunctionCall(name, function, value):
            return "unknownFunctionCall(\(name), \(function), \(value))"
        case let .unknownScriptCall(scriptSource, calldata):
            return "unknownScriptCall(\(scriptSource.description), \(calldata.description))"
        }
    }

    var descriptionExt: String {
        switch self {
        case let .multicall(calls):
            return
                "multicall:\n\(calls.map { "\n\t\t- \($0.descriptionExt)" }.joined(separator: "\n"))\n"
        default:
            return description
        }
    }
}

extension Array where Element == Call {
    var descriptionExt: String {
        if count == 1 {
            return self[0].descriptionExt
        } else {
            return "multicall:\n\(map { "\n\t\t- \($0.descriptionExt)" }.joined(separator: "\n"))\n"
        }
    }
}

func getScriptAddress(_ creationCode: Hex) -> EthAddress {
    // Create2 address calculation according to EIP-1014
    // address = keccak256(0xff ++ deployingAddress ++ salt ++ keccak256(bytecode))[12:]
    let codeJarAddress = EthAddress("0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8")

    // Pack the data according to create2 spec:
    // 1. 0xff - prevents collision with create
    // 2. deploying contract address
    // 3. salt (32 bytes of 0 in this case)
    // 4. keccak256 hash of initialization code
    var packed = Data()
    packed.append(Data([0xFF]))  // prefix byte
    packed.append(codeJarAddress.data)  // deploying address
    packed.append(Data(repeating: 0, count: 32))  // salt
    packed.append(SwiftKeccak.keccak256(creationCode.data))  // hash of init code

    // Take keccak256 hash and extract last 20 bytes for address
    let hash = SwiftKeccak.keccak256(packed)
    return EthAddress(Hex(hash.subdata(in: 12..<32)))!
}

enum Account: Hashable, Equatable {
    case alice
    case bob
    case stax
    case unknownAccount(EthAddress)

    static let knownCases: [Account] = [.alice, .bob, .stax]

    var description: String {
        switch self {
        case .alice:
            return "Alice"
        case .bob:
            return "Bob"
        case .stax:
            return "stax"
        case let .unknownAccount(address):
            return "UnknownAccount(\(address.description))"
        }
    }

    var address: EthAddress {
        switch self {
        case .alice:
            return EthAddress("0x00000000000000000000000000000000000A1BC5")
        case .bob:
            return EthAddress("0x00000000000000000000000000000000000B0B0B")
        case .stax:
            return EthAddress("0x7ea8d6119596016935543d90Ee8f5126285060A1")
        case let .unknownAccount(address):
            return address
        }
    }

    static func from(address: EthAddress) -> Account {
        for knownCase in Account.knownCases {
            if address == knownCase.address {
                return knownCase
            }
        }
        return .unknownAccount(address)
    }
}

enum Comet: Hashable, Equatable {
    case cusdcv3
    case cwethv3
    case unknownComet(EthAddress)

    enum Given {
        case supplied(Account, TokenAmount)
        case borrowed(Account, TokenAmount)
    }

    static let knownCases: [Comet] = [.cusdcv3, .cwethv3]

    func address(network: Network) -> EthAddress {
        switch (network, self) {
        // TODO?: add cases for some more (network, market) pairs?
        // eventually this should be migrated to use builderpack instead.
        case (.ethereum, .cusdcv3):
            return EthAddress("0xc3d688B66703497DAA19211EEdff47f25384cdc3")
        case (.base, .cusdcv3):
            return EthAddress("0xb125E6687d4313864e53df431d5425969c15Eb2F")
        case (.ethereum, .cwethv3):
            return EthAddress("0xA17581A9E3356d9A858b789D68B4d866e593aE94")
        case (_, .cusdcv3):
            fatalError("no market .cusdcv3 for network \(network.description)")
        case (_, .cwethv3):
            fatalError("no market .cwethv3 for network \(network.description)")
        case let (_, .unknownComet(address)):
            return address
        }
    }

    var baseAsset: Token {
        switch self {
        case .cusdcv3: return .usdc
        case .cwethv3: return .weth
        case .unknownComet: return .unknownToken("0x0000000000000000000000000000000000000000")
        }
    }

    var description: String {
        switch self {
        case .cusdcv3:
            return "cUSDCv3"
        case .cwethv3:
            return "cWETHv3"
        case let .unknownComet(address):
            return "Comet at \(address.description)"
        }
    }

    static func from(network: Network, address: EthAddress) -> Comet {
        switch (network, address) {
        case (.ethereum, "0xc3d688B66703497DAA19211EEdff47f25384cdc3"):
            return .cusdcv3
        case (.ethereum, "0xA17581A9E3356d9A858b789D68B4d866e593aE94"):
            return .cwethv3
        case (.base, "0xb125E6687d4313864e53df431d5425969c15Eb2F"):
            return .cusdcv3
        case _:
            return .unknownComet(address)
        }
    }
}

enum Quote: Hashable, Equatable {
    case basic
    case custom(quoteId: Hex, prices: [Token: Double], fees: [Network: Double])

    static let knownCases: [Quote] = [.basic]

    var params: (quoteId: Hex, prices: [Token: Double], fees: [Network: Double]) {
        switch self {
        case let .custom(quoteId, prices, fees):
            return (quoteId, prices, fees)
        case .basic:
            return (
                Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
                Dictionary(
                    uniqueKeysWithValues: Token.knownCases.map { token in
                        (token, token.defaultUsdPrice)
                    }
                ),
                [
                    .ethereum: 0.10,
                    .base: 0.02,
                    .arbitrum: 0.04,
                ]
            )
        }
    }

    var prices: [Token: Double] {
        params.prices
    }

    var fees: [Network: Double] {
        params.fees
    }

    var quoteId: Hex {
        params.quoteId
    }

    static func findQuote(quoteId: Hex, prices: [Token: Double], fees: [Network: Double]) -> Quote {
        for knownCase in Quote.knownCases {
            if knownCase.params.quoteId == quoteId {
                return knownCase
            }
        }
        return .custom(quoteId: quoteId, prices: prices, fees: fees)
    }
}

// TODO: These should come from builder pack
enum Token: Hashable, Equatable {
    case usdc
    case eth
    case weth
    case link
    case unknownToken(EthAddress)

    static let knownCases: [Token] = [.usdc, .eth, .weth, .link]

    static let networkTokenAddress: [Network: [Token: EthAddress]] = [
        .ethereum: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"),
            .usdc: EthAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"),
            .link: EthAddress("0x514910771af9ca656af840dff83e8264ecf986ca")
        ],
        .base: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0x4200000000000000000000000000000000000006"),
            .usdc: EthAddress("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"),
            .link: EthAddress("0x514910771af9ca656af840dff83e8264ecf986ca") 
        ],
        .arbitrum: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"),
            .usdc: EthAddress("0xaf88d065e77c8cC2239327C5EDb3A432268e5831"),
            .link: EthAddress("0xf97f4df75117a78c1A5a0DBb814Af92458539FB4")
        ],
    ]

    static var networkAddressToken: [Network: [EthAddress: Token]] {
        networkTokenAddress.mapValues { tokenMap in
            Dictionary(uniqueKeysWithValues: tokenMap.map { ($0.value, $0.key) })
        }
    }

    static func from(network: Network, address: EthAddress) -> Token {
        if let token = Token.networkAddressToken[network]?[address] {
            return token
        } else {
            return .unknownToken(address)
        }
    }

    static func getTokenAmount(amount: BigUInt, network: Network, address: EthAddress)
        -> TokenAmount
    {
        let token = Token.from(network: network, address: address)
        return TokenAmount.amt(Double(amount) / pow(10, Double(token.decimals)), token)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    var symbol: String {
        switch self {
        case .usdc:
            return "USDC"
        case .eth:
            return "ETH"
        case .weth:
            return "WETH"
        case .link:
            return "LINK"
        case let .unknownToken(address):
            return "UnknownToken(\(address.description))"
        }
    }

    var decimals: Int {
        switch self {
        case .usdc:
            return 6
        case .eth, .weth, .link:
            return 18
        case .unknownToken:
            return 0
        }
    }

    var defaultUsdPrice: Double {
        switch self {
        case .usdc:
            return 1.0
        case .eth, .weth:
            return 4000.0
        case .link:
            return 25.0
        case .unknownToken:
            return 0
        }
    }

    var description: String {
        return symbol
    }

    func address(network: Network) -> EthAddress {
        if let address = Token.networkTokenAddress[network]?[self] {
            return address
        } else {
            fatalError("Unknown token \(self) for network \(network)")
        }
    }
}

extension BigUInt {
    static let max = BigUInt(1) << 256 - 1
}

struct TokenAmount: Equatable {
    let amount: BigUInt
    let token: Token

    init(fromAmount amount: Double, ofToken token: Token) {
        self.amount = BigUInt(amount * pow(10, Double(token.decimals)))
        self.token = token
    }

    init(fromWei amount: BigUInt, ofToken token: Token) {
        self.amount = amount
        self.token = token
    }

    static func == (lhs: TokenAmount, rhs: TokenAmount) -> Bool {
        return lhs.amount == rhs.amount && lhs.token == rhs.token
    }

    static func amt(_ amount: Double, _ token: Token) -> TokenAmount {
        return TokenAmount(
            fromAmount: amount,
            ofToken: token
        )
    }

    static func max(_ token: Token) -> TokenAmount {
        return TokenAmount(
            fromWei: BigUInt.max,
            ofToken: token
        )
    }
}

enum Given {
    case tokenBalance(Account, TokenAmount, Network)
    case quote(Quote)
    case cometSupply(Account, TokenAmount, Comet, Network)
    case cometBorrow(Account, TokenAmount, Comet, Network)
    case acrossQuote(TokenAmount, Double)
}

indirect enum When {
    case transfer(from: Account, to: Account, amount: TokenAmount, on: Network)
    case cometSupply(from: Account, market: Comet, amount: TokenAmount, on: Network)
    case cometRepay(from: Account, market: Comet, repayAmount: TokenAmount, collateralAmounts: [TokenAmount], on: Network)
    case payWith(currency: Token, When)

    var sender: Account {
        switch self {
        case let .transfer(from, _, _, _):
            return from
        case let .cometSupply(from, _, _, _):
            return from
        case let .cometRepay(from, _, _, _, _):
            return from
        case let .payWith(_, intent):
            return intent.sender
        }
    }

    var paymentAssetSymbol: String {
        switch self {
        case let .payWith(token, _):
            return token.symbol
        case _:
            return "USDC"
        }
    }
}

enum CallExpect {
    case single(Call)
    case multi([Call])
}

enum Expect {
    case revert(QuarkBuilder.RevertReason)
    case success(CallExpect)
}

final class AcceptanceTest: CustomTestArgumentEncodable, CustomStringConvertible, Sendable {
    let name: String
    let given: [Given]
    let when: When
    let expect: Expect
    let only: Bool
    let skip: Bool

    init(
        name: String, given: [Given], when: When, expect: Expect, only: Bool = false,
        skip: Bool = false
    ) {
        self.name = name
        self.given = given
        self.when = when
        self.expect = expect
        self.only = only
        self.skip = skip

        if only, skip {
            fatalError("Cannot set both `only` and `skip` for a test")
        }
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    var description: String {
        return name
    }
}

class Context {
    let sender: Account
    var prices: [Token: Double]
    var fees: [Network: Double]
    var paymentToken: Token?
    var tokenPositions: [Network: [Token: [Account: BigUInt]]]
    var cometPositions: [Network: [Comet: [Account: (BigUInt, BigUInt, [Token: BigUInt])]]]
    var ffis: EVM.FFIMap = [:]

    let allNetworks: [Network] = [.ethereum, .base, .arbitrum]

    var chainAccounts: [QuarkBuilder.Accounts.ChainAccounts] {
        allNetworks.map { network in
            QuarkBuilder.Accounts.ChainAccounts(
                chainId: BigUInt(network.chainId),
                quarkSecrets: [
                    .init(
                        account: sender.address,
                        nonceSecret: Hex(
                            "0x5555555555555555555555555555555555555555555555555555555555555555"
                        )
                    )
                ],
                assetPositionsList: reifyTokenPositions(network: network),
                cometPositions: reifyCometPositions(network: network),
                morphoPositions: [],
                morphoVaultPositions: []
            )
        }
    }

    init(sender: Account) {
        self.sender = sender
        prices = [:]
        fees = [:]
        paymentToken = .none
        tokenPositions = [:]
        cometPositions = [:]
    }

    func given(_ given: Given) {
        switch given {
        case let .tokenBalance(account, amount, network):
            let currentPosition =
                tokenPositions[network, default: [:]][amount.token, default: [:]][account] ?? 0
            tokenPositions[network, default: [:]][amount.token, default: [:]][account] =
                currentPosition + amount.amount
        case let .cometSupply(account, amount, comet, network):
            if amount.token == comet.baseAsset {
                let (currSupply, currBorrow, collaterals) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:]
                    )
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply + amount.amount, currBorrow, collaterals
                )
            } else {
                let (currSupply, currBorrow, collaterals) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:]
                    )
                var updatedCollaterals = collaterals
                updatedCollaterals[amount.token, default: 0] += amount.amount
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply, currBorrow, updatedCollaterals
                )
            }
        case let .cometBorrow(account, amount, comet, network):
            if amount.token == comet.baseAsset {
                let (currSupply, currBorrow, collaterals) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:]
                    )
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply, currBorrow + amount.amount, collaterals
                )
            } else {
                fatalError("Cannot borrow non-base asset")
            }
        case let .quote(quote):
            prices = quote.prices
            fees = quote.fees
        case let .acrossQuote(gasFee, feePct):
            ffis[EthAddress("0x0000000000000000000000000000000000FF1010")] = { _ in
                return .ok(
                    ABI.Value.tuple2(
                        .uint256(gasFee.amount), .uint256(BigUInt(feePct * 1e18))
                    ).encoded)
            }
        }
    }

    func when(_ when: When) async throws -> Result<
        QuarkBuilder.QuarkBuilderBase.BuilderResult, QuarkBuilder.RevertReason
    > {
        let assetQuotes = prices.map {
            QuarkBuilder.Quotes.AssetQuote.init(
                symbol: $0.key.symbol, price: BigUInt($0.value * 1e8))
        }

        let networkOperationFees = fees.map {
            QuarkBuilder.Quotes.NetworkOperationFee.init(
                chainId: BigUInt($0.key.chainId),
                opType: "BASELINE",
                price: BigUInt($0.value * 1e8)
            )
        }

        switch when {
        case let .payWith(token, intent):
            paymentToken = token
            return try await self.when(intent)

        case let .cometRepay(from, market, repayAmount, collateralAmounts, network):
            return try await QuarkBuilder.cometRepay(
                repayIntent: .init(
                    amount: repayAmount.amount,
                    assetSymbol: repayAmount.token.symbol,
                    blockTimestamp: 0,
                    chainId: BigUInt(network.chainId),
                    collateralAmounts: collateralAmounts.map {
                        $0.amount
                    },
                    collateralAssetSymbols: collateralAmounts.map {
                        $0.token.symbol
                    },
                    comet: market.address(network: network),
                    repayer: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )

        case let .cometSupply(from, market, amount, network):
            return try await QuarkBuilder.cometSupply(
                cometSupplyIntent: .init(
                    amount: amount.amount,
                    assetSymbol: amount.token.symbol,
                    blockTimestamp: 0,
                    chainId: BigUInt(network.chainId),
                    comet: market.address(network: network),
                    sender: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )

        case let .transfer(from, to, amount, network):
            return try await QuarkBuilder.transfer(
                transferIntent: .init(
                    chainId: BigUInt(network.chainId),
                    assetSymbol: amount.token.symbol,
                    amount: amount.amount,
                    sender: from.address,
                    recipient: to.address,
                    blockTimestamp: BigUInt(1_000_000),
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(1_200_000),
                    assetQuotes: prices.map {
                        .init(symbol: $0.key.symbol, price: BigUInt($0.value * 1e8))
                    },
                    networkOperationFees: fees.map {
                        .init(
                            chainId: BigUInt($0.key.chainId),
                            opType: "BASELINE",
                            price: BigUInt($0.value * 1e8)
                        )
                    }
                ),
                withFunctions: ffis
            )
        }
    }

    func reifyTokenPositions(network: Network) -> [QuarkBuilder.Accounts.AssetPositions] {
        Token.knownCases.map { token in
            QuarkBuilder.Accounts.AssetPositions(
                asset: token.address(network: network),
                symbol: token.symbol,
                decimals: BigUInt(token.decimals),
                usdPrice: BigUInt(token.defaultUsdPrice),
                accountBalances: Account.knownCases.map { account in
                    let amount =
                        tokenPositions[network, default: [:]][token, default: [:]][account] ?? 0
                    return QuarkBuilder.Accounts.AccountBalance(
                        account: account.address,
                        balance: amount
                    )
                }
            )
        }
    }

    func reifyCometPositions(network: Network) -> [QuarkBuilder.Accounts.CometPositions] {
        (cometPositions[network] ?? [:]).map { comet, accountPositions in
            var collateralPositions: [Token: [Account: BigUInt]] = [:]
            for (account, position) in accountPositions {
                for (token, amount) in position.2 {
                    collateralPositions[token, default: [:]][account] = amount
                }
            }

            return QuarkBuilder.Accounts.CometPositions(
                comet: comet.address(network: network),
                basePosition: QuarkBuilder.Accounts.CometBasePosition(
                    asset: comet.baseAsset.address(network: network),
                    accounts: accountPositions.map { account, _ in account.address },
                    borrowed: accountPositions.map { _, position in position.1 },
                    supplied: accountPositions.map { _, position in position.0 }
                ),
                collateralPositions: collateralPositions.map { token, accountAmounts in
                    QuarkBuilder.Accounts.CometCollateralPosition(
                        asset: token.address(network: network),
                        accounts: accountAmounts.map { account, amount in account.address },
                        balances: accountAmounts.map { _, amount in amount }
                    )
                }
            )
        }
    }
}

enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case reset = "\u{001B}[0m"
}

func colorize(_ text: String, with color: ANSIColor) -> String {
    return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

func customFatalError(_ message: String, file: String = #file, line: Int = #line) -> Never {
    print("Error: \(message)")
    print("Location: \(file):\(line)")
    print("Stack trace:")
    Thread.callStackSymbols.forEach { print($0) }
    fatalError(message)
}

func buildResultToCalls(builderResult: QuarkBuilder.QuarkBuilderBase.BuilderResult) -> [Call] {
    return zip(builderResult.quarkOperations, builderResult.actions).map { operation, action in
        Call.tryDecodeCall(
            scriptAddress: operation.scriptAddress, calldata: operation.scriptCalldata,
            network: Network.fromChainId(BigInt(action.chainId)))
    }
}

@Test func testCreate2Address() {
    let address = getScriptAddress(Hex("0xaa"))
    #expect(address == EthAddress("0x103B7e61BBaa2F62028Ebf3Ea7C47dC74Bd3a617"))
}

@Test("Acceptance Tests", arguments: filteredTests)
func testAcceptanceTests(test: AcceptanceTest) async throws {
    let context = Context(sender: test.when.sender)
    for given in test.given {
        context.given(given)
    }
    let result: Result<QuarkBuilder.QuarkBuilderBase.BuilderResult, QuarkBuilder.RevertReason>
    do {
        result = try await context.when(test.when)
    } catch let queryError as EVM.QueryError {
        result = .failure(
            QuarkBuilder.RevertReason.unknownRevert("QueryError", String(describing: queryError)))
    }

    switch (test.expect, result) {
    case let (.revert(expectedRevertReason), .failure(revertReason)):
        #expect(
            revertReason == expectedRevertReason,
            "\n\(colorize("Expected Revert:", with: .yellow))\n\t\(colorize(String(describing: expectedRevertReason), with: .reset))\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(colorize(String(describing: revertReason), with: .reset))\n\n"
        )
    case let (.revert(expectedRevertReason), .success(builderResult)):
        let calls = buildResultToCalls(builderResult: builderResult)
        #expect(
            Bool(false),
            "\n\(colorize("Expected Revert:", with: .yellow))\n\t\(colorize(String(describing: expectedRevertReason), with: .reset))\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(calls.descriptionExt)\n\n"
        )
    case let (.success(callExpect), .failure(revertReason)):
        let expectedCalls =
            switch callExpect {
            case let .single(expectedCall):
                [expectedCall]
            case let .multi(expectedCalls):
                expectedCalls
            }

        #expect(
            Bool(false),
            "\n\(colorize("Expected Result:", with: .yellow))\n\t\(expectedCalls.descriptionExt)\n\n\n\(colorize("Quark Builder Failure:", with: .yellow))\n\t\(colorize(String(describing: revertReason), with: .red))\n\n"
        )
    case let (.success(callExpect), .success(builderResult)):
        // #expect(builderResult.eip712Data.domainSeparator == EIP712Helper.DomainSeparator(name: "Quark", version: "1")) // TODO: Check domain separator?
        // #expect(builderResult.paymentCurrency == "USDC") // TODO: Check payment currency?

        let calls = buildResultToCalls(builderResult: builderResult)
        let expectedCalls =
            switch callExpect {
            case let .single(expectedCall):
                [expectedCall]
            case let .multi(expectedCalls):
                expectedCalls
            }
        #expect(
            expectedCalls == calls,
            "\n\(colorize("Expected Result:", with: .yellow))\n\t\(expectedCalls.descriptionExt)\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(calls.descriptionExt)\n\n"
        )
    }
}
