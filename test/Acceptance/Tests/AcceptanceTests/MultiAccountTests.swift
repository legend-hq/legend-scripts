@preconcurrency import Eth
import Testing

@Suite("Multi Account Tests Tests")
struct MultiAccountTests {
    @Test("Alice transfers 10 USDC to Bob on Ethereum by sourcing founds from Carl on Base")
    func testMultiAccountTransferWithBridgeAndQuotePay() async throws {
        try await testAcceptanceTests(
            test: .init(
                given: [
                    .tokenBalance(.carl, .amt(100, .usdc), .base),
                    .quote(.basic),
                    .acrossQuote(.amt(1, .usdc), 0.01)
                ],
                when: .transfer(from: .alice, to: .bob, amount: .amt(10, .usdc), on: .ethereum),
                expect: .success(
                    .multi([
                        .multicall([
                            .bridge(
                                bridge: "Across",
                                srcNetwork: .base,
                                destinationNetwork: .ethereum,
                                inputTokenAmount: .amt(11.1, .usdc),
                                outputTokenAmount: .amt(10, .usdc)
                            ),
                            .quotePay(payment: .amt(0.12, .usdc), payee: .stax, quote: .basic),
                        ], executionType: .immediate),
                        .transferErc20(
                                tokenAmount: .amt(10, .usdc), recipient: .bob, network: .ethereum, executionType: .contingent)
                    ])
                )
            )
        )
    }
}
