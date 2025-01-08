@preconcurrency import Eth

let morphoVaultSupplyTests: [AcceptanceTest] = [
    .init(
        name: "testMorphoVaultSupplyMaxWithBridgeAndQuotePay",
        given: [
            .tokenBalance(.alice, .amt(3.0, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(3.0, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .morphoVaultSupply(from: .alice, vault: .usdc, amount: .max(.usdc), on: .base),
        expect: .success(
            .multi([
                .bridge(
                    bridge: "Across",
                    srcNetwork: .ethereum,
                    destinationNetwork: .base,
                    inputTokenAmount: .amt(3, .usdc),
                    outputTokenAmount: .amt(1.97, .usdc)
                ),
                .multicall([
                    .supplyToMorphoVault(
                        tokenAmount: .amt(4.85, .usdc), vault: .usdc, network: .base
                    ),
                    .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),
    .init(
        name: "Alice supplies max on base, bridging usdc from arbitrum, paying QuotePay with Degen",
        given: [
            .tokenBalance(.alice, .amt(3.0, .usdc), .arbitrum),
            .tokenBalance(.alice, .amt(3.0, .usdc), .base),
            .tokenBalance(.alice, .amt(20.0, .degen), .base),
            .quote(
                .custom(
                    quoteId: "0x00000000000000000000000000000000000000000000000000000000000000CC",
                    prices: [
                        .degen: 0.01
                    ],
                    fees: [
                        .base: 0.01,
                        .arbitrum: 0.02,
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
                    outputTokenAmount: .amt(1.97, .usdc)
                ),
                .multicall([
                    .supplyToMorphoVault(
                        tokenAmount: .amt(4.97, .usdc), vault: .usdc, network: .base
                    ),
                    .quotePay(
                        payment: .amt(3, .degen), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),
]
