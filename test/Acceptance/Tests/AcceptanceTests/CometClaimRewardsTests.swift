@preconcurrency import Eth

let cometClaimRewardsTests: [AcceptanceTest] = [
    .init(
        name: "Alice claims USDC and WETH rewards from Comet, paying with QuotePay (testCometClaimRewards + testCometClaimRewardsWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(1.5, .usdc), .base),
            .cometReward(.alice, .amt(10, .usdc), .cusdcv3, .usdcReward, .base),
            .cometReward(.alice, .amt(1, .weth), .cwethv3, .wethReward, .ethereum),
            .quote(.basic)
        ],
        when: .cometClaimRewards(
            from: .alice
        ),
        expect: .success(
            .multi([
                .claimCometRewards(cometRewards: [.wethReward], comets: [.cwethv3], accounts: [.alice], network: .ethereum),
                .multicall([
                    .claimCometRewards(cometRewards: [.usdcReward], comets: [.cusdcv3], accounts: [.alice], network: .base),
                    .quotePay(
                        payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                ])
            ])
        )
    ),
    .init(
        name: "Alice claims USDC rewards from Comet, paying for the operation with the claimed rewards (testCometClaimRewardsPayFromWithdraw)",
        given: [
            .cometReward(.alice, .amt(10, .usdc), .cusdcv3, .usdcReward, .ethereum),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: [Token.usdc: 1.0],
                    fees: [
                        .ethereum: 0.5,
                    ]
                )
            ),
        ],
        when: .cometClaimRewards(
            from: .alice
        ),
        expect: .success(
            .single(
                .multicall([
                    .claimCometRewards(cometRewards: [.usdcReward], comets: [.cusdcv3], accounts: [.alice], network: .ethereum),
                    .quotePay(
                        payment: .amt(0.5, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    .init(
        name: "Alice claims USDC rewards from Comet, but the claimed amount cannot cover the operation cost (testCometClaimRewardsCostTooHigh)",
        given: [
            .cometReward(.alice, .amt(3, .usdc), .cusdcv3, .usdcReward, .ethereum),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: [Token.usdc: 1.0],
                    fees: [
                        .ethereum: 5
                    ]
                )
            ),
        ],
        when: .cometClaimRewards(
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
]
