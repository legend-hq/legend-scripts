@preconcurrency import Eth
import Testing

@Suite("Morpho Vault Supply Tests")
struct MorphoVaultSupplyTests {
    @Test("Alice supplies max with bridge and QuotePay")
    func testMorphoVaultSupplyMaxWithBridgeAndQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3.0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(3.0, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice, vault: .usdc, amount: .max(.usdc), on: .base),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(3, .usdc),
                            outputTokenAmount: .amt(1.97, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(4.85, .usdc), vault: .usdc, network: .base
                                ),
                                .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies max on base, bridging usdc from arbitrum, paying QuotePay with Degen")
    func testMorphoVaultSupplyMaxWithDegenQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3.0, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(3.0, .usdc), .base),
                    .tokenBalance(.alice, .amt(20.0, .degen), .base),
                    .quote(
                        .custom(
                            quoteId:
                                "0x00000000000000000000000000000000000000000000000000000000000000CC",
                            prices: [
                                .degen: 0.01
                            ],
                            fees: [
                                .base: 0.02,
                                .arbitrum: 0.04,
                            ])
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .payWith(
                    currency: .degen,
                    .morphoVaultSupply(from: .alice, vault: .usdc, amount: .max(.usdc), on: .base)),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .arbitrum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(3, .usdc),
                            outputTokenAmount: .amt(1.97, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(4.97, .usdc), vault: .usdc, network: .base
                                ),
                                .quotePay(
                                    // Slightly larger than 6 since quark builder adds a small buffer
                                    payment: .amt(6, .degen), payee: .stax, quote: .basic),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault more than she has")
    func testMorphoSupplyInsufficientFunds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(2, .usdc),
                    on: .ethereum
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

    @Test("Alice supplies to MorphoVault, but the operation cost is too high")
    func testMorphoSupplyMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .usdc), .base),
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
                                .ethereum: 1000,
                                .base: 0.1,
                            ]
                        )
                    ),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
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
                        TokenAmount.amt(1000.1, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault, but her funds are on an unreachable chain (7777)")
    func testMorphoSupplyFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(0, .usdc), .base),
                    .tokenBalance(.alice, .amt(100, .usdc), .unknown(7777)),
                    .quote(.basic),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(2, .usdc),
                    on: .ethereum
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

    @Test("Alice supplies max on base, bridging USDC from arbitrum and paying with Degen")
    func testMorphoVaultSupplyMaxWithDegen() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3.0, .usdc), .arbitrum),
                    .tokenBalance(.alice, .amt(3.0, .usdc), .base),
                    .tokenBalance(.alice, .amt(20.0, .degen), .base),
                    .quote(
                        .custom(
                            quoteId:
                                "0x00000000000000000000000000000000000000000000000000000000000000CC",
                            prices: [
                                .degen: 0.01
                            ],
                            fees: [
                                .base: 0.02,
                                .arbitrum: 0.04,
                            ]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .payWith(
                    currency: .degen,
                    .morphoVaultSupply(from: .alice, vault: .usdc, amount: .max(.usdc), on: .base)
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .arbitrum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(3, .usdc),
                            outputTokenAmount: .amt(1.97, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(4.97, .usdc), vault: .usdc, network: .base
                                ),
                                .quotePay(
                                    payment: .amt(6, .degen), payee: .stax, quote: .basic
                                ),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault but operation cost is too high")
    func testMorphoVaultSupplyMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .usdc), .base),
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
                                .ethereum: 1000,
                                .base: 0.1,
                            ]
                        )
                    ),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
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
                        TokenAmount.amt(1000.1, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault but funds are on an unreachable chain")
    func testMorphoVaultSupplyFundsUnavailable() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(0, .usdc), .base),
                    .tokenBalance(.alice, .amt(100, .usdc), .unknown(7777)),
                    .quote(.basic),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(2, .usdc),
                    on: .ethereum
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

    @Test("Alice supplies to MorphoVault, paying with QuotePay")
    func testSimpleMorphoVaultSupply() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(1, .usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(1, .usdc),
                                    vault: .usdc,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice supplies max to MorphoVault")
    func testSimpleMorphoVaultSupplyMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .max(.usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .base,
                            destinationNetwork: .ethereum,
                            inputTokenAmount: .amt(1.5, .usdc),
                            outputTokenAmount: .amt(0.485, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(1.865, .usdc),
                                    vault: .usdc,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault, converting ETH to WETH")
    func testSimpleMorphoVaultSupplyWithAutoWrapper() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .eth), .ethereum),
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .weth,
                    amount: .amt(1, .weth),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall(
                            [
                                .wrapAsset(.eth),
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(1, .weth),
                                    vault: .weth,
                                    network: .ethereum
                                ),
                                .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault, bridging funds from Ethereum to Base")
    func testMorphoVaultSupplyWithBridge() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(3, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(5, .usdc),
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
                                .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate),
                        .supplyToMorphoVault(
                            tokenAmount: .amt(5, .usdc),
                            vault: .usdc,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies max to MorphoVault, bridging funds")
    func testMorphoVaultSupplyMaxWithBridge() async throws {
        /*
        +3 on Base
        +3 on Ethereum
        -1 for Across gas fee
        -(3 * 0.01) for Across pct fee
        -0.1 for Ethereum operation fee
        -0.02 for Base operation fee
        = 4.85 USDC supplied to MorphoVault
        */
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(3, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .max(.usdc),
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(3, .usdc),
                            outputTokenAmount: .amt(1.97, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(4.85, .usdc),
                                    vault: .usdc,
                                    network: .base
                                ),
                                .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    /*
    +3 on Ethereum
    +3 on Base
    -1 for Across gas fee
    -(3 * .01) for Across pct fee
    -0.5 for Ethereum operation fee
    -0.1 for Base operation fee
    = 4.37 USDC supplied
    */
    @Test("Alice supplies max to MorphoVault, bridging funds and paying with QuotePay")
    func testMorphoVaultSupplyMaxWithBridgeAndQuotePayCustomQuote() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(3, .usdc), .base),
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
                                .ethereum: 0.5,
                                .base: 0.1,
                            ]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .max(.usdc),
                    on: .base
                ),
                expect: .success(
                    .multi([
                        .bridge(
                            bridge: "Across",
                            srcNetwork: .ethereum,
                            destinationNetwork: .base,
                            inputTokenAmount: .amt(3, .usdc),
                            outputTokenAmount: .amt(1.97, .usdc),
                            executionType: .immediate
                        ),
                        .multicall(
                            [
                                .supplyToMorphoVault(
                                    tokenAmount: .amt(4.37, .usdc),
                                    vault: .usdc,
                                    network: .base
                                ),
                                .quotePay(payment: .amt(0.6, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice supplies to MorphoVault, bridging funds and paying with QuotePay")
    func testMorphoVaultSupplyWithBridgeAndQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(3, .usdc), .base),
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
                                .ethereum: 0.5,
                                .base: 0.1,
                            ]
                        )
                    ),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .morphoVaultSupply(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(5, .usdc),
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
                                .quotePay(payment: .amt(0.6, .usdc), payee: .stax, quote: .basic),
                            ], executionType: .immediate),
                        .supplyToMorphoVault(
                            tokenAmount: .amt(5, .usdc),
                            vault: .usdc,
                            network: .base,
                            executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }
}
