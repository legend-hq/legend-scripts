@preconcurrency import BigInt
@preconcurrency import Eth

let cometBorrowTests: [AcceptanceTest] = [
    .init(
        name: "Alice tries to supply collateral that she doesn't have (testBorrowFundsUnavailable)",
        given: [
            .quote(.basic),
        ],
        when: .cometBorrow(
            from: .alice,
            market: .cusdcv3,
            borrowAmount: .amt(1, .usdc),
            collateralAmounts: [.amt(1, .link)],
            on: .ethereum
        ),
        expect: .revert(
            .badInputInsufficientFunds(
                Token.link.symbol,
                TokenAmount.amt(1, .link).amount,
                TokenAmount.amt(0, .link).amount
            )
        )
    ),
    .init(
        name: "Alice supplies 1 Link and borrows 1 USDC on mainnet cUSDCv3 (testBorrow)",
        given: [
            .tokenBalance(.alice, .amt(10, .link), .ethereum),
            .quote(.basic),
        ],
        when: .cometBorrow(
            from: .alice,
            market: .cusdcv3,
            borrowAmount: .amt(1, .usdc),
            collateralAmounts: [.amt(1, .link)],
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .supplyMultipleAssetsAndBorrowFromComet(
                        borrowAmount: .amt(1, .usdc),
                        collateralAmounts: [.amt(1, .link)],
                        market: .cusdcv3,
                        network: .ethereum
                    ),
                    .quotePay(
                        payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    .init(
        name: "Alice supplies 10 ETH, which are auto-wrapped to WETH (testBorrowWithAutoWrapper)",
        given: [
            .tokenBalance(.alice, .amt(10, .eth), .ethereum),
            .quote(.basic),
        ],
        when: .cometBorrow(
            from: .alice,
            market: .cusdcv3,
            borrowAmount: .amt(1, .usdc),
            collateralAmounts: [.amt(10, .weth)],
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .wrapAsset(.eth),
                    .supplyMultipleAssetsAndBorrowFromComet(
                        borrowAmount: .amt(1, .usdc),
                        collateralAmounts: [.amt(10, .weth)],
                        market: .cusdcv3,
                        network: .ethereum
                    ),
                    .quotePay(
                        payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),
    // somewhat invalid input, since Alice supplies USDT to cUSDCv3
    .init(
        name: "Alice borrows from Comet, paying with QuotePay (testCometBorrowWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(3, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(5, .link), .base),
            .quote(
                .custom(
                    quoteId: Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 0.1, .base: 1]
                )
            )
        ],
        when: .cometBorrow(
            from: .alice,
            market: .cusdcv3,
            borrowAmount: .amt(1, .usdt),
            collateralAmounts: [.amt(1, .link)],
            on: .base
        ),
        expect: .success(
            .multi([
                .supplyMultipleAssetsAndBorrowFromComet(
                    borrowAmount: .amt(1, .usdt),
                    collateralAmounts: [.amt(1, .link)],
                    market: .cusdcv3,
                    network: .base
                ),
                .quotePay(payment: .amt(1.1, .usdc), payee: .stax, quote: .basic)
            ])
        )
    ),
    .init(
        name: "Alice pays for a QuotePay with USDC she has borrowed (testBorrowPayFromBorrow)",
        given: [
            .tokenBalance(.alice, .amt(10, .link), .ethereum),
            .quote(
                .custom(
                    quoteId: Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 1.5]
                )
            )
        ],
        when: .cometBorrow(
            from: .alice,
            market: .cusdcv3,
            borrowAmount: .amt(2, .usdc),
            collateralAmounts: [.amt(1, .link)],
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .supplyMultipleAssetsAndBorrowFromComet(
                        borrowAmount: .amt(2, .usdc),
                        collateralAmounts: [.amt(1, .link)],
                        market: .cusdcv3,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(1.5, .usdc), payee: .stax, quote: .basic)
                ])
            )
        )
    ),
    // skip: reverts with `Panic`
    .init(
        name: "Alice supplies bridged USDC and borrows against it (testBorrowWithBridgedCollateralAsset)",
        given: [
            .tokenBalance(.alice, .amt(4, .usdc), .ethereum),
            .quote(
                .custom(
                    quoteId: Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
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
        when: .cometBorrow(
            from: .alice,
            market: .cwethv3,
            borrowAmount: .amt(1, .weth),
            collateralAmounts: [.amt(2, .usdc)],
            on: .base
        ),
        expect: .success(
            .multi([
                .multicall([
                    .bridge(
                        bridge: "Across",
                        srcNetwork: .ethereum,
                        destinationNetwork: .base,
                        inputTokenAmount: .amt(2.2, .usdc),
                        outputTokenAmount: .amt(1.178, .usdc)
                    ),
                    .quotePay(payment: .amt(0.3, .usdc), payee: .stax, quote: .basic),
                ]),
                .supplyMultipleAssetsAndBorrowFromComet(
                    borrowAmount: .amt(2, .usdc),
                    collateralAmounts: [.amt(1, .weth)],
                    market: .cusdcv3,
                    network: .base
                )
            ])
        ),
        skip: true
    )
]
