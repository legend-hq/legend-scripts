@preconcurrency import Eth
import Testing

@Suite("Morpho Borrow Tests")
struct MorphoBorrowTests {
    @Test("Alice tries to borrow from a Morpho market that does not exist (WETH/USDC)")
    func testMorphoBorrowInvalidMarketParams() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .wbtc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .weth), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .weth),
                    on: .ethereum
                ),
                expect: .revert(.morphoMarketNotFound)
            )
        )
    }

    @Test("Alice tries to supply collateral that she does not have")
    func testMorphoBorrowFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .wbtc),
                    on: .ethereum
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.wbtc.symbol,
                        TokenAmount.amt(1, .wbtc).amount,
                        0
                    )
                )
            )
        )
    }

    @Test("Alice supplies WBTC and borrows USDC from Morpho")
    func testMorphoBorrowSuccess() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .wbtc), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .wbtc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .supplyCollateralAndBorrowFromMorpho(
                                borrowAmount: .amt(1, .usdc),
                                collateralAmount: .amt(1, .wbtc),
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

    @Test("Alice supplies ETH to Morpho, which is auto-wrapped to WETH")
    func testMorphoBorrowWithAutoWrapper() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .eth), .base),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .weth),
                    on: .base
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .wrapAsset(.eth),
                            .supplyCollateralAndBorrowFromMorpho(
                                borrowAmount: .amt(1, .usdc),
                                collateralAmount: .amt(1, .weth),
                                market: .morpho(.weth, .usdc),
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.02, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice borrows USDC with WBTC collateral, paying for the operation via QuotePay")
    func testMorphoBorrowWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .wbtc), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .wbtc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .supplyCollateralAndBorrowFromMorpho(
                                borrowAmount: .amt(1, .usdc),
                                collateralAmount: .amt(1, .wbtc),
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

    @Test(
        "Alice borrows USDC with WBTC collateral, paying for the operation using the USDC she borrowed"
    )
    func testMorphoBorrowPayFromBorrow() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .wbtc), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmount: .amt(1, .wbtc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .supplyCollateralAndBorrowFromMorpho(
                                borrowAmount: .amt(1, .usdc),
                                collateralAmount: .amt(1, .wbtc),
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

    @Test("Alice tries to borrow from Morpho, but the operation cost exceeds her USDC balance")
    func testMorphoBorrowMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0.4, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(2, .wbtc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .weth), .ethereum),
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: [Token.usdc: 1.0],
                            fees: [
                                .ethereum: 0.5
                            ]
                        )
                    ),
                ],
                when: .morphoBorrow(
                    from: .alice,
                    borrowAmount: .amt(1, .weth),
                    collateralAmount: .amt(0, .wbtc),
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
            )
        )
    }

    @Test("Alice borrows from Morpho, supplying max WBTC collateral and paying with WBTC")
    func testMorphoBorrowWithMaxCollateral() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(5, .wbtc), .ethereum),
                    .quote(.basic),
                ],
                when: .payWith(
                    currency: .wbtc,
                    .morphoBorrow(
                        from: .alice,
                        borrowAmount: .amt(1, .usdc),
                        collateralAmount: .max(.wbtc),
                        on: .ethereum
                    )
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .supplyCollateralAndBorrowFromMorpho(
                                borrowAmount: .amt(1, .usdc),
                                collateralAmount: .init(fromWei: 499_999_900, ofToken: .wbtc),
                                market: .init(collateralToken: .wbtc, borrowToken: .usdc),
                                network: .ethereum
                            ),
                            .quotePay(
                                payment: .init(fromWei: 100, ofToken: .wbtc), payee: .stax,
                                quote: .basic),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }
}
