@preconcurrency import Eth
import Testing

@Suite("Swap And Supply Tests")
struct SwapAndSupplyTests {
    @Test("Alice swaps and supplies on a single chain, paying with QuotePay")
    func testLocalSwapAndSupplyWithQuotePaySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4000, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(3000, .usdc),
                        buyAmount: .amt(1, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(0.5, .weth), on: .ethereum
                    )
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
                            .supplyToComet(
                                tokenAmount: .amt(0.5, .weth), market: .cwethv3,
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice auto-wraps ETH, then swaps and supplies on a single chain, paying with QuotePay")
    func testLocalSwapAndSupplyWithAutoWrapperSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .eth), .ethereum),
                    .tokenBalance(.alice, .amt(10, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(1, .weth),
                        buyAmount: .amt(3000, .usdc),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cusdcv3, amount: .amt(3005, .usdc), on: .ethereum
                    )
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
                            .supplyToComet(
                                tokenAmount: .amt(3005, .usdc), market: .cusdcv3,
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps max and supplies an amount on a single chain, paying with QuotePay")
    func testSwapMaxSucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(9000.1, .usdc), .ethereum),
                    .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .max(.usdc),
                        buyAmount: .amt(3, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(2, .weth), on: .ethereum
                    )
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
                            .supplyToComet(
                                tokenAmount: .amt(2, .weth), market: .cwethv3,
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice swaps an amount and supplies max on a single chain, paying with QuotePay")
    func testCometSupplyMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .weth), .ethereum),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(1, .weth),
                        buyAmount: .amt(3000, .usdc),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cusdcv3, amount: .max(.usdc), on: .ethereum
                    )
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .swap(
                                    sellAmount: .amt(1, .weth),
                                    buyAmount: .amt(3000, .usdc),
                                    exchange: .zeroEx,
                                    network: .ethereum
                                ),
                                .supplyToComet(
                                    tokenAmount: .amt(2999.9, .usdc), market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ],
                            executionType: .immediate
                        )
                    )
                )
            )
        )
    }

    @Test("Alice swaps max and supplies max on a single chain, paying with QuotePay")
    func testCometSwapAndSupplyMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(9000.1, .usdc), .ethereum),
                    .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .max(.usdc),
                        buyAmount: .amt(3, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .max(.weth), on: .ethereum
                    )
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .swap(
                                    sellAmount: .amt(9000, .usdc),
                                    // buyAmount and exchange are updated to reflect the new quote
                                    // We multiply by 0.99 to account for a 1% slippage buffer
                                    buyAmount: .amt(2.5 * 0.99, .weth),
                                    exchange: .updatedZeroEx,
                                    network: .ethereum
                                ),
                                .supplyToComet(
                                    tokenAmount: .amt(2.5 * 0.99, .weth), market: .cwethv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ],
                            executionType: .immediate
                        )
                    )
                )
            )
        )
    }

    @Test("Alice bridges funds from Ethereum to Base, then swaps and supplies, paying with QuotePay")
    func testBridgeSwapAndSupplySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(3000, .usdc),
                        buyAmount: .amt(1, .weth),
                        exchange: .zeroEx,
                        on: .base
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(1, .weth), on: .base
                    )
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
                        .multicall([
                            .swap(
                                sellAmount: .amt(3000, .usdc),
                                buyAmount: .amt(1, .weth),
                                exchange: .zeroEx,
                                network: .base
                            ),
                            .supplyToComet(
                                tokenAmount: .amt(1, .weth), market: .cwethv3,
                                network: .base
                            ),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice bridges and swaps max and supplies an amount, paying with QuotePay")
    func testBridgeSwapMaxAndSupplyWithQuotePaySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                    .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .max(.usdc),
                        buyAmount: .amt(2.0, .weth),
                        exchange: .zeroEx,
                        on: .base
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(2, .weth), on: .base
                    )
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(2000, .usdc),
                            // 2000 * (1 - .01) Across pct fee - 1 Across base fee = 1979
                            outputTokenAmount: .amt(1979, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .swap(
                                // subtract 0.12 USDC to be used for the QuotePay
                                sellAmount: .amt(3979 - 0.12, .usdc),
                                // buyAmount and exchange are updated to reflect the new quote
                                // We multiply by 0.99 to account for a 1% slippage buffer
                                buyAmount: .amt(2.5 * 0.99, .weth),
                                exchange: .updatedZeroEx,
                                network: .base
                            ),
                            .supplyToComet(
                                tokenAmount: .amt(2, .weth), market: .cwethv3,
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice bridges and swaps max and supplies max, paying with QuotePay")
    func testBridgeSwapMaxAndSupplyMaxWithQuotePaySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                    .zeroExQuote(.amt(2.5, .weth), .updatedZeroEx, .base),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .max(.usdc),
                        buyAmount: .amt(2.0, .weth),
                        exchange: .zeroEx,
                        on: .base
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .max(.weth), on: .base
                    )
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(2000, .usdc),
                            // 2000 * (1 - .01) Across pct fee - 1 Across base fee = 1979
                            outputTokenAmount: .amt(1979, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .swap(
                                // subtract 0.12 USDC to be used for the QuotePay
                                sellAmount: .amt(3979 - 0.12, .usdc),
                                // buyAmount and exchange are updated to reflect the new quote
                                // We multiply by 0.99 to account for a 1% slippage buffer
                                buyAmount: .amt(2.5 * 0.99, .weth),
                                exchange: .updatedZeroEx,
                                network: .base
                            ),
                            .supplyToComet(
                                tokenAmount: .amt(2.5 * 0.99, .weth), market: .cwethv3,
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps and supplies on Base via bridge, with bridge amount adjusted to be the min bridge amount")
    func testSwapsOnBaseViaBridgeAdjustingAmount() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic),
                    .acrossQuoteWithMin(.amt(1, .usdc), 0.01, .amt(1000, .usdc)),
                    .tokenBalance(.alice, .amt(2000, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2000, .usdc), .base),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(2000.1, .usdc),
                        buyAmount: .amt(1, .weth),
                        exchange: .zeroEx,
                        on: .base
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(1, .weth), on: .base
                    )
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
                        .multicall([
                            .swap(
                                sellAmount: .amt(2000.1, .usdc),
                                buyAmount: .amt(1, .weth),
                                exchange: .zeroEx,
                                network: .base
                            ),
                            .supplyToComet(
                                tokenAmount: .amt(1, .weth), market: .cwethv3,
                                network: .base
                            ),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice swaps on a chain that cannot be bridged to")
    func testSwapFundsOnUnbridgeableChains() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(0, .usdc), .unknown(7777)),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(30, .usdc),
                        buyAmount: .amt(0.01, .weth),
                        exchange: .zeroEx,
                        on: .unknown(7777)
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(0.5, .weth), on: .ethereum
                    )
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        // TODO: This seems to be due to a bug in Network.swift, where all .unknown(_) enums return a chain id of 0
                        "",
                        TokenAmount.amt(30, .usdc).amount,
                        TokenAmount.amt(0, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies on a chain that cannot be bridged to")
    func testSuppliesFundsOnUnbridgeableChains() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(30, .usdc),
                        buyAmount: .amt(0.1, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .unknownComet("0x0000000000000000000000000000000000000000"), amount: .amt(0.1, .weth), on: .lineaSepolia
                    )
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        "WETH",
                        TokenAmount.amt(0.1, .weth).amount,
                        TokenAmount.amt(0, .weth).amount
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
                    .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(30, .usdc), .base),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(65, .usdc),
                        buyAmount: .amt(0.01, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(0.5, .weth), on: .ethereum
                    )
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

    @Test("Alice supplies more than she has")
    func testSupplyFundsUnavailableErrorGivesSuggestionForAvailableFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(60, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(60, .usdc),
                        buyAmount: .amt(0.1, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(0.5, .weth), on: .ethereum
                    )
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.weth.symbol,
                        TokenAmount.amt(0.5, .weth).amount,
                        TokenAmount.amt(0.1, .weth).amount
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
                    .tokenBalance(.alice, .amt(30, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(30, .usdc), .base),
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
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(30, .usdc),
                        buyAmount: .amt(0.1, .weth),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cwethv3, amount: .amt(0.1, .weth), on: .ethereum
                    )
                ),
                expect: .revert(
                    .unableToConstructQuotePay(
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(1000.1, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies, but does not have enough to cover QuotePay cost")
    func testSupplyMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0.1, .weth), .ethereum),
                    .tokenBalance(.alice, .amt(0.1, .weth), .base),
                    .quote(.basic),
                ],
                when: .swapAndSupply(
                    swap: (
                        from: .alice,
                        sellAmount: .amt(0.1, .weth),
                        buyAmount: .amt(900, .usdc),
                        exchange: .zeroEx,
                        on: .ethereum
                    ),
                    supply: (
                        from: .alice, market: .cusdcv3, amount: .amt(900, .usdc), on: .ethereum
                    )
                ),
                expect: .revert(
                    .unableToConstructQuotePay(
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0, .usdc).amount
                    )
                )
            )
        )
    }
}
