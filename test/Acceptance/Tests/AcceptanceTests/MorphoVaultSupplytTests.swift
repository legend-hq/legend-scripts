@preconcurrency import Eth

let morphoVaultSupplyTests: [AcceptanceTest] = [
    // testMorphoSupplyInsufficientFunds
    // testMorphoSupplyMaxCostTooHigh
    // testMorphoSupplyFundsUnavailable

    .init(
        name: " (testSimpleMorphoVaultSupply)",
        given: [
            .tokenBalance(.alice, .amt(1.5, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1.5, .usdc), .base),
            .quote(.basic)
        ],
        when: .morphoVaultSupply(
            from: .alice,
            amount: .amt(1, .usdc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .depositToMorphoVault(
                        amount: .amt(1, .usdc),
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    // testSimpleMorphoVaultSupplyMax
    // testSimpleMorphoVaultSupplyWithAutoWrapper
    // testMorphoVaultSupplyWithQuotePay
    // testMorphoVaultSupplyWithBridge
    // testMorphoVaultSupplyMaxWithBridge
    // testMorphoVaultSupplyMaxWithBridgeAndQuotePay
    // testMorphoVaultSupplyWithBridgeAndQuotePay
]
