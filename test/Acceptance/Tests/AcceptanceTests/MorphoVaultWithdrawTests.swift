@preconcurrency import Eth
import Testing

@Suite("Morpho Vault Withdraw Tests")
struct MorphoVaultWithdrawTests {
    @Test("Alice withdraws from MorphoVault, paying with QuotePay")
    func testMorphoVaultWithdrawPayingWithQuotepay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(1, .usdc), .base),
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultWithdraw(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(2, .usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .amt(2, .usdc),
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

    @Test("Alice withdraws from MorphoVault, paying the QuotePay with the withdrawn funds")
    func testMorphoVaultWithdrawPayFromWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoVaultSupply(.alice, .amt(2, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultWithdraw(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(2, .usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .amt(2, .usdc),
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

    @Test(
        "Alice withdraws from MorphoVault more than she has supplied",
        .disabled("MorphoVault balance checking not currently implemented"))
    func testMorphoVaultWithdrawMoreThanSupply() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoVaultSupply(.alice, .amt(1, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultWithdraw(
                    from: .alice,
                    vault: .usdc,
                    amount: .amt(5, .usdc),
                    on: .ethereum
                ),
                expect: .revert(
                    .unknownRevert(
                        "MorphoVaultWithdrawError",
                        "Insufficient supply balance"
                    )
                )
            )
        )
    }

    @Test("Alice withdraws max from MorphoVault")
    func testMorphoVaultWithdrawMax() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
                    .quote(.basic),
                ],
                when: .morphoVaultWithdraw(
                    from: .alice,
                    vault: .usdc,
                    amount: .max(.usdc),
                    on: .ethereum
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .withdrawFromMorphoVault(
                                tokenAmount: .max(.usdc),
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

    @Test(
        "Alice withdraws max from MorphoVault, but the withdrawn amount is not enough to cover QuotePay cost"
    )
    func testMorphoVaultWithdrawMaxRevertsMaxCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
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
                            fees: [.ethereum: 100]
                        )
                    ),
                ],
                when: .morphoVaultWithdraw(
                    from: .alice,
                    vault: .usdc,
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
                        0
                    )
                )
            )
        )
    }

    // TODO: bridging tests
}
