@preconcurrency import Eth
import Testing

@Suite("Comet Withdraw Tests")
struct CometWithdrawTests {

    @Test("Alice withdraws 1 LINK from Comet, paying with QuotePay")
    func testCometWithdrawWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .cometWithdraw(
                    from: .alice,
                    market: .cusdcv3,
                    amount: .amt(1, .link),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(1, .link), market: .cusdcv3, network: .ethereum
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

    @Test("Alice withdraws from Comet, paying with the withdrawn funds")
    func testCometWithdrawPayFromWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
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
                    )
                ],
                when: .cometWithdraw(
                    from: .alice,
                    market: .cusdcv3,
                    amount: .amt(1, .usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(1, .usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .quotePay(
                                payment: .amt(0.5, .usdc), payee: .stax, quote: .basic
                            ),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice withdraws max from Comet")
    func testCometWithdrawMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic),
                    .cometSupply(.alice, .amt(1, .usdc), .cusdcv3, .ethereum),
                ],
                when: .cometWithdraw(
                    from: .alice,
                    market: .cusdcv3,
                    amount: .max(.usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
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

    @Test("Alice withdraws, but the withdrawn amount cannot cover the operation cost")
    func testCometWithdrawCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: [Token.usdc: 1.0],
                            fees: [
                                .ethereum: 5
                            ]
                        )
                    )
                ],
                when: .cometWithdraw(
                    from: .alice,
                    market: .cusdcv3,
                    amount: .amt(1, .usdc),
                    on: .ethereum
                ),
                expect: .revert(
                    .unableToConstructActionIntent(
                        false,
                        "",
                        0,
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0, .usdc).amount
                    )
                )
            )
        )
    }

    @Test(
        "Alice withdraws max from Comet, but the withdrawn amount cannot cover the operation cost")
    func testCometWithdrawMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(1, .usdc), .cusdcv3, .ethereum),
                    .quote(
                        .custom(
                            quoteId: Hex(
                                "0x00000000000000000000000000000000000000000000000000000000000000CC"
                            ),
                            prices: [Token.usdc: 1.0],
                            fees: [
                                .ethereum: 100
                            ]
                        )
                    ),
                ],
                when: .cometWithdraw(
                    from: .alice,
                    market: .cusdcv3,
                    amount: .max(.usdc),
                    on: .ethereum
                ),
                expect: .revert(
                    .unableToConstructActionIntent(
                        false,
                        "",
                        0,
                        "IMPOSSIBLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0, .usdc).amount
                    )
                )
            )
        )
    }
}
