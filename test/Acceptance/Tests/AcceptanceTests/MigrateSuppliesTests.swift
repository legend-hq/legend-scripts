@preconcurrency import Eth
import Testing

@Suite("Migrate Supplies Tests")
struct MigrateSuppliesTests {
    @Test("Alice migrates USDC from Comet to Morpho on same chain, paying with QuotePay")
    func testMigrateFromCometToMorphoWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .amt(5, .usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .amt(5, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(5, .usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .supplyToMorphoVault(
                                tokenAmount: .amt(5, .usdc), vault: .usdc, network: .ethereum
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

    @Test("Alice migrates USDC from Morpho to Comet on same chain, paying with QuotePay")
    func testMigrateFromMorphoToCometWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .morpho(.usdc), amount: .amt(5, .usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .amt(5, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .amt(5, .usdc), vault: .usdc, network: .ethereum
                            ),
                            .supplyToComet(
                                tokenAmount: .amt(5, .usdc), market: .cusdcv3, network: .ethereum
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

    @Test("Alice migrates USDC and supplies some from existing balance")
    func testMigrateByUsingExistingBalance() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .tokenBalance(.alice, .amt(5, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .amt(5, .usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .amt(9, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(5, .usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .supplyToMorphoVault(
                                tokenAmount: .amt(9, .usdc), vault: .usdc, network: .ethereum
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

    @Test("Alice migrates USDC on same chain, paying with withdrawn funds")
    func testMigratePayFromWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .amt(5, .usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .amt(4.9, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(5, .usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .supplyToMorphoVault(
                                tokenAmount: .amt(4.9, .usdc), vault: .usdc, network: .ethereum
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

    @Test("Alice migrates USDC by withdrawing max to supply on same chain, paying with QuotePay")
    func testMigrateByWithdrawingMaxWithQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .amt(10, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc), vault: .usdc, network: .ethereum
                            ),
                            .supplyToMorphoVault(
                                tokenAmount: .amt(10, .usdc), vault: .usdc, network: .ethereum
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

    @Test("Alice migrates USDC by withdrawing max to supply on same chain, paying with withdrawn funds")
    func testMigrateByWithdrawingMaxAndPayWithWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .amt(9.9, .usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc), vault: .usdc, network: .ethereum
                            ),
                            .supplyToMorphoVault(
                                tokenAmount: .amt(9.9, .usdc), vault: .usdc, network: .ethereum
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

    @Test("Alice migrates max USDC to Comet on same chain, paying with withdrawn funds")
    func testMigrateMaxToCometAndPayWithWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc), vault: .usdc, network: .ethereum
                            ),
                            .quotePay(
                                payment: .amt(0.1, .usdc), payee: .stax, quote: .basic
                            ),
                            .supplyToComet(
                                // 9.9
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice migrates max USDC to Morpho on same chain, paying with withdrawn funds")
    func testMigrateMaxToMorphoAndPayWithWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(5, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .ethereum)
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc), vault: .usdc, network: .ethereum
                            ),
                            .quotePay(
                                payment: .amt(0.1, .usdc), payee: .stax, quote: .basic
                            ),
                            .supplyToMorphoVault(
                                // 9.9
                                tokenAmount: .max(.usdc), vault: .usdc, network: .ethereum
                            ),
                        ], executionType: .immediate)
                    )
                )
            )
        )
    }

    @Test("Alice migrates USDC from different chains, bridging withdrawn funds to supply on destination chain")
    func testMigrateFromDifferentChains() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(10, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(10, .usdc), .usdc, .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .amt(10, .usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .amt(10, .usdc), on: .base),
                    ],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .amt(17, .usdc), on: .arbitrum)
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .amt(10, .usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .ethereum,
                                destinationNetwork: .arbitrum,
                                inputTokenAmount: .amt(10, .usdc),
                                // 10 - 1 Across base fee - (10 * .01) Across pct fee = 8.9
                                outputTokenAmount: .amt(8.9, .usdc)
                            ),
                        ], executionType: .immediate),
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .amt(10, .usdc), vault: .usdc, network: .base
                            ),
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .arbitrum,
                                // 10 + 1 Across base fee + (10 * .01) Across pct fee = 9.181
                                inputTokenAmount: .amt(9.181, .usdc),
                                outputTokenAmount: .amt(8.1, .usdc)
                            ),
                            .quotePay(
                                payment: .amt(0.16, .usdc), payee: .stax, quote: .basic
                            ),
                        ], executionType: .immediate),
                        .supplyToComet(
                            tokenAmount: .amt(17, .usdc), market: .cusdcv3, network: .arbitrum, executionType: .contingent
                        ),
                    ])
                )
            )
        )
    }

    @Test("Alice migrates max USDC from different chains, bridging withdrawn funds to supply on destination chain")
    func testMigrateMaxFromDifferentChains() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(10, .usdc), .cusdcv3, .ethereum),
                    .morphoVaultSupply(.alice, .amt(10, .usdc), .usdc, .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                        (from: .alice, market: .morpho(.usdc), amount: .max(.usdc), on: .base),
                    ],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .arbitrum)
                ),
                expect: .success(
                    .multi([
                        .multicall([
                            .withdrawFromComet(
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .ethereum
                            ),
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .ethereum,
                                destinationNetwork: .arbitrum,
                                inputTokenAmount: .amt(10, .usdc),
                                // 10 - 1 Across base fee - (10 * .01) Across pct fee = 8.9
                                outputTokenAmount: .amt(8.9, .usdc)
                            ),
                        ], executionType: .immediate),
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc), vault: .usdc, network: .base
                            ),
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .arbitrum,
                                inputTokenAmount: .amt(10, .usdc),
                                // 10 - 1 Across base fee - (10 * .01) Across pct fee = 8.9
                                outputTokenAmount: .amt(8.9, .usdc)
                            ),
                        ], executionType: .immediate),
                        .multicall([
                            .quotePay(
                                payment: .amt(0.16, .usdc), payee: .stax, quote: .basic
                            ),
                            .supplyToComet(
                                // 17.64
                                tokenAmount: .max(.usdc), market: .cusdcv3, network: .arbitrum
                            ),
                        ], executionType: .contingent),
                    ])
                )
            )
        )
    }

    @Test("Alice migrates, but the withdrawn amount cannot cover the supply")
    func testMigratesButNotEnoughToSupply() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .cometSupply(.alice, .amt(10, .usdc), .cusdcv3, .ethereum),
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [
                        (from: .alice, market: .comet(.cusdcv3), amount: .max(.usdc), on: .ethereum),
                    ],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .amt(11, .usdc), on: .arbitrum)
                ),
                expect: .revert(
                    .badInputInsufficientFunds(
                        Token.usdc.symbol,
                        TokenAmount.amt(11, .usdc).amount,
                        TokenAmount.amt(10, .usdc).amount
                    )
                )
            )
        )
    }

    @Test("Alice migrates, but the withdrawn amount cannot cover the operation cost")
    func testMigratesButWithdrawCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .quote(.basic),
                ],
                when: .migrateSupplies(
                    withdraw: [],
                    supply: (from: .alice, market: .comet(.cusdcv3), amount: .amt(0, .usdc), on: .arbitrum)
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
