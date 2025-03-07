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
                        .multicall(
                            [
                                .transferErc20(
                                    tokenAmount: .amt(10, .usdc), recipient: .bob,
                                    network: .ethereum),
                                .quotePay(payment: .amt(0.10, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
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
                        .multicall(
                            [
                                .transferErc20(
                                    tokenAmount: .amt(10, .usdc), recipient: .bob,
                                    network: .arbitrum),
                                .quotePay(payment: .amt(0.04, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice transfers 10 USDC to Bob on Optimism")
    func testTransferUsdcToBobOptimism() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(100, .usdc), .optimism),
                    .quote(.basic),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .optimism),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .transferErc20(
                                    tokenAmount: .amt(10, .usdc), recipient: .bob,
                                    network: .optimism),
                                .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate
                        )
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
                    .unableToConstructQuotePay(
                        "UNABLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(0.04, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice attempts to transfer perceived MAX USDC to Bob on Arbitrum via Bridge")
    func testTransferPerceivedMaxUsdcViaBridge() async throws {
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
                    .unableToConstructBridge(
                        Token.usdc.symbol,
                        TokenAmount.amt(1.5, .usdc).amount
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
                            // 50
                            inputTokenAmount: .max(.usdc),
                            outputTokenAmount: .amt(48.5, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                            .transferErc20(
                                // 98.44
                                tokenAmount: .max(.usdc), recipient: .bob, network: .arbitrum
                            ),
                        ], executionType: .contingent),
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
                    .unableToConstructBridge(
                        Token.usdc.symbol,
                        TokenAmount.amt(1.5, .usdc).amount
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
                        ], executionType: .immediate),
                        .transferErc20(
                            tokenAmount: .amt(98, .usdc), recipient: .bob, network: .arbitrum, executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice transfers ETH. WETH is unwrapped and ETH is transferred")
    func testTransferETH() async throws {
        try await testAcceptanceTests(
            test:  .init(
                given: [
                    .tokenBalance(.alice, .amt(0.5, .eth), .base),
                    .tokenBalance(.alice, .amt(0.2, .weth), .base),
                    .tokenBalance(.alice, .amt(5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(0.7, .eth), on: .base),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .unwrapWETHUpTo(
                                    tokenAmount: .amt(0.7, .weth)
                                ),
                                .transferNativeToken(
                                    tokenAmount: .amt(0.7, .eth),
                                    recipient: .bob,
                                    network: .base
                                ),
                                .quotePay(payment: .amt(0.02, .usdc), payee: .stax, quote: .basic)
                            ],
                            executionType: .immediate
                        )
                    )
                )
            )
        )
    }

    @Test("Alice transfers ETH over bridge. WETH is unwrapped and ETH is transferred")
    func testTransferETHOverBridge() async throws {
        try await testAcceptanceTests(
            test:  .init(
                given: [
                    .tokenBalance(.alice, .amt(0.8, .eth), .base),
                    .tokenBalance(.alice, .amt(5, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(0.01, .weth), 0.01),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(0.7, .eth), on: .arbitrum),
                expect: .success(
                    .multi(
                        [
                            .multicall(
                                [
                                    .bridge(
                                        bridge: "Across",
                                        srcNetwork: .base,
                                        destinationNetwork: .arbitrum,
                                        inputTokenAmount: .amt(0.717, .eth),
                                        outputTokenAmount: .amt(0.7, .eth)
                                    ),
                                    .quotePay(
                                        payment: .amt(0.06, .usdc),
                                        payee: .stax,
                                        quote: .basic
                                    )
                                ],
                                executionType: .immediate
                            ),
                            .multicall(
                                [
                                    .unwrapWETHUpTo(
                                        tokenAmount: .amt(0.7, .weth)
                                    ),
                                    .transferNativeToken(
                                        tokenAmount: .amt(0.7, .eth),
                                        recipient: .bob,
                                        network: .arbitrum
                                    )
                                ],
                                executionType: .contingent
                            ),
                        ]
                    )
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
                        ], executionType: .immediate),
                        .multicall([
                            .wrapAsset(.eth),
                            .transferErc20(
                                tokenAmount: .amt(0.3, .weth), recipient: .bob, network: .arbitrum),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice transfers all of Base USDC to Bob on Arbitrum via Bridge")
    func testTransferMaxUsdcViaBridge() async throws {
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
                            // 100
                            inputTokenAmount: .max(.usdc),
                            outputTokenAmount: .amt(98.00, .usdc),
                            executionType: .immediate
                        ),
                        .multicall([
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                            // Bridge 100 -> 98 arrives on arbitrum - 0.06 quote pay -> 97.94 USDC transfer
                            .transferErc20(
                                tokenAmount: .max(.usdc), recipient: .bob, network: .arbitrum
                            ),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test(
        "Alice transfers MAX USDC (with uint256.max) to Bob on Arbitrum via Bridge, but some funds are unbridgeable"
    )
    func testTransferMaxWithSomeUnbridgeableFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuoteWithMin(.amt(1, .usdc), 0.01, .amt(51, .usdc)),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .max(.usdc), on: .arbitrum),
                expect: .success(
                    .multi([
                        // Only 50 USDC is transferred because the other 50 USDC is unbridgeable (bridge min is 51 USDC).
                        // Payment is made on Base, where there are unbridgeable funds
                        .transferErc20(
                            // 50
                            tokenAmount: .max(.usdc), recipient: .bob, network: .arbitrum, executionType: .immediate),
                        .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic, executionType: .immediate),
                    ])
                )
            )
        )
    }

    @Test(
        "Alice transfers to Bob on Arbitrum via Bridge, with bridge amount adjusted to be the min bridge amount"
    )
    func testTransferAdjustingBridgeAmountToMin() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(50, .usdc), .base),
                    .quote(.basic),
                    .acrossQuoteWithMin(.amt(0.1, .usdc), 0.01, .amt(0.5, .usdc)),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(50.1, .usdc), on: .arbitrum),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .arbitrum,
                                // Normally would bridge 0.1, but bridge min is 0.5
                                inputTokenAmount: .amt(0.5, .usdc),
                                outputTokenAmount: .amt(0.395, .usdc)
                            ),
                            .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate),
                        .transferErc20(
                            tokenAmount: .amt(50.1, .usdc), recipient: .bob, network: .arbitrum, executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test(
        "Alice transfers to Bob on Arbitrum via Bridge, when total paymentFees > unbridgeableAmount"
    )
    func testTransferWithBridgeWithPaymentFeesGtUnbridgeableAmount() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
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
                            fees: [.arbitrum: 40, .base: 5]
                        )),
                    .acrossQuoteWithMin(.amt(0.1, .usdc), 0.01, .amt(50, .usdc)),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(20, .usdc), on: .arbitrum),
                expect: .revert(
                    // There is no way to construct a valid transfer of 20 USDC
                    .unableToConstructQuotePay(
                        "UNABLE_TO_CONSTRUCT",
                        Token.usdc.symbol,
                        TokenAmount.amt(40, .usdc).amount
                    )
                )
            )
        )
    }

    @Test(
        "Alice transfers MAX to Bob on Arbitrum via Bridge, when total paymentFees > unbridgeableAmount"
    )
    func testTransferMaxWithBridgeWithPaymentFeesGtUnbridgeableAmount() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
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
                            fees: [.arbitrum: 40, .base: 5]
                        )),
                    .acrossQuoteWithMin(.amt(0.1, .usdc), 0.01, .amt(50, .usdc)),
                ],
                when: .transfer(from: .alice, to: .bob, amount: .max(.usdc), on: .arbitrum),
                expect: .success(
                    .single(
                        .multicall([
                            .quotePay(payment: .amt(40, .usdc), payee: .stax, quote: .basic),
                            // Only 10 USDC is available to transfer since payment has to be made on Arbitrum
                            // due to unbridgeable funds on Base
                            .transferErc20(
                                // 10
                                tokenAmount: .max(.usdc), recipient: .bob, network: .arbitrum),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

}
