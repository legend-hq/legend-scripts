@preconcurrency import BigInt
@preconcurrency import Eth
import Testing

@Suite("Comet Borrow Tests")
struct CometBorrowTests {
    @Test("Alice tries to supply collateral that she doesn't have")
    func testBorrowFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic)
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmounts: [.amt(1, .link)],
                    on: .ethereum
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.link.symbol,
                        TokenAmount.amt(1, .link).amount,
                        TokenAmount.amt(0, .link).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies 1 Link and borrows 1 USDC on mainnet cUSDCv3")
    func testBorrow() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .link), .ethereum),
                    .quote(.basic),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmounts: [.amt(1, .link)],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyMultipleAssetsAndBorrowFromComet(
                                    borrowAmount: .amt(1, .usdc),
                                    collateralAmounts: [.amt(1, .link)],
                                    market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(
                                    payment: .amt(0.1, .usdc), payee: .stax, quote: .basic
                                ),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice supplies 10 ETH, which are auto-wrapped to WETH")
    func testBorrowWithAutoWrapper() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .eth), .ethereum),
                    .quote(.basic),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(1, .usdc),
                    collateralAmounts: [.amt(10, .weth)],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .wrapAsset(.eth),
                                .supplyMultipleAssetsAndBorrowFromComet(
                                    borrowAmount: .amt(1, .usdc),
                                    collateralAmounts: [.amt(10, .weth)],
                                    market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(
                                    payment: .amt(0.1, .usdc), payee: .stax, quote: .basic
                                ),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice borrows from Comet, paying with QuotePay")
    func testCometBorrowWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(5, .wbtc), .base),
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
                            fees: [.ethereum: 0.1, .base: 1]
                        )
                    ),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(1, .usdt),
                    collateralAmounts: [.amt(1, .wbtc)],
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .supplyMultipleAssetsAndBorrowFromComet(
                            borrowAmount: .amt(1, .usdt),
                            collateralAmounts: [.amt(1, .wbtc)],
                            market: .cusdcv3,
                            network: .base,
                            executionType: .immediate
                        ),
                        .quotePay(
                            payment: .amt(1.1, .usdc), payee: .stax, quote: .basic,
                            executionType: .immediate),
                    ])
                )
            )
        )
    }

    @Test("Alice borrows from Comet on Optimism")
    func testCometBorrowOnOptimism() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(5, .wbtc), .optimism),
                    .quote(.basic),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(1, .usdt),
                    collateralAmounts: [.amt(1, .wbtc)],
                    on: .optimism
                ),
                expect: .success(
                    .multi([
                        .supplyMultipleAssetsAndBorrowFromComet(
                            borrowAmount: .amt(1, .usdt),
                            collateralAmounts: [.amt(1, .wbtc)],
                            market: .cusdcv3,
                            network: .optimism
                        ),
                        .quotePay(payment: .amt(0.16, .usdc), payee: .stax, quote: .basic),
                    ])
                )
            )
        )
    }

    @Test("Alice pays for a QuotePay with USDC she has borrowed")
    func testBorrowPayFromBorrow() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .link), .ethereum),
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
                            fees: [.ethereum: 1.5]
                        )
                    ),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cusdcv3,
                    borrowAmount: .amt(2, .usdc),
                    collateralAmounts: [.amt(1, .link)],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .supplyMultipleAssetsAndBorrowFromComet(
                                borrowAmount: .amt(2, .usdc),
                                collateralAmounts: [.amt(1, .link)],
                                market: .cusdcv3,
                                network: .ethereum
                            ),
                            .quotePay(payment: .amt(1.5, .usdc), payee: .stax, quote: .basic),
                        ])
                    )
                )
            )
        )
    }

    @Test("Alice supplies bridged USDC and borrows against it", .disabled("reverts with `Panic`"))
    func testBorrowWithBridgedCollateralAsset() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
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
                            fees: [.ethereum: 0.1, .base: 0.2]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .cometBorrow(
                    from: .alice,
                    market: .cwethv3,
                    borrowAmount: .amt(1, .weth),
                    collateralAmounts: [.amt(2, .usdc)],
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .ethereum,
                                destinationNetwork: .base,
                                inputTokenAmount: .amt(2.2, .usdc),
                                outputTokenAmount: .amt(1.178, .usdc),
                                executionType: .immediate
                            ),
                            .quotePay(
                                payment: .amt(0.3, .usdc), payee: .stax, quote: .basic,
                                executionType: .immediate),
                        ]),
                        .supplyMultipleAssetsAndBorrowFromComet(
                            borrowAmount: .amt(2, .usdc),
                            collateralAmounts: [.amt(1, .weth)],
                            market: .cusdcv3,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice borrows from Comet, supplying max weth collateral and paying with weth")
    func testCometBorrowWithMaxCollateral() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(5, .weth), .base),
                    .quote(.basic),
                ],
                when: .payWith(
                    currency: .weth,
                    .cometBorrow(
                        from: .alice,
                        market: .cusdcv3,
                        borrowAmount: .amt(1, .usdt),
                        collateralAmounts: [.max(.weth)],
                        on: .base
                    )),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyMultipleAssetsAndBorrowFromComet(
                                    borrowAmount: .amt(1, .usdt),
                                    collateralAmounts: [
                                        .init(fromWei: 4_999_995_000_000_000_000, ofToken: .weth)
                                    ],
                                    market: .cusdcv3,
                                    network: .base
                                ),
                                .quotePay(
                                    payment: .init(fromWei: 5_000_000_000_000, ofToken: .weth),
                                    payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test(
        "Alice borrows from Comet, supplying max weth collateral and paying with weth when no weth balance"
    )
    func testCometBorrowWithMaxCollateralAndNoWethBalance() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic)
                ],
                when: .payWith(
                    currency: .weth,
                    .cometBorrow(
                        from: .alice,
                        market: .cusdcv3,
                        borrowAmount: .amt(1, .usdt),
                        collateralAmounts: [.max(.weth)],
                        on: .base
                    )),
                expect: .revert(
                    .unableToConstructActionIntent(
                        false,
                        "",
                        0,
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.weth.symbol,
                        TokenAmount.amt(0, .weth).amount
                    )
                )
            )
        )
    }
}
