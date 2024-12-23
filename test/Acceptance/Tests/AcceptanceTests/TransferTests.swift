@preconcurrency import BigInt
@preconcurrency import Eth

let transferTests: [AcceptanceTest] = [
    .init(
        name: "Alice transfers 10 USDC to Bob on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.10, .usdc), payee: .stax, quote: .basic),
                ])))
    ),
    .init(
        name: "Alice transfers 10 USDC to Bob on Arbitrum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .arbitrum),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.04, .usdc), payee: .stax, quote: .basic),
                ])))
    ),
    .init(
        name: "Alice attempts transfers MAX USDC to Bob on Arbitrum",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .arbitrum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                Token.usdc.symbol,
                0,
                "UNABLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                TokenAmount.amt(0.04, .usdc).amount
            )
        )
    ),
    .init(
        name: "Alice attempts to transfers perceived MAX USDC to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(100, .usdc), on: .arbitrum),
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
    ),
    .init(
        name: "Alice transfers MAX USDC (with uint256.max) to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
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
                    inputTokenAmount: .amt(50, .usdc),
                    outputTokenAmount: .amt(48.5, .usdc)
                ),
                .multicall([
                    .transferErc20(tokenAmount: .amt(98.44, .usdc), recipient: .bob),
                    .quotePay(payment: .amt(0.06, .usdc), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),
    .init(
        name: "Alice bridges sumSrcBalance via Across when inputAmount > sumSrcBalance",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(99, .usdc), on: .arbitrum),
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
    ),
    .init(
        name:
            "Alice attempts to transfers 75 USDC to Bob on Arbitrum via Bridge but doesn't have all the quotes",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
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
                        .arbitrum: 0.04
                    ]
                )
            ),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(75, .usdc), on: .arbitrum),
        expect: .revert(
            .maxCostMissingForChain(BigUInt(Network.base.chainId))
        )
    ),
    .init(
        name: "Alice transfers USDC to Bob on Arbitrum via Bridge",
        given: [
            .tokenBalance(.alice, .amt(50, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(50, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(98, .usdc), on: .arbitrum),
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
    ),
    .init(
        name: "Alice transfers WETH to Bob on Arbitrum via Across [Pay with WETH]",
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
                    .quotePay(payment: .amt(0.000015000000000037, .weth), payee: .stax, quote: .basic),
                ]),
                .transferErc20(tokenAmount: .amt(0.3, .weth), recipient: .bob),
            ])
        )
    ),
    .init(
        name:
            "WIP: Alice repays 75 USDC of a 100 USDC borrow against 0.3 WETH on cUSDCv3 on Ethereum",
        given: [
            .tokenBalance(.alice, .amt(0.5, .weth), .ethereum),
            .cometSupply(.alice, .amt(0.3, .weth), .cusdcv3, .ethereum),
            .cometBorrow(.alice, .amt(100, .usdc), .cusdcv3, .ethereum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(50, .usdc), on: .arbitrum),
        // FIXME: this should not revert! borrowed funds should be added to token balance
        expect: .revert(
            .badInputInsufficientFunds(
                Token.usdc.symbol,
                TokenAmount.amt(50, .usdc).amount,
                TokenAmount.amt(0, .usdc).amount
            )
        )
    ),
]
