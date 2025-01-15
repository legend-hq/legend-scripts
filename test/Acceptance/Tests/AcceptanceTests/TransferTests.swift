@preconcurrency import BigInt
@preconcurrency import Eth
import Testing

@Suite("Transfer Tests")
struct TransferTests {
    @Test("Alice transfers 10 USDC to Bob on Ethereum")
    func testTransferUsdcToBobEthereum() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(100, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                            .quotePay(payment: .amt(0.10, .usdc), payee: .stax, quote: .basic),
                        ])
                    )
                )
            )
        )
    }

    @Test("Alice transfers 10 USDC to Bob on Arbitrum")
    func testTransferUsdcToBobArbitrum() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
                    .quote(.basic),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(10, .usdc), on: .arbitrum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                            .quotePay(payment: .amt(0.04, .usdc), payee: .stax, quote: .basic),
                        ])
                    )
                )
            )
        )
    }

    @Test("Alice attempts to transfer MAX USDC to Bob on Arbitrum")
    func testTransferMaxUsdcToBobArbitrum() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
                    .quote(.basic),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum
                ),
                expect: .revert(
                    .unableToConstructActionIntent(
                        false,
                        "",
                        0,
                        "UNABLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0.04, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice attempts to transfer perceived MAX USDC to Bob on Arbitrum via Bridge")
    func testTransferMaxUsdcViaBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum
                ),
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
            )
        )
    }

    @Test("Alice transfers MAX USDC (uint256.max) to Bob on Arbitrum via Bridge")
    func testTransferMaxUsdcUint256ViaBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .max(.usdc), on: .arbitrum
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .base,
                            destinationNetwork: .arbitrum,
                            inputTokenAmount: .amt(50, .usdc),
                            outputTokenAmount: .amt(48.5, .usdc)
                        ),
                        .multicall([
                            .transferErc20(tokenAmount: .amt(98.44, .usdc), recipient: .bob),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ]),
                    ])
                )
            )
        )
    }

    @Test("Alice transfers MAX USDC (uint256.max) to Bob on Arbitrum via Bridge")
    func testTransferMaxUsdcUint256ViaBridgeBackwards() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .max(.usdc), on: .base
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .arbitrum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(50, .usdc),
                            outputTokenAmount: .amt(48.5, .usdc)
                        ),
                        .multicall([
                            .transferErc20(tokenAmount: .amt(98.44, .usdc), recipient: .bob),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ]),
                    ])
                )
            )
        )
    }

    @Test("Alice bridges sumSrcBalance via Across when inputAmount > sumSrcBalance")
    func testBridgeSumSrcBalance() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(99, .usdc), on: .arbitrum
                ),
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
            )
        )
    }

    @Test("Alice transfers 75 USDC to Bob on Arbitrum via Bridge without all quotes")
    func testTransfer75UsdcViaBridgeWithoutAllQuotes() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
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
                                .arbitrum: 0.04
                            ]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(75, .usdc), on: .arbitrum
                ),
                expect: .revert(
                    .maxCostMissingForChain(BigUInt(Network.base.chainId))
                )
            )
        )
    }

    @Test("Alice transfers USDC to Bob on Arbitrum via Bridge")
    func testTransferUsdcToBobViaBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .transfer(
                    from: .alice, to: .bob, amount: .amt(98, .usdc), on: .arbitrum
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .arbitrum,
                                inputTokenAmount: .amt(49.48, .usdc),
                                outputTokenAmount: .amt(48.00, .usdc)
                            ),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ]),
                        .transferErc20(tokenAmount: .amt(98, .usdc), recipient: .bob),
                    ])
                )
            )
        )
    }

    @Test("Alice transfers WETH to Bob on Arbitrum via Across [Pay with WETH]")
    func testTransferWethAndPayWithWeth() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0.5, .weth), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(0.01, .weth), 0.01),
                ],
                when: .payWith(
                    currency: .weth,
                    .transfer(from: .alice, to: .bob, amount: .amt(0.3, .weth), on: .arbitrum)
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .arbitrum,
                                inputTokenAmount: .amt(0.313, .weth),
                                outputTokenAmount: .amt(0.3, .weth)
                            ),
                            // Total quote = 0.02 + 0.04 = 0.06
                            // Amount in terms of ETH = 0.06 / 4000 = 0.000015
                            .quotePay(payment: .amt(0.000015, .weth), payee: .stax, quote: .basic),
                        ]),
                        .transferErc20(tokenAmount: .amt(0.3, .weth), recipient: .bob),
                    ])
                )
            )
        )
    }

    @Test("Alice transfers all of Base USDC to Bob on Arbitrum via Bridge")
    func transferMaxUsdcViaBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(100, .usdc), .base),
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
                            inputTokenAmount: .amt(100, .usdc),
                            outputTokenAmount: .amt(98.00, .usdc)
                        ),
                        .multicall([
                            // Bridge 100 -> 98 arrives on arbitrum - 0.06 quote pay -> 97.94 USDC transfer
                            .transferErc20(tokenAmount: .amt(97.94, .usdc), recipient: .bob),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ]),
                    ])
                )
            )
        )
    }

}
