@preconcurrency import Eth

let quotePayTests: [AcceptanceTest] = [
    .init(
        name: "Alice pays with QuotePay using USDC",
        given: [
            .tokenBalance(.alice, .amt(100, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob, network: .ethereum),
                    .quotePay(payment: .amt(0.10, .usdc), payee: .stax, quote: .basic),
                ], executionType: .immediate)
            )
        )
    ),
    .init(
        name: "Alice pays with QuotePay using WETH wrapped from ETH",
        given: [
            .tokenBalance(.alice, .amt(1, .eth), .ethereum),
            .tokenBalance(.alice, .amt(10, .usdc), .ethereum),
            .quote(.basic),
        ],
        when: .payWith(
            currency: .weth,
            .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum)
        ),
        expect: .success(
            .single(
                .multicall([
                    .transferErc20(tokenAmount: .amt(10, .usdc), recipient: .bob, network: .ethereum),
                    .wrapAsset(.eth),
                    .quotePay(payment: .amt(0.000025, .weth), payee: .stax, quote: .basic),
                ], executionType: .immediate)
            )
        )
    ),
    .init(
        name: "Alice performs action using WETH while also paying with QuotePay using WETH (should wrap only once)",
        given: [
            .tokenBalance(.alice, .amt(1, .eth), .ethereum),
            .quote(.basic),
        ],
        when: .payWith(
            currency: .weth,
            .transfer(from: .alice, to: .bob, amount: .amt(0.5, .weth), on: .ethereum)
        ),
        expect: .success(
            .single(
                .multicall([
                    .wrapAsset(.eth),
                    .transferErc20(tokenAmount: .amt(0.5, .weth), recipient: .bob, network: .ethereum),
                    .quotePay(payment: .amt(0.000025, .weth), payee: .stax, quote: .basic),
                ], executionType: .immediate)
            )
        )
    ),
    .init(
        name: "Alice does not have enough ETH to cover QuotePay cost after spending it on an action",
        given: [
            .tokenBalance(.alice, .amt(0.5, .eth), .ethereum),
            .quote(.basic),
        ],
        when: .payWith(
            currency: .weth,
            .transfer(from: .alice, to: .bob, amount: .amt(0.5, .weth), on: .ethereum)
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.weth.symbol,
                TokenAmount.amt(0, .weth).amount
            )
        )
    )
]
