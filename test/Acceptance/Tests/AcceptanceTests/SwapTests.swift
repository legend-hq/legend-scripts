@preconcurrency import Eth

let swapTests: [AcceptanceTest] = [
    .init(
        name: "testBridgeSwapMaxWithQuotePaySucceeds",
        given: [
            .tokenBalance(.alice, .amt(4_005.0, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(4_005.0, .usdc), .base),
            .quote(.basic),
            .acrossQuote(.amt(1, .usdc), 0.01),
        ],
        when: .swap(from: .alice, sellAmount: .max(.usdc), buyAmount: .amt(2.0, .weth), exchange: .zeroEx, on: .base),
        expect: .success(
            .multi([
                .bridge(
                    bridge: "Across",
                    srcNetwork: .ethereum,
                    destinationNetwork: .base,
                    inputTokenAmount: .amt(4_005.0, .usdc),
                    outputTokenAmount: .amt(3_963.95, .usdc)
                ),
                .multicall([
                    .swap(
                        sellAmount: .amt(7_968.83, .usdc), 
                        buyAmount: .amt(2.0, .weth), 
                        exchange: .zeroEx, 
                        network: .base
                    ),
                    .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                ]),
            ])
        )
    ),
]