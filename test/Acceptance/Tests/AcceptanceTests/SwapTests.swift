@preconcurrency import Eth

let swapTests: [AcceptanceTest] = [
    .init(
        name: "testBridgeSwapMaxWithQuotePaySucceeds",
        given: [
            .tokenBalance(.alice, .amt(4_005.0, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(4_005.0, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
            .zeroExQuote(.amt(1.5, .weth), .updatedZeroEx, .base)
        ],
        when: .swap(from: .alice, sellAmount: .max(.usdc), buyAmount: .amt(2.0, .weth), exchange: .zeroEx, on: .base),
        expect: .success(
            .multi([
                .bridge(
                    bridge: "Across",
                    srcNetwork: .ethereum,
                    destinationNetwork: .base,
                    inputTokenAmount: .amt(4_005.0, .usdc),
                    outputTokenAmount: .amt(3_963.95, .usdc)
                ),
                .multicall([
                    .swap(
                        // 4005+(4005*0.99-1)-0.12=7968.83
                        sellAmount: .amt(7_968.83, .usdc),
                        // buyAmount and exchange are updated to reflect the new quote
                        buyAmount: .amt(1.5, .weth),
                        exchange: .updatedZeroEx,
                        network: .base
                    ),
                    .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),

    .init(
        name: "Alice swaps an amount she does not have (testSwapInsufficientFunds)",
        given: [
            .quote(.basic),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(3000, .usdc),
            buyAmount: .amt(1, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(3000, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice swaps, but does not have enough to cover QuotePay cost (testSwapMaxCostTooHigh)",
        given: [
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 1000, .base: 0.1]
                )
            ),
            .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(30, .usdc), .base),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(30, .usdc),
            buyAmount: .amt(0.01, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(1000.1, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice swaps on a chain that cannot be bridged to (testSwapFundsOnUnbridgeableChains)",
        given: [
            .quote(.basic),
            .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(30, .usdc), .base),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(30, .usdc),
            buyAmount: .amt(0.01, .weth),
            exchange: .zeroEx,
            on: .unknown(7777)
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                "",
                TokenAmount.amt(30, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice swaps more than she has (testSwapFundsUnavailableErrorGivesSuggestionForAvailableFunds)",
        given: [
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
                        .ethereum: 3,
                        .base: 0.1,
                        .unknown(7777): 0.1
                    ]
                )
            ),
            .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(30, .usdc), .base),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(65, .usdc),
            buyAmount: .amt(0.01, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(65, .usdc).amount,
                TokenAmount.amt(60, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice swaps on a single chain (testLocalSwapSucceeds)",
        given: [
            .tokenBalance(.alice, .amt(4000, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(3000, .usdc),
            buyAmount: .amt(1, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .swap(
                        sellAmount: .amt(3000, .usdc),
                        buyAmount: .amt(1, .weth),
                        exchange: .zeroEx,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice swaps, wrapping ETH to WETH (testLocalSwapWithAutoWrapperSucceeds)",
        given: [
            .tokenBalance(.alice, .amt(1, .eth), .ethereum),
            .tokenBalance(.alice, .amt(10, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(1, .weth),
            buyAmount: .amt(3000, .usdc),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .wrapAsset(.eth),
                    .swap(
                        sellAmount: .amt(1, .weth),
                        buyAmount: .amt(3000, .usdc),
                        exchange: .zeroEx,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice swaps, paying with QuotePay (testLocalSwapWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(3005, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(3005, .usdc), .base),
            .quote(.basic),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(3000, .usdc),
            buyAmount: .amt(1, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .swap(
                        sellAmount: .amt(3000, .usdc),
                        buyAmount: .amt(1, .weth),
                        exchange: .zeroEx,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice swaps max (testSwapMaxSucceeds)",
        given: [
            .tokenBalance(.alice, .amt(9005, .usdc), .ethereum),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 5]
                )
            ),
            .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base)
        ],
        when: .swap(
            from: .alice,
            sellAmount: .max(.usdc),
            buyAmount: .amt(3, .weth),
            exchange: .zeroEx,
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .swap(
                        sellAmount: .amt(9000, .usdc),
                        // buyAmount and exchange are updated to reflect the new quote
                        buyAmount: .amt(2.5, .weth),
                        exchange: .updatedZeroEx,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(5, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice swaps, bridging funds from Ethereum to Base (testBridgeSwapSucceeds)",
        given: [
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
            .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(2000, .usdc), .base),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(3000, .usdc),
            buyAmount: .amt(1, .weth),
            exchange: .zeroEx,
            on: .base
        ),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .ethereum,
                        destinationNetwork: .base,
                        // 1000 + 1 Across base fee + (1000 * .01) Across pct fee = 1011
                        inputTokenAmount: .amt(1011, .usdc),
                        outputTokenAmount: .amt(1000, .usdc)
                    ),
                    .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                ]),
                .swap(
                    sellAmount: .amt(3000, .usdc),
                    buyAmount: .amt(1, .weth),
                    exchange: .zeroEx,
                    network: .base
                )
            ])
        )
    ),

    .init(
        name: "Alice swaps, bridging funds from Ethereum to Base, paying with QuotePay (testBridgeSwapWithQuotePay)",
        given: [
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
                        .ethereum: 5,
                        .base: 1
                    ]
                )
            ),
            .acrossQuote(.amt(1, .usdc), 0.01),
            .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(2000, .usdc), .base),
        ],
        when: .swap(
            from: .alice,
            sellAmount: .amt(3000, .usdc),
            buyAmount: .amt(1, .weth),
            exchange: .zeroEx,
            on: .base
        ),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .ethereum,
                        destinationNetwork: .base,
                        // 1000 + 1 Across base fee + (1000 * .01) Across pct fee = 1011
                        inputTokenAmount: .amt(1011, .usdc),
                        outputTokenAmount: .amt(1000, .usdc)
                    ),
                    .quotePay(payment: .amt(6, .usdc), payee: .stax, quote: .basic),
                ]),
                .swap(
                    sellAmount: .amt(3000, .usdc),
                    buyAmount: .amt(1, .weth),
                    exchange: .zeroEx,
                    network: .base
                )
            ])
        )
    )

    // TODO: swap max with bridge
]
