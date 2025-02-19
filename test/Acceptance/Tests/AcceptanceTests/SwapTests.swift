@preconcurrency import Eth
import Testing

@Suite("Swap Tests")
struct SwapTests {
    @Test("Alice bridges max and swaps with quote pay")
    func testBridgeSwapMaxWithQuotePaySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4_005.0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(4_005.0, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                    .zeroExQuote(.amt(1.5, .weth), .updatedZeroEx, .base),
                ],
                when: .swap(
                    from: .alice, sellAmount: .max(.usdc), buyAmount: .amt(2.0, .weth),
                    exchange: .zeroEx, on: .base),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(4_005.0, .usdc),
                            outputTokenAmount: .amt(3_963.95, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .swap(
                                // 4005+(4005*0.99-1)-0.12=7968.83
                                sellAmount: .amt(7_968.83, .usdc),
                                // buyAmount and exchange are updated to reflect the new quote
                                // We multiply by 0.99 to account for a 1% slippage buffer
                                buyAmount: .amt(1.5 * 0.99, .weth),
                                exchange: .updatedZeroEx,
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps an amount she does not have")
    func testSwapInsufficientFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic)
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
            )
        )
    }

    @Test("Alice swaps, but does not have enough to cover QuotePay cost")
    func testSwapMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
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
            )
        )
    }

    @Test("Alice swaps on a chain that cannot be bridged to")
    func testSwapFundsOnUnbridgeableChains() async throws {
        try await testAcceptanceTests(
            test: .init(
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
            )
        )
    }

    @Test("Alice swaps more than she has")
    func testSwapFundsUnavailableErrorGivesSuggestionForAvailableFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: Dictionary(
                                uniqueKeysWithValues: Token.knownCases.map { token in
                                    (token, token.defaultUsdPrice)
                                }
                            ),
                            fees: [
                                .ethereum: 3,
                                .base: 0.1,
                                .unknown(7777): 0.1,
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
            )
        )
    }

    @Test("Alice swaps on a single chain")
    func testLocalSwapSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
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
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps, wrapping ETH to WETH")
    func testLocalSwapWithAutoWrapperSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
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
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps, paying with QuotePay")
    func testLocalSwapWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
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
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps max")
    func testSwapMaxSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(9005, .usdc), .ethereum),
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: Dictionary(
                                uniqueKeysWithValues: Token.knownCases.map { token in
                                    (token, token.defaultUsdPrice)
                                }
                            ),
                            fees: [.ethereum: 5]
                        )
                    ),
                    .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base),
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
                                // We multiply by 0.99 to account for a 1% slippage buffer
                                buyAmount: .amt(2.5 * 0.99, .weth),
                                exchange: .updatedZeroEx,
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(5, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps, bridging funds from Ethereum to Base")
    func testBridgeSwapSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
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
                        ], executionType: .immediate),
                        .swap(
                            sellAmount: .amt(3000, .usdc),
                            buyAmount: .amt(1, .weth),
                            exchange: .zeroEx,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps, bridging funds from Ethereum to Base, paying with QuotePay")
    func testBridgeSwapWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: Dictionary(
                                uniqueKeysWithValues: Token.knownCases.map { token in
                                    (token, token.defaultUsdPrice)
                                }
                            ),
                            fees: [
                                .ethereum: 5,
                                .base: 1,
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
                        ], executionType: .immediate),
                        .swap(
                            sellAmount: .amt(3000, .usdc),
                            buyAmount: .amt(1, .weth),
                            exchange: .zeroEx,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps max on Base via Bridge, but some funds are unbridgeable")
    func testSwapMaxViaBridgeWithSomeUnbridgeableFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic),
                    .acrossQuoteWithMin(.amt(1, .usdc), 0.01, .amt(3000, .usdc)),
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                    .zeroExQuote(.amt(1.5, .weth), .updatedZeroEx, .base),
                ],
                when: .swap(
                    from: .alice,
                    sellAmount: .max(.usdc),
                    buyAmount: .amt(1, .weth),
                    exchange: .zeroEx,
                    on: .base
                ),
                expect: .success(
                    .multi([
                        // Only 2000 USDC is swapped because the other 50 USDC is unbridgeable.
                        .swap(
                            sellAmount: .amt(2000, .usdc),
                            // We multiply by 0.99 to account for a 1% slippage buffer
                            buyAmount: .amt(1.5 * 0.99, .weth),
                            exchange: .updatedZeroEx,
                            network: .base,
                            executionType: .immediate
                        ),
                        // Payment is made on Ethereum, where there are unbridgeable funds
                        .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic, executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps on Base via Bridge, with bridge amount adjusted to be the min bridge amount")
    func testSwapsOnBaseViaBridgeAdjustingAmount() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic),
                    .acrossQuoteWithMin(.amt(1, .usdc), 0.01, .amt(1000, .usdc)),
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                ],
                when: .swap(
                    from: .alice,
                    sellAmount: .amt(2000.1, .usdc),
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
                                // Normally would bridge 0.1, but bridge min is 1000
                                inputTokenAmount: .amt(1000, .usdc),
                                outputTokenAmount: .amt(989, .usdc)
                            ),
                            .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate),
                        .swap(
                            sellAmount: .amt(2000.1, .usdc),
                            buyAmount: .amt(1, .weth),
                            exchange: .zeroEx,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }
}
