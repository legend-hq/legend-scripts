@preconcurrency import Eth
import Testing

@Suite("Morpho Claim Rewards Tests")
struct MorphoClaimRewardsTests {
    @Test("Alice claims USDC and WETH rewards from Morpho, paying with QuotePay")
    func testMorphoClaimRewards() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(1.5, .usdc), .base),
                    .morphoReward(.alice, .amt(1, .weth), .distributor, .validProof1, .ethereum),
                    .morphoReward(.alice, .amt(0.1, .wbtc), .distributor, .validProof2, .ethereum),
                    .morphoReward(.alice, .amt(10, .usdc), .distributor, .validProof3, .base),
                    .quote(.basic),
                ],
                when: .morphoClaimRewards(
                    from: .alice
                ),
                expect: .success(
                    .multi([
                        .claimMorphoRewards(
                            distributors: [.distributor, .distributor], accounts: [.alice, .alice],
                            rewardsClaimable: [.amt(1, .weth), .amt(0.1, .wbtc)],
                            proofs: [.validProof1, .validProof2], network: .ethereum),
                        .multicall([
                            .claimMorphoRewards(
                                distributors: [.distributor], accounts: [.alice],
                                rewardsClaimable: [.amt(10, .usdc)], proofs: [.validProof3],
                                network: .base),
                            .quotePay(
                                payment: .amt(0.12, .usdc), payee: .stax, quote: .basic
                            ),
                        ]),
                    ])
                )
            )
        )
    }

    @Test(
        "Alice claims USDC rewards from Morpho, paying for the operation with the claimed rewards")
    func testMorphoClaimRewardsPayFromWithdraw() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoReward(.alice, .amt(10, .usdc), .distributor, .validProof1, .ethereum),
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
                when: .morphoClaimRewards(
                    from: .alice
                ),
                expect: .success(
                    .single(
                        .multicall([
                            .claimMorphoRewards(
                                distributors: [.distributor], accounts: [.alice],
                                rewardsClaimable: [.amt(10, .usdc)], proofs: [.validProof1],
                                network: .ethereum),
                            .quotePay(
                                payment: .amt(0.5, .usdc), payee: .stax, quote: .basic
                            ),
                        ])
                    )
                )
            )
        )
    }

    @Test(
        "Alice claims USDC rewards from Morpho, but the claimed amount cannot cover the operation cost"
    )
    func testMorphoClaimRewardsCostTooHigh() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .morphoReward(.alice, .amt(3, .usdc), .distributor, .validProof1, .ethereum),
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
                    ),
                ],
                when: .morphoClaimRewards(
                    from: .alice
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
