@preconcurrency import Eth
import Testing

@Suite("Swap Tests")
struct SwapTests {
    @Test("Alice bridges max and swaps with quote pay")
    func testBridgeSwapMaxWithQuotePaySucceeds() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.alice, .amt(4_005.0, .usdc), .ethereum),
                    .tokenBalance(.alice, .amt(4_005.0, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01),
                ],
                when: .swap(
                    from: .alice, sellAmount: .max(.usdc), buyAmount: .amt(2.0, .weth),
                    exchange: .zeroEx,
                    on: .base),
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
            )
        )
    }
}
