@preconcurrency import Eth
import Testing

@Suite("Comet Repay Tests")
struct CometRepayTests {
    @Test("Alice repays 1 USDC after supplying 1 LINK")
    func testCometRepay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(2, .usdc), .ethereum),
                    .cometBorrow(.alice, .amt(1, .usdc), .cusdcv3, .ethereum),
                    .cometSupply(.alice, .amt(1, .link), .cusdcv3, .ethereum),
                    .quote(.basic),
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
                        .multicall(
                            [
                                .repayAndWithdrawMultipleAssetsFromComet(
                                    repayAmount: .amt(1, .usdc),
                                    collateralAmounts: [.amt(1, .link)],
                                    market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice tries to repay with insufficient funds")
    func testCometRepayFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic)
                ],
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
            )
        )
    }

    @Test("Alice repays WETH with insufficient USDC")
    func testCometRepayNotEnoughPaymentToken() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0.4, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .weth), .ethereum),
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
                            fees: [.ethereum: 0.5]
                        )
                    ),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cwethv3,
                    repayAmount: .amt(1, .weth),
                    collateralAmounts: [],
                    on: .ethereum
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

    @Test("Alice repays with auto-wrapped ETH")
    func testCometRepayWithAutoWrapper() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .eth), .ethereum),
                    .quote(.basic),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cwethv3,
                    repayAmount: .amt(1, .weth),
                    collateralAmounts: [.amt(1, .link)],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .wrapAsset(.eth),
                                .repayAndWithdrawMultipleAssetsFromComet(
                                    repayAmount: .amt(1, .weth),
                                    collateralAmounts: [.amt(1, .link)],
                                    market: .cwethv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice repays and pays from withdrawn collateral")
    func testCometRepayPayFromWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .weth), .ethereum),
                    .quote(.basic),
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
                        .multicall(
                            [
                                .repayAndWithdrawMultipleAssetsFromComet(
                                    repayAmount: .amt(1, .weth),
                                    collateralAmounts: [.amt(1, .usdc)],
                                    market: .cwethv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice repays max USDC and pays with QuotePay")
    func testCometRepayMaxWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .ethereum),
                    .cometBorrow(.alice, .amt(10, .usdc), .cusdcv3, .ethereum),
                    .quote(.basic),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cusdcv3,
                    repayAmount: .max(.usdc),
                    collateralAmounts: [],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .repayAndWithdrawMultipleAssetsFromComet(
                                    repayAmount: .max(.usdc),
                                    collateralAmounts: [],
                                    market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice repays max balance USDC with QuotePay")
    func testCometRepayMaxBalanceWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .usdc), .ethereum),
                    .cometBorrow(.alice, .amt(50, .usdc), .cusdcv3, .ethereum),
                    .quote(.basic),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cusdcv3,
                    repayAmount: .max(.usdc),
                    collateralAmounts: [],
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .repayAndWithdrawMultipleAssetsFromComet(
                                    repayAmount: .amt(9.9, .usdc),
                                    collateralAmounts: [],
                                    market: .cusdcv3,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice repays with a bridge")
    func testCometRepayWithBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
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
                            fees: [.ethereum: 0.1, .base: 0.2]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cusdcv3,
                    repayAmount: .amt(2, .usdc),
                    collateralAmounts: [.amt(1, .wbtc)],
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .multicall(
                            [
                                .bridge(
                                    bridge: "Across",
                                    srcNetwork: .ethereum,
                                    destinationNetwork: .base,
                                    inputTokenAmount: .amt(3.02, .usdc),
                                    outputTokenAmount: .amt(2, .usdc)
                                ),
                                .quotePay(payment: .amt(0.3, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate),
                        .repayAndWithdrawMultipleAssetsFromComet(
                            repayAmount: .amt(2, .usdc),
                            collateralAmounts: [.amt(1, .wbtc)],
                            market: .cusdcv3,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice repays max USDC with a bridge")
    func testCometRepayMaxWithBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .ethereum),
                    .cometBorrow(.alice, .amt(10, .usdc), .cusdcv3, .base),
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
                            fees: [.ethereum: 0.1, .base: 0.1]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cusdcv3,
                    repayAmount: .max(.usdc),
                    collateralAmounts: [],
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .multicall(
                            [
                                .bridge(
                                    bridge: "Across",
                                    srcNetwork: .ethereum,
                                    destinationNetwork: .base,
                                    inputTokenAmount: .amt(11.1101, .usdc),
                                    outputTokenAmount: .amt(10.01, .usdc)
                                ),
                                .quotePay(payment: .amt(0.2, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate),
                        .repayAndWithdrawMultipleAssetsFromComet(
                            repayAmount: .max(.usdc),
                            collateralAmounts: [],
                            market: .cusdcv3,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice repays max balance USDC with a bridge")
    func testCometRepayMaxBalanceWithBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(10, .usdc), .ethereum),
                    .cometBorrow(.alice, .amt(50, .usdc), .cusdcv3, .base),
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
                            fees: [.ethereum: 0.1, .base: 0.1]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .cometRepay(
                    from: .alice,
                    market: .cusdcv3,
                    repayAmount: .max(.usdc),
                    collateralAmounts: [],
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            // 10
                            inputTokenAmount: .max(.usdc),
                            outputTokenAmount: .amt(8.9, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .repayAndWithdrawMultipleAssetsFromComet(
                                repayAmount: .amt(8.7, .usdc),
                                collateralAmounts: [],
                                market: .cusdcv3,
                                network: .base
                            ),
                            .quotePay(payment: .amt(0.2, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }
}
