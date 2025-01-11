@preconcurrency import Eth

let morphoVaultWithdrawTests: [AcceptanceTest] = [
    .init(
        name: "Alice withdraws from MorphoVault, paying with QuotePay (testMorphoVaultWithdraw + testMorphoVaultWithdrawWithQuotePay)",
        given: [
            .tokenBalance(.alice, .amt(1, .usdc), .ethereum),
            .tokenBalance(.alice, .amt(1, .usdc), .base),
            .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
            .quote(.basic)
        ],
        when: .morphoVaultWithdraw(
            from: .alice,
            vault: .usdc,
            amount: .amt(2, .usdc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .withdrawFromMorphoVault(
                        tokenAmount: .amt(2, .usdc),
                        vault: .usdc,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice withdraws from MorphoVault, paying the QuotePay with the withdrawn funds (testMorphoVaultWithdrawPayFromWithdraw)",
        given: [
            .morphoVaultSupply(.alice, .amt(2, .usdc), .usdc, .ethereum),
            .quote(.basic),
        ],
        when: .morphoVaultWithdraw(
            from: .alice,
            vault: .usdc,
            amount: .amt(2, .usdc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .withdrawFromMorphoVault(
                        tokenAmount: .amt(2, .usdc),
                        vault: .usdc,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    // XXX MorphoVault balance checking not currently implemented
    .init(
        name: "Alice withdraws from MorphoVault more than she has supplied",
        given: [
            .morphoVaultSupply(.alice, .amt(1, .usdc), .usdc, .ethereum),
            .quote(.basic),
        ],
        when: .morphoVaultWithdraw(
            from: .alice,
            vault: .usdc,
            amount: .amt(5, .usdc),
            on: .ethereum
        ),
        expect: .revert(
            .unknownRevert(
                "MorphoVaultWithdrawError",
                "Insufficient supply balance"
            )
        ),
        skip: true
    ),

    .init(
        name: "Alice withdraws max from MorphoVault (testMorphoVaultWithdrawMax)",
        given: [
            .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
            .quote(.basic),
        ],
        when: .morphoVaultWithdraw(
            from: .alice,
            vault: .usdc,
            amount: .max(.usdc),
            on: .ethereum
        ),
        expect: .success(
            .single(
                .multicall([
                    .withdrawFromMorphoVault(
                        tokenAmount: .max(.usdc),
                        vault: .usdc,
                        network: .ethereum
                    ),
                    .quotePay(payment: .amt(0.1, .usdc), payee: .stax, quote: .basic),
                ])
            )
        )
    ),

    .init(
        name: "Alice withdraws max from MorphoVault, but the withdrawn amount is not enough to cover QuotePay cost (testMorphoVaultWithdrawMaxRevertsMaxCostTooHigh)",
        given: [
            .morphoVaultSupply(.alice, .amt(5, .usdc), .usdc, .ethereum),
            .quote(
                .custom(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    prices: Dictionary(
                        uniqueKeysWithValues: Token.knownCases.map { token in
                            (token, token.defaultUsdPrice)
                        }
                    ),
                    fees: [.ethereum: 100]
                )
            ),
        ],
        when: .morphoVaultWithdraw(
            from: .alice,
            vault: .usdc,
            amount: .max(.usdc),
            on: .ethereum
        ),
        expect: .revert(
            .unableToConstructActionIntent(
                false,
                "",
                0,
                "IMPOSSIBLE_TO_CONSTRUCT",
                Token.usdc.symbol,
                0
            )
        )
    ),

    // TODO: bridging tests
]
