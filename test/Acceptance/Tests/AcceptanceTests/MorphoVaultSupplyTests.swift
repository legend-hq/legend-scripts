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
]
