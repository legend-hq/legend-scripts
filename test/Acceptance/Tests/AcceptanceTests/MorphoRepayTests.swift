@preconcurrency import Eth

let morphoRepayTests: [AcceptanceTest] = [
    .init(
        name: "Alice tries to repay with funds she doesn't have (testMorphoRepayFundsUnavailable)",
        given: [.quote(.basic)],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(1, .usdc),
            collateralAmount: .amt(1, .wbtc),
            on: .ethereum
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(1, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice tries to repay Morpho balance, but does not have enough USDC for QuotePay (testMorphoRepayMaxCostTooHigh)",
        given: [
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.base: 0.5]
                )
            ),
            .tokenBalance(.alice, .amt(0.4, .usdc), .base),
            .tokenBalance(.alice, .amt(1, .weth), .base),
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(1, .weth),
            collateralAmount: .amt(1, .cbeth),
            on: .base
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.5, .usdc).amount
            )
        )
    ),

    .init(
        name: "Alice repays Morpho borrow (testMorphoRepay)",
        given: [
            .tokenBalance(.alice, .amt(1.1, .usdc), .ethereum),
            .quote(.basic)
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(1, .usdc),
            collateralAmount: .amt(1, .wbtc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .repayAndWithdrawCollateralFromMorpho(
                        repayAmount: .amt(1, .usdc),
                        collateralAmount: .amt(1, .wbtc),
                        market: .morpho(.wbtc, .usdc),
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice repays MorphoBorrow of WETH with ETH (testMorphoRepayWithAutoWrapper)",
        given: [
            .tokenBalance(.alice, .amt(1, .eth), .base),
            .tokenBalance(.alice, .amt(1, .usdc), .base),
            .quote(.basic)
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(1, .weth),
            collateralAmount: .amt(0, .cbeth),
            on: .base
        ),
        expect: .success(
            .single(
                .multicall([
                    .wrapAsset(.eth),
                    .repayAndWithdrawCollateralFromMorpho(
                        repayAmount: .amt(1, .weth),
                        collateralAmount: .amt(0, .cbeth),
                        market: .morpho(.cbeth, .weth),
                        network: .base
                    ),
                    .quotePay(payment: .amt(0.02, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice repays Morpho borrow, paying with QuotePay (testMorphoRepayWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(2, .usdc), .ethereum),
            .quote(.basic)
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(1, .usdc),
            collateralAmount: .amt(0, .wbtc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .repayAndWithdrawCollateralFromMorpho(
                        repayAmount: .amt(1, .usdc),
                        collateralAmount: .amt(0, .wbtc),
                        market: .morpho(.wbtc, .usdc),
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice repays Morpho borrow on Base with funds bridged from Ethereum (testMorphoRepayWithBridge)",
        given: [
            .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [
                        .ethereum: 0.1,
                        .base: 0.2,
                    ]
                )
            ),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .amt(2, .usdc),
            collateralAmount: .amt(0, .weth),
            on: .base
        ),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .ethereum,
                        destinationNetwork: .base,
                        // 2 USDC bridged + 1 USDC Across fee + (2 * 0.01) Across pct fee = 3.02
                        inputTokenAmount: .amt(3.02, .usdc),
                        outputTokenAmount: .amt(2, .usdc)
                    ),
                    // one mainnet operation (0.1) + one base operation (0.2)
                    .quotePay(payment: .amt(0.3, .usdc), payee: .stax, quote: .basic),
                ]),
                .repayAndWithdrawCollateralFromMorpho(
                    repayAmount: .amt(2, .usdc),
                    collateralAmount: .amt(0, .weth),
                    market: .morpho(.weth, .usdc),
                    network: .base
                )
            ])
        )
    ),

    .init(
        name: "Alice repays max Morpho borrow (testMorphoRepayMax)",
        given: [
            .tokenBalance(.alice, .amt(20, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .max(.usdc),
            collateralAmount: .amt(0, .wbtc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .repayAndWithdrawCollateralFromMorpho(
                        repayAmount: .max(.usdc),
                        collateralAmount: .amt(0, .wbtc),
                        market: .morpho(.wbtc, .usdc),
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice repays max Morpho borrow on Base with funds bridged from Ethereum (testMorphoRepayMaxWithBridge)",
        given: [
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [
                        .ethereum: 0.1,
                        .base: 0.1,
                    ]
                )
            ),
            .acrossQuote(.amt(1, .usdc), 0.01),
            .tokenBalance(.alice, .amt(50, .usdc), .ethereum),
            .morphoBorrow(.alice, .amt(10, .usdc), .amt(1, .weth), .base)
        ],
        when: .morphoRepay(
            from: .alice,
            repayAmount: .max(.usdc),
            collateralAmount: .amt(0, .weth),
            on: .base
        ),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .ethereum,
                        destinationNetwork: .base,
                        // amount to bridge = 10 + 1% max repay buffer (10.01)
                        // + 1 (Across fixed fee)
                        // + .01% * amount to bridge (Across pct fee)
                        // = 11.1101
                        inputTokenAmount: .amt(11.1101, .usdc),
                        // 10 + 1% max repay buffer
                        outputTokenAmount: .amt(10.01, .usdc)
                    ),
                    // one mainnet operation (0.1) + one base operation (0.1)
                    .quotePay(payment: .amt(0.2, .usdc), payee: .stax, quote: .basic),
                ]),
                .repayAndWithdrawCollateralFromMorpho(
                    repayAmount: .max(.usdc),
                    collateralAmount: .amt(0, .weth),
                    market: .morpho(.weth, .usdc),
                    network: .base
                )
            ])
        )
    )
]
