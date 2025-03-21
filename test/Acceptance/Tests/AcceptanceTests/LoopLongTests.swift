@preconcurrency import Eth
import Testing

@Suite("Loop Long Tests")
struct LoopLongTests {
    @Test("Alice loops long on WBTC using USDC")
    func testLoopLongSuccess() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(20_010, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(1, .wbtc),
                    backingAmount: .amt(20_000, .usdc),
                    maxSwapBackingAmount: .amt(85_000, .usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .loopLong(
                                exposureAmount: .amt(1, .wbtc),
                                backingAmount: .amt(20_000, .usdc),
                                maxSwapBackingAmount: .amt(85_000, .usdc),
                                market: .morpho(.wbtc, .usdc),
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice loops long cbETH using ETH, which is auto-wrapped to WETH")
    func testLoopWithAutoWrapper() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .eth), .base),
                    .tokenBalance(.alice, .amt(1, .usdc), .base),
                    .quote(.basic),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(2, .cbeth),
                    backingAmount: .amt(1, .weth),
                    maxSwapBackingAmount: .amt(2, .weth),
                    on: .base
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .wrapAsset(.eth),
                            .loopLong(
                                exposureAmount: .amt(2, .cbeth),
                                backingAmount: .amt(1, .weth),
                                maxSwapBackingAmount: .amt(2, .weth),
                                market: .morpho(.cbeth, .weth),
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.02, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice loops long cbETH using USDC on Base via bridge")
    func testTransferUsdcToBobViaBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(21_000, .usdc), .arbitrum),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(1, .cbeth),
                    backingAmount: .amt(20_000, .usdc),
                    maxSwapBackingAmount: .amt(85_000, .usdc),
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .arbitrum,
                                destinationNetwork: .base,
                                inputTokenAmount: .amt(20_201, .usdc),
                                outputTokenAmount: .amt(20_000, .usdc),
                                cappedMax: false
                            ),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate),
                        .loopLong(
                            exposureAmount: .amt(1, .cbeth),
                            backingAmount: .amt(20_000, .usdc),
                            maxSwapBackingAmount: .amt(85_000, .usdc),
                            market: .morpho(.cbeth, .usdc),
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice tries to loop from a Morpho market that does not exist (WETH/USDC)")
    func testLoopLongInvalidMorphoMarketParams() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(1, .weth),
                    backingAmount: .amt(1, .usdc),
                    maxSwapBackingAmount: .amt(1, .usdc),
                    on: .ethereum
                ),
                expect: .revert(.morphoMarketNotFound)
            )
        )
    }

    @Test("Alice tries to loop with a backing token that she does not have")
    func testLoopLongFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .wbtc), .ethereum),
                    .quote(.basic),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(1, .wbtc),
                    backingAmount: .amt(1, .usdc),
                    maxSwapBackingAmount: .amt(1, .usdc),
                    on: .ethereum
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.usdc.symbol,
                        TokenAmount.amt(1, .usdc).amount,
                        0
                    )
                )
            )
        )
    }

    @Test("Alice tries to loop long, but the operation cost exceeds her USDC balance")
    func testLoopLongMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0.4, .usdc), .base),
                    .tokenBalance(.alice, .amt(1, .eth), .base),
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: [Token.usdc: 1.0],
                            fees: [
                                .base: 0.5,
                            ]
                        )
                    ),
                ],
                when: .loopLong(
                    from: .alice,
                    exposureAmount: .amt(2, .cbeth),
                    backingAmount: .amt(1, .weth),
                    maxSwapBackingAmount: .amt(2, .weth),
                    on: .base
                ),
                expect: .revert(
                    .unableToConstructQuotePay(
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0.5, .usdc).amount
                    )
                )
            )
        )
    }
}
