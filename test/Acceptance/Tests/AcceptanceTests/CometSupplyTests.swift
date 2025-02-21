@preconcurrency import Eth
import Testing

@Suite("Comet Supply Tests")
struct CometSupplyTests {
    @Test("Alice supplies 0.5 WETH to cUSDCv3 on Ethereum")
    func testCometSupplyWETH() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.0, .weth), .ethereum),
                    .quote(.basic),
                ],
                when: .payWith(
                    currency: .weth,
                    .cometSupply(
                        from: .alice, market: .cusdcv3, amount: .amt(0.5, .weth), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(0.5, .weth), market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(
                                    payment: .amt(0.000025, .weth), payee: .stax, quote: .basic
                                ),
                            ],
                            executionType: .immediate
                        )
                    )
                )
            )
        )
    }

    @Test("Alice supplies 0.5 ETH to cUSDCv3 on Ethereum", .disabled())
    func testCometSupplyETH() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.0, .eth), .ethereum),
                    .quote(.basic),
                ],
                when: .payWith(
                    currency: .eth,
                    .cometSupply(
                        from: .alice, market: .cusdcv3, amount: .amt(0.5, .eth), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(0.5, .eth), market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(
                                    payment: .amt(0.000025, .eth), payee: .stax, quote: .basic),
                            ],
                            executionType: .immediate
                        )
                    )
                )
            )
        )
    }

    @Test("Alice supplies, but does not allow enough for quote pay")
    func testCometSupplyInsufficientFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic)
                ],
                when: .cometSupply(
                    from: .alice, market: .cusdcv3, amount: .amt(2, .usdc), on: .ethereum
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.usdc.symbol,
                        TokenAmount.amt(2, .usdc).amount,
                        TokenAmount.amt(0, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies, but cannot cover operation cost")
    func testCometSupplyMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.0, .usdc), .base),
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: [Token.usdc: 1.0],
                            fees: [
                                .ethereum: 1000,
                                .base: 0.03,
                            ]
                        )
                    ),
                ],
                when: .payWith(
                    currency: .usdc,
                    .cometSupply(
                        from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum)
                ),
                expect: .revert(
                    .unableToConstructActionIntent(
                        false,
                        "",
                        0,
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(1000.03, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies to Comet")
    func testSimpleCometSupply() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .cometSupply(
                    from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(1, .usdc), market: .cusdcv3,
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

    @Test("Alice supplies max to Comet")
    func testSimpleCometSupplyMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .cometSupply(
                    from: .alice, market: .cusdcv3, amount: .max(.usdc), on: .ethereum),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(2.9, .usdc), market: .cusdcv3,
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

    @Test("Alice supplies max to Comet with bridge")
    func testCometSupplyMaxWithBridgeAndQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .cometSupply(
                    from: .alice, market: .cusdcv3, amount: .max(.usdc), on: .arbitrum),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .base,
                            destinationNetwork: .arbitrum,
                            inputTokenAmount: .amt(50, .usdc),
                            outputTokenAmount: .amt(48.5, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(98.44, .usdc), market: .cusdcv3,
                                    network: .arbitrum
                                ),
                                .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                            ],
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies to Comet, paying via Quote Pay")
    func testCometSupplyWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .cometSupply(
                    from: .alice, market: .cusdcv3, amount: .amt(1, .usdc), on: .ethereum),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToComet(
                                    tokenAmount: .amt(1, .usdc), market: .cusdcv3,
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

    @Test("Alice supplies ETH to Comet after bridging, paying via Quote Pay")
    func testCometSupplyAfterBridgeWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .optimism),
                    .tokenBalance(.alice, .amt(1.5, .eth), .optimism),
                    .quote(.basic),
                    .acrossQuote(.amt(0.01, .eth), 0.01),
                ],
                when: .cometSupply(
                   from: .alice, market: .cwethv3, amount: .amt(1, .weth), on: .base),
                expect: .success(
                    .multi([
                        .multicall([
                            .wrapAsset(.eth),
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .optimism,
                                destinationNetwork: .base,
                                inputTokenAmount: .amt(1.02, .weth),
                                outputTokenAmount: .amt(1, .weth)
                            ),
                            .quotePay(payment: .amt(0.08, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate),
                        .multicall([
                            .wrapAsset(.eth),
                            .supplyToComet(
                                tokenAmount: .amt(1, .weth), market: .cwethv3, network: .base
                            ),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }
}
