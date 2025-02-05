@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation
import SwiftKeccak
import Testing

@testable import Acceptance

let allTests: [AcceptanceTest] = transferTests +
    cometBorrowTests +
    cometClaimRewardsTests +
    cometRepayTests +
    cometSupplyTests +
    cometWithdrawTests +
    morphoBorrowTests +
    morphoRepayTests +
    morphoVaultSupplyTests +
    morphoVaultWithdrawTests +
    swapTests

let tests = allTests.filter { !$0.skip }
let filteredTests = tests.contains { $0.only } ? tests.filter { $0.only } : tests

enum Call: CustomStringConvertible, Equatable {
    case bridge(
        bridge: String,
        srcNetwork: Network,
        destinationNetwork: Network,
        inputTokenAmount: TokenAmount,
        outputTokenAmount: TokenAmount
    )
    case claimCometRewards(cometRewards: [CometReward], comets: [Comet], accounts: [Account], network: Network)
    case transferErc20(tokenAmount: TokenAmount, recipient: Account, network: Network)
    case supplyToComet(tokenAmount: TokenAmount, market: Comet, network: Network)
    case supplyMultipleAssetsAndBorrowFromComet(
        borrowAmount: TokenAmount,
        collateralAmounts: [TokenAmount],
        market: Comet,
        network: Network
    )
    case repayAndWithdrawMultipleAssetsFromComet(
        repayAmount: TokenAmount,
        collateralAmounts: [TokenAmount],
        market: Comet,
        network: Network
    )
    case supplyToMorphoVault(tokenAmount: TokenAmount, vault: MorphoVault, network: Network)
    case withdrawFromMorphoVault(tokenAmount: TokenAmount, vault: MorphoVault, network: Network)
    case swap(
        sellAmount: TokenAmount,
        buyAmount: TokenAmount,
        exchange: Exchange,
        network: Network
    )
    case quotePay(payment: TokenAmount, payee: Account, quote: Quote)
    case repayAndWithdrawCollateralFromMorpho(
        repayAmount: TokenAmount,
        collateralAmount: TokenAmount,
        market: Morpho,
        network: Network
    )
    case supplyCollateralAndBorrowFromMorpho(
        borrowAmount: TokenAmount,
        collateralAmount: TokenAmount,
        market: Morpho,
        network: Network
    )
    case multicall(_ calls: [Call])
    case withdrawFromComet(tokenAmount: TokenAmount, market: Comet, network: Network)
    case wrapAsset(_ token: Token)
    case unknownFunctionCall(String, String, ABI.Value)
    case unknownScriptCall(EthAddress, Hex)

    static let allFunctions: [(String, Hex, [ABI.Function])] = [
        ("AcrossActions", AcrossActions.creationCode, AcrossActions.functions),
        ("TransferActions", TransferActions.creationCode, TransferActions.functions),
        ("Multicall", Multicall.creationCode, Multicall.functions),
        ("QuotePay", QuotePay.creationCode, QuotePay.functions),
        ("WrapperActions", WrapperActions.creationCode, WrapperActions.functions),
        ("MorphoVaultActions", MorphoVaultActions.creationCode, MorphoVaultActions.functions),
        ("ApproveAndSwap", ApproveAndSwap.creationCode, ApproveAndSwap.functions),
    ]

    static func tryDecodeCall(scriptAddress: EthAddress, calldata: Hex, network: Network) -> Call {
        if scriptAddress == getScriptAddress(AcrossActions.creationCode) {
            if let (
                _,
                _,
                _,
                inputToken,
                outputToken,
                inputAmount,
                outputAmount,
                destinationChainId,
                _,
                _,
                _,
                _,
                _,
                _
            ) = try? AcrossActions.depositV3Decode(input: calldata) {
                return .bridge(
                    bridge: "Across",
                    srcNetwork: network,
                    destinationNetwork: Network.fromChainId(BigInt(destinationChainId)),
                    inputTokenAmount: Token.getTokenAmount(
                        amount: inputAmount,
                        network: network,
                        address: inputToken
                    ),
                    outputTokenAmount: Token.getTokenAmount(
                        amount: outputAmount,
                        network: Network.fromChainId(BigInt(destinationChainId)),
                        address: outputToken
                    )
                )
            }
        }

        if scriptAddress == getScriptAddress(TransferActions.creationCode) {
            if let (token, recipient, amount) = try? TransferActions.transferERC20TokenDecode(
                input: calldata)
            {
                return .transferErc20(
                    tokenAmount: Token.getTokenAmount(
                        amount: amount, network: network, address: token
                    ),
                    recipient: Account.from(address: recipient),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(QuotePay.creationCode) {
            if let (payee, paymentToken, quotedAmount, quoteId) = try? QuotePay.payDecode(
                input: calldata)
            {
                return .quotePay(
                    payment: Token.getTokenAmount(
                        amount: quotedAmount, network: network, address: paymentToken
                    ),
                    payee: Account.from(address: payee),
                    quote: Quote.findQuote(quoteId: quoteId, prices: [:], fees: [:])
                )
            }
        }

        if scriptAddress == getScriptAddress(Multicall.creationCode) {
            if let (callContracts, callDatas) = try? Multicall.runDecode(input: calldata) {
                let calls = zip(callContracts, callDatas).map {
                    Call.tryDecodeCall(scriptAddress: $0, calldata: $1, network: network)
                }
                return .multicall(calls)
            }
        }

        if scriptAddress == getScriptAddress(CometClaimRewards.creationCode) {
            if let (cometRewards, comets, accounts) = try? CometClaimRewards.claimDecode(input: calldata) {
                return .claimCometRewards(
                    cometRewards: cometRewards.map {cometRewardAddress in
                        CometReward.from(network: network, address: cometRewardAddress)
                    },
                    comets: comets.map {cometAddress in
                        Comet.from(network: network, address: cometAddress)
                    },
                    accounts: accounts.map {account in
                        Account.from(address: account)
                    },
                    network: network
                )
            } else if let (comet, to, asset, amount) = try? CometSupplyActions.supplyToDecode(
                input: calldata)
            {
                print("supplyTo(\(comet) to: \(to) \(asset) \(amount))")
            } else if let (comet, from, to, asset, amount) =
                try? CometSupplyActions.supplyFromDecode(input: calldata)
            {
                print("supplyFrom(\(comet) from: \(from) to: \(to) \(asset) \(amount))")
            } else if let (comet, assets, amounts) =
                try? CometSupplyActions.supplyMultipleAssetsDecode(input: calldata)
            {
                print("supplyMultipleAssets(\(comet) \(assets) \(amounts))")
            }
        }

        if scriptAddress == getScriptAddress(CometSupplyActions.creationCode) {
            if let (comet, asset, amount) = try? CometSupplyActions.supplyDecode(input: calldata) {
                return .supplyToComet(
                    tokenAmount: Token.getTokenAmount(
                        amount: amount, network: network, address: asset
                    ),
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            } else if let (comet, to, asset, amount) = try? CometSupplyActions.supplyToDecode(
                input: calldata)
            {
                print("supplyTo(\(comet) to: \(to) \(asset) \(amount))")
            } else if let (comet, from, to, asset, amount) =
                try? CometSupplyActions.supplyFromDecode(input: calldata)
            {
                print("supplyFrom(\(comet) from: \(from) to: \(to) \(asset) \(amount))")
            } else if let (comet, assets, amounts) =
                try? CometSupplyActions.supplyMultipleAssetsDecode(input: calldata)
            {
                print("supplyMultipleAssets(\(comet) \(assets) \(amounts))")
            }
        }

        if scriptAddress == getScriptAddress(CometWithdrawActions.creationCode) {
            if let (comet, asset, amount) = try? CometWithdrawActions.withdrawDecode(input: calldata) {
                return .withdrawFromComet(
                    tokenAmount: Token.getTokenAmount(
                        amount: amount, network: network, address: asset
                    ),
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(CometRepayAndWithdrawMultipleAssets.creationCode) {
            if let (comet, assets, amounts, baseAsset, repayAmount) = try? CometRepayAndWithdrawMultipleAssets.runDecode(input: calldata) {
                let collateralAmounts = zip(amounts, assets).map { Token.getTokenAmount(amount: $0, network: network, address: $1) }

                return repayAndWithdrawMultipleAssetsFromComet(
                    repayAmount: Token.getTokenAmount(amount: repayAmount, network: network, address: baseAsset),
                    collateralAmounts: collateralAmounts,
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(CometSupplyMultipleAssetsAndBorrow.creationCode) {
            if let (comet, assets, amounts, baseAsset, borrowAmount) = try? CometSupplyMultipleAssetsAndBorrow.runDecode(input: calldata) {
                let collateralAmounts = zip(amounts, assets).map { Token.getTokenAmount(amount: $0, network: network, address: $1) }
                return supplyMultipleAssetsAndBorrowFromComet(
                    borrowAmount: Token.getTokenAmount(amount: borrowAmount, network: network, address: baseAsset),
                    collateralAmounts: collateralAmounts,
                    market: Comet.from(network: network, address: comet),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(MorphoActions.creationCode) {
            if let (_, marketParams, collateralTokenAmount, borrowTokenAmount) = try? MorphoActions.supplyCollateralAndBorrowDecode(input: calldata) {
                let borrowToken = Token.from(network: network, address: marketParams.loanToken)
                let collateralToken = Token.from(network: network, address: marketParams.collateralToken)

                return .supplyCollateralAndBorrowFromMorpho(
                    borrowAmount: TokenAmount(fromWei: borrowTokenAmount, ofToken: borrowToken),
                    collateralAmount: TokenAmount(fromWei: collateralTokenAmount, ofToken: collateralToken),
                    market: Morpho(collateralToken: collateralToken, borrowToken: borrowToken),
                    network: network
                )
            } else if let (_, marketParams, repayAmount, withdrawAmount) = try? MorphoActions.repayAndWithdrawCollateralDecode(input: calldata) {
                let repayToken = Token.from(network: network, address: marketParams.loanToken)
                let collateralToken = Token.from(network: network, address: marketParams.collateralToken)

                return .repayAndWithdrawCollateralFromMorpho(
                    repayAmount: TokenAmount(fromWei: repayAmount, ofToken: repayToken),
                    collateralAmount: TokenAmount(fromWei: withdrawAmount, ofToken: collateralToken),
                    market: Morpho(collateralToken: collateralToken, borrowToken: repayToken),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(MorphoVaultActions.creationCode) {
            if let (vault, asset, amount) = try? MorphoVaultActions.depositDecode(input: calldata) {
                return .supplyToMorphoVault(
                    tokenAmount: Token.getTokenAmount(amount: amount, network: network, address: asset),
                    vault: MorphoVault.from(network: network, address: vault),
                    network: network
                )
            } else if let (vaultAddress, amount) = try? MorphoVaultActions.withdrawDecode(input: calldata) {
                let vault = MorphoVault.from(network: network, address: vaultAddress);
                guard let tokenAddress = vault.asset(network: network) else {
                    fatalError("No asset for \(vault.description) on network \(network.description)")
                }
                let token = Token.from(
                    network: network,
                    address: tokenAddress
                )

                return .withdrawFromMorphoVault(
                    tokenAmount: TokenAmount(fromWei: amount, ofToken: token),
                    vault: vault,
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(ApproveAndSwap.creationCode) {
            if let (
                to,
                sellToken,
                sellAmount,
                buyToken,
                buyAmount,
                data
            ) = try? ApproveAndSwap.runDecode(input: calldata) {
                return .swap(
                    sellAmount: Token.getTokenAmount(
                        amount: sellAmount,
                        network: network,
                        address: sellToken
                    ),
                    buyAmount: Token.getTokenAmount(
                        amount: buyAmount,
                        network: network,
                        address: buyToken
                    ),
                    exchange: Exchange.from(
                        network: network,
                        address: to,
                        data: data
                    ),
                    network: network
                )
            }
        }

        if scriptAddress == getScriptAddress(WrapperActions.creationCode) {
            if let _ = try? WrapperActions.wrapAllETHDecode(input: calldata) {
                return .wrapAsset(.eth)
            }
        }

        for (name, creationCode, functions) in Call.allFunctions {
            if scriptAddress == getScriptAddress(creationCode) {
                for function in functions {
                    if let value = try? function.decodeInput(input: calldata) {
                        return .unknownFunctionCall(name, function.name, value)
                    }
                }
            }
        }
        return .unknownScriptCall(scriptAddress, calldata)
    }

    var description: String {
        switch self {
        case let .bridge(bridge, chainId, destinationChainId, inputTokenAmount, outputTokenAmount):
            return
                "bridge(\(bridge), \(inputTokenAmount.amount) \(inputTokenAmount.token.symbol) to receive \(outputTokenAmount.amount) \(outputTokenAmount.token.symbol) from \(chainId.description) to \(destinationChainId.description))"
        case let .claimCometRewards(cometRewards, comets, accounts, network):
            return
                "claimCometRewards(claiming from \(cometRewards.map { $0.description }.joined(separator: ", ")) for \(comets.map { $0.description }.joined(separator: ", ")) for \(accounts.map { $0.description }.joined(separator: ", ")) on \(network.description))"
        case let .transferErc20(tokenAmount, recipient, network):
            return
                "transferErc20(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(recipient.description) on \(network.description))"
        case let .quotePay(payment, payee, quoteId):
            return
                "quotePay(\(payment.amount) \(payment.token.symbol) to \(payee.description), quoteId: \(quoteId))"
        case let .supplyToComet(tokenAmount, market, network):
            return
                "supplyToComet(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(market.description) on \(network.description))"
        case let .supplyMultipleAssetsAndBorrowFromComet(borrowAmount, collateralAmounts, market, network):
            let collateralsString = collateralAmounts.map { collateralAmount in
                "\(collateralAmount.amount) \(collateralAmount.token.symbol)"
            }.joined(separator: ",")
            return "supplyMultipleAssetsAndBorrowFromComet(supply [\(collateralsString)] and borrow \(borrowAmount.amount) \(borrowAmount.token.symbol) from \(market.description) on \(network.description) )"
        case let .repayAndWithdrawMultipleAssetsFromComet(
            repayAmount,
            collateralAmounts,
            market,
            network
        ):
            let withdrawString = collateralAmounts.map { collateralAmount in
                "\(collateralAmount.amount) \(collateralAmount.token.symbol)"
            }.joined(separator: ",")
            return "repayAndWithdrawMultipleAssetsFromComet(repay \(repayAmount.amount) \(repayAmount.token.symbol), and withdraw [\(withdrawString)] from \(market.description) on \(network.description))"
        case let .withdrawFromComet(tokenAmount, market, network):
            return
                "withdrawFromComet(\(tokenAmount.amount) \(tokenAmount.token.symbol) from \(market.description) on \(network.description))"
        case let .supplyToMorphoVault(tokenAmount, vault, network):
            return "supplyToMorphoVault(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(vault.description) on \(network.description))"
        case let .withdrawFromMorphoVault(tokenAmount, vault, network):
            return "withdrawFromMorphoVault(\(tokenAmount.amount) \(tokenAmount.token.symbol) to \(vault.description) on \(network.description))"
        case let .swap(sellAmount, buyAmount, _, network):
            return "swap(\(sellAmount.amount) \(sellAmount.token.symbol) for \(buyAmount.amount) \(buyAmount.token.symbol) on \(network.description))"
        case let .multicall(calls):
            return "multicall(\(calls.map { $0.description }.joined(separator: ", ")))"
        case let .wrapAsset(token):
            return "wrapAsset(\(token.symbol))"
        case let .repayAndWithdrawCollateralFromMorpho(repayAmount, collateralAmount, market, network):
            return "repayAndWithdrawCollateralFromMorpho(repay \(repayAmount.amount) \(repayAmount.token.symbol), withdraw \(collateralAmount.amount) \(collateralAmount.token.symbol) from \(market.description) on \(network.description))"
        case let .supplyCollateralAndBorrowFromMorpho(borrowAmount, collateralAmount, market, network):
            return "supplyCollateralAndBorrowFromMorpho(borrow \(borrowAmount.amount) \(borrowAmount.token.symbol), supply \(collateralAmount.amount) \(collateralAmount.token.symbol) from \(market.description) on \(network.description))"
        case let .unknownFunctionCall(name, function, value):
            return "unknownFunctionCall(\(name), \(function), \(value))"
        case let .unknownScriptCall(scriptSource, calldata):
            return "unknownScriptCall(\(scriptSource.description), \(calldata.description))"
        }
    }

    var descriptionExt: String {
        switch self {
        case let .multicall(calls):
            return
                "multicall:\n\(calls.map { "\n\t\t\t- \($0.descriptionExt)" }.joined(separator: "\n"))\n"
        default:
            return description
        }
    }
}

extension Array where Element == Call {
    var descriptionExt: String {
        if count == 1 {
            return self[0].descriptionExt
        } else {
            return "multi operation:\n\(map { "\n\t\t- \($0.descriptionExt)" }.joined(separator: "\n"))\n"
        }
    }
}

func getScriptAddress(_ creationCode: Hex) -> EthAddress {
    // Create2 address calculation according to EIP-1014
    // address = keccak256(0xff ++ deployingAddress ++ salt ++ keccak256(bytecode))[12:]
    let codeJarAddress = EthAddress("0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8")

    // Pack the data according to create2 spec:
    // 1. 0xff - prevents collision with create
    // 2. deploying contract address
    // 3. salt (32 bytes of 0 in this case)
    // 4. keccak256 hash of initialization code
    var packed = Data()
    packed.append(Data([0xFF])) // prefix byte
    packed.append(codeJarAddress.data) // deploying address
    packed.append(Data(repeating: 0, count: 32)) // salt
    packed.append(SwiftKeccak.keccak256(creationCode.data)) // hash of init code

    // Take keccak256 hash and extract last 20 bytes for address
    let hash = SwiftKeccak.keccak256(packed)
    return EthAddress(Hex(hash.subdata(in: 12 ..< 32)))!
}

enum Account: Hashable, Equatable {
    case alice
    case bob
    case stax
    case unknownAccount(EthAddress)

    static let knownCases: [Account] = [.alice, .bob, .stax]

    var description: String {
        switch self {
        case .alice:
            return "Alice"
        case .bob:
            return "Bob"
        case .stax:
            return "stax"
        case let .unknownAccount(address):
            return "UnknownAccount(\(address.description))"
        }
    }

    var address: EthAddress {
        switch self {
        case .alice:
            return EthAddress("0x00000000000000000000000000000000000A1BC5")
        case .bob:
            return EthAddress("0x00000000000000000000000000000000000B0B0B")
        case .stax:
            return EthAddress("0x7ea8d6119596016935543d90Ee8f5126285060A1")
        case let .unknownAccount(address):
            return address
        }
    }

    static func from(address: EthAddress) -> Account {
        for knownCase in Account.knownCases {
            if address == knownCase.address {
                return knownCase
            }
        }
        return .unknownAccount(address)
    }
}

enum Comet: Hashable, Equatable {
    case cusdcv3
    case cwethv3
    case unknownComet(EthAddress)

    enum Given {
        case supplied(Account, TokenAmount)
        case borrowed(Account, TokenAmount)
    }

    static let knownCases: [Comet] = [.cusdcv3, .cwethv3]

    func address(network: Network) -> EthAddress {
        switch (network, self) {
        // TODO?: add cases for some more (network, market) pairs?
        // eventually this should be migrated to use builderpack instead.
        case (.ethereum, .cusdcv3):
            return EthAddress("0xc3d688B66703497DAA19211EEdff47f25384cdc3")
        case (.ethereum, .cwethv3):
            return EthAddress("0xA17581A9E3356d9A858b789D68B4d866e593aE94")
        case (.base, .cusdcv3):
            return EthAddress("0xb125E6687d4313864e53df431d5425969c15Eb2F")
        case (.base, .cwethv3):
            return EthAddress("0x46e6b214b524310239732D51387075E0e70970bf")
        case (.arbitrum, .cusdcv3):
            return EthAddress("0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf")
        case (.optimism, .cusdcv3):
            return EthAddress("0x2e44e174f7D53F0212823acC11C01A11d58c5bCB")
        case (.optimism, .cwethv3):
            return EthAddress("0xE36A30D249f7761327fd973001A32010b521b6Fd")
        case (_, .cusdcv3):
            fatalError("no market .cusdcv3 for network \(network.description)")
        case (_, .cwethv3):
            fatalError("no market .cwethv3 for network \(network.description)")
        case let (_, .unknownComet(address)):
            return address
        }
    }

    var baseAsset: Token {
        switch self {
        case .cusdcv3: return .usdc
        case .cwethv3: return .weth
        case .unknownComet: return .unknownToken("0x0000000000000000000000000000000000000000")
        }
    }

    var description: String {
        switch self {
        case .cusdcv3:
            return "cUSDCv3"
        case .cwethv3:
            return "cWETHv3"
        case let .unknownComet(address):
            return "Comet at \(address.description)"
        }
    }

    static func from(network: Network, address: EthAddress) -> Comet {
        switch (network, address) {
        case (.ethereum, "0xc3d688B66703497DAA19211EEdff47f25384cdc3"):
            return .cusdcv3
        case (.ethereum, "0xA17581A9E3356d9A858b789D68B4d866e593aE94"):
            return .cwethv3
        case (.base, "0xb125E6687d4313864e53df431d5425969c15Eb2F"):
            return .cusdcv3
        case (.base, "0x46e6b214b524310239732D51387075E0e70970bf"):
            return .cwethv3
        case (.arbitrum, "0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf"):
            return .cusdcv3
        case (.optimism, "0x2e44e174f7D53F0212823acC11C01A11d58c5bCB"):
            return .cusdcv3
        case (.optimism, "0xE36A30D249f7761327fd973001A32010b521b6Fd"):
            return .cwethv3
        case _:
            return .unknownComet(address)
        }
    }
}

enum CometReward: Hashable, Equatable {
    case wethReward
    case usdcReward
    case unknownCometReward(EthAddress)

    var rewardToken: Token {
        switch self {
        case .usdcReward:
            return .usdc
        case .wethReward:
            return .weth
        case .unknownCometReward(let address):
            return .unknownToken(address)
        }
    }

    // TODO: These are just Comet addresses for now, but should be fine
    func address(network: Network) -> EthAddress {
        switch (network, self) {
        case (.ethereum, .usdcReward):
            return EthAddress("0xc3d688B66703497DAA19211EEdff47f25384cdc3")
        case (.ethereum, .wethReward):
            return EthAddress("0xA17581A9E3356d9A858b789D68B4d866e593aE94")
        case (.base, .usdcReward):
            return EthAddress("0xb125E6687d4313864e53df431d5425969c15Eb2F")
        case (.base, .wethReward):
            return EthAddress("0x46e6b214b524310239732D51387075E0e70970bf")
        case (.arbitrum, .usdcReward):
            return EthAddress("0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf")
        case (.arbitrum, .wethReward):
            return EthAddress("0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf")
        case (.optimism, .usdcReward):
            return EthAddress("0x2e44e174f7D53F0212823acC11C01A11d58c5bCB")
        case (.optimism, .wethReward):
            return EthAddress("0xE36A30D249f7761327fd973001A32010b521b6Fd")
        case (_, .usdcReward):
            fatalError("no CometReward for .usdc for network \(network.description)")
        case (_, .wethReward):
            fatalError("no CometReward for .weth for network \(network.description)")
        case let (_, .unknownCometReward(address)):
            return address
        }
    }

    var description: String {
        switch self {
        case .usdcReward:
            return "USDCCometReward"
        case .wethReward:
            return "WETHCometReward"
        case let .unknownCometReward(address):
            return "CometReward at \(address.description)"
        }
    }

    static func from(network: Network, address: EthAddress) -> CometReward {
        switch (network, address) {
        case (.ethereum, "0xc3d688B66703497DAA19211EEdff47f25384cdc3"):
            return .usdcReward
        case (.ethereum, "0xA17581A9E3356d9A858b789D68B4d866e593aE94"):
            return .wethReward
        case (.base, "0xb125E6687d4313864e53df431d5425969c15Eb2F"):
            return .usdcReward
        case (.base, "0x46e6b214b524310239732D51387075E0e70970bf"):
            return .wethReward
        case (.arbitrum, "0x9c4ec768c28520B50860ea7a15bd7213a9fF58bf"):
            return .usdcReward
        case (.optimism, "0x2e44e174f7D53F0212823acC11C01A11d58c5bCB"):
            return .usdcReward
        case (.optimism, "0xE36A30D249f7761327fd973001A32010b521b6Fd"):
            return .wethReward
        case _:
            return .unknownCometReward(address)
        }
    }
}

struct Morpho: Hashable, Equatable {
    let collateralToken: Token
    let borrowToken: Token

    init(collateralToken ct: Token, borrowToken bt: Token) {
        self.collateralToken = ct
        self.borrowToken = bt
    }

    static func == (lhs: Morpho, rhs: Morpho) -> Bool {
        return lhs.collateralToken == rhs.collateralToken && lhs.borrowToken == rhs.borrowToken
    }

    static func morpho(_ collateralToken: Token, _ borrowToken: Token) -> Morpho {
        return Morpho(
            collateralToken: collateralToken,
            borrowToken: borrowToken
        )
    }

    var description: String {
        return "Morpho(\(self.collateralToken.symbol)/\(self.borrowToken.symbol))"
    }

    static func address(_ network: Network) -> EthAddress {
        switch network {
            case .ethereum, .base, .baseSepolia:
                return EthAddress("0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb")
            case .sepolia:
                return EthAddress("0xd011EE229E7459ba1ddd22631eF7bF528d424A14")
            default:
                fatalError("Morpho not available on network: \(network.description)")
        }
    }
}

enum MorphoVault: Hashable, Equatable {
    case usdc
    case usdt
    case weth
    case wbtc
    case unknownVault(EthAddress)

    static let knownCases: [MorphoVault] = [.usdc, .usdt, .weth, .wbtc]

    func address(network: Network) -> EthAddress {
        switch (network, self) {
        case (.ethereum, .usdc):
            return EthAddress("0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458")
        case (.ethereum, .usdt):
            return EthAddress("0x8CB3649114051cA5119141a34C200D65dc0Faa73")
        case (.ethereum, .weth):
            return EthAddress("0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658")
        case (.ethereum, .wbtc):
            return EthAddress("0x443df5eEE3196e9b2Dd77CaBd3eA76C3dee8f9b2")
        case (.base, .usdc):
            return EthAddress("0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca")
        case (.base, .weth):
            return EthAddress("0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1")
        case let (_, .unknownVault(address)):
            return address
        default:
            fatalError("no vault for \(description) on network \(network.description)")
        }
    }

    func asset(network: Network) -> EthAddress? {
        switch self {
        case .usdc:
            return Token.usdc.address(network: network)
        case .usdt:
            return Token.usdt.address(network: network)
        case .weth:
            return Token.weth.address(network: network)
        case .wbtc:
            return Token.wbtc.address(network: network)
        default:
            fatalError("no asset for \(description) on network \(network.description)")
        }
    }

    var description: String {
        switch self {
        case .usdc:
            return "USDC Vault"
        case .usdt:
            return "USDT Vault"
        case .weth:
            return "WETH Vault"
        case .wbtc:
            return "WBTC Vault"
        case let .unknownVault(address):
            return "Vault at \(address.description)"
        }
    }

    static func from(network: Network, address: EthAddress) -> MorphoVault {
        switch (network, address) {
        case (.ethereum, "0x8eB67A509616cd6A7c1B3c8C21D48FF57df3d458"):
            return .usdc
        case (.ethereum, "0x8CB3649114051cA5119141a34C200D65dc0Faa73"):
            return .usdt
        case (.ethereum, "0x4881Ef0BF6d2365D3dd6499ccd7532bcdBCE0658"):
            return .weth
        case (.ethereum, "0x443df5eEE3196e9b2Dd77CaBd3eA76C3dee8f9b2"):
            return .wbtc
        case (.base, "0xc1256Ae5FF1cf2719D4937adb3bbCCab2E00A2Ca"):
            return .usdc
        case (.base, "0xa0E430870c4604CcfC7B38Ca7845B1FF653D0ff1"):
            return .weth
        case _:
            return .unknownVault(address)
        }
    }
}

enum Exchange: Hashable, Equatable {
    case zeroEx
    case updatedZeroEx
    case unknownExchange(EthAddress, Hex)

    static let knownCases: [Exchange] = [.zeroEx]

    static let ZERO_EX_ENTRYPOINT = EthAddress("0xDef1C0ded9bec7F1a1670819833240f027b25EfF")
    static let ZERO_EX_SWAP_DATA: Hex = Hex("0xabcdef")
    static let UPDATED_ZERO_EX_SWAP_DATA: Hex = Hex("0xdef1")

    var description: String {
        switch self {
        case .zeroEx:
            return "0x"
        case .updatedZeroEx:
            return "Updated 0x"
        case let .unknownExchange(address, calldata):
            return "Exchange at \(address.description) with calldata \(calldata.description)"
        }
    }

    var entryPoint: EthAddress {
        switch self {
        case .zeroEx, .updatedZeroEx:
            return Exchange.ZERO_EX_ENTRYPOINT
        case let .unknownExchange(address, _):
            return address
        }
    }

    var swapData: Hex {
        switch self {
        case .zeroEx:
            return Exchange.ZERO_EX_SWAP_DATA
        case .updatedZeroEx:
            return Exchange.UPDATED_ZERO_EX_SWAP_DATA
        case let .unknownExchange(_, data):
            return data
        }
    }

    static func from(network: Network, address: EthAddress, data: Hex) -> Exchange {
        switch (network, address, data) {
        case (_, ZERO_EX_ENTRYPOINT, ZERO_EX_SWAP_DATA):
            return .zeroEx
        case (_, ZERO_EX_ENTRYPOINT, UPDATED_ZERO_EX_SWAP_DATA):
            return .updatedZeroEx
        case _:
            return .unknownExchange(address, data)
        }
    }
}

enum Quote: Hashable, Equatable {
    case basic
    case custom(quoteId: Hex, prices: [Token: Double], fees: [Network: Double])

    static let knownCases: [Quote] = [.basic]

    var params: (quoteId: Hex, prices: [Token: Double], fees: [Network: Double]) {
        switch self {
        case let .custom(quoteId, prices, fees):
            return (quoteId, prices, fees)
        case .basic:
            return (
                Hex("0x00000000000000000000000000000000000000000000000000000000000000CC"),
                Dictionary(
                    uniqueKeysWithValues: Token.knownCases.map { token in
                        (token, token.defaultUsdPrice)
                    }
                ),
                [
                    .ethereum: 0.10,
                    .base: 0.02,
                    .arbitrum: 0.04,
                    .optimism: 0.06
                ]
            )
        }
    }

    var prices: [Token: Double] {
        params.prices
    }

    var fees: [Network: Double] {
        params.fees
    }

    var quoteId: Hex {
        params.quoteId
    }

    static func findQuote(quoteId: Hex, prices: [Token: Double], fees: [Network: Double]) -> Quote {
        for knownCase in Quote.knownCases {
            if knownCase.params.quoteId == quoteId {
                return knownCase
            }
        }
        return .custom(quoteId: quoteId, prices: prices, fees: fees)
    }
}

// TODO: These should come from builder pack
enum Token: Hashable, Equatable {
    case usdc
    case eth
    case weth
    case link
    case usdt
    case wbtc
    case degen
    case cbeth
    case unknownToken(EthAddress)

    static let knownCases: [Token] = [.usdc, .eth, .weth, .link, .usdt, .wbtc, .degen, .cbeth]

    static let networkTokenAddress: [Network: [Token: EthAddress]] = [
        .ethereum: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"),
            .usdc: EthAddress("0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"),
            .link: EthAddress("0x514910771af9ca656af840dff83e8264ecf986ca"),
            .usdt: EthAddress("0xdac17f958d2ee523a2206206994597c13d831ec7"),
            .wbtc: EthAddress("0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"),
        ],
        .base: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0x4200000000000000000000000000000000000006"),
            .usdc: EthAddress("0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"),
            .usdt: EthAddress("0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2"),
            .wbtc: EthAddress("0x0555E30da8f98308EdB960aa94C0Db47230d2B9c"),
            .degen: EthAddress("0x4ed4E862860beD51a9570b96d89aF5E1B0Efefed"),
            .cbeth: EthAddress("0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22"),
        ],
        .arbitrum: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"),
            .usdc: EthAddress("0xaf88d065e77c8cC2239327C5EDb3A432268e5831"),
            .link: EthAddress("0xf97f4df75117a78c1A5a0DBb814Af92458539FB4"),
            .usdt: EthAddress("0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"),
            .wbtc: EthAddress("0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"),
        ],
        .optimism: [
            .eth: EthAddress("0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE"),
            .weth: EthAddress("0x4200000000000000000000000000000000000006"),
            .usdc: EthAddress("0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85"),
            .usdt: EthAddress("0x94b008aA00579c1307B0EF2c499aD98a8ce58e58"),
            .wbtc: EthAddress("0x68f180fcCe6836688e9084f035309E29Bf0A2095"),
        ],
        .unknown(7777): [
            .usdc: EthAddress("0x7777000000000000000000000000000000000001"),
            .weth: EthAddress("0x7777000000000000000000000000000000000002"),
        ]
    ]

    static var networkAddressToken: [Network: [EthAddress: Token]] {
        networkTokenAddress.mapValues { tokenMap in
            Dictionary(uniqueKeysWithValues: tokenMap.map { ($0.value, $0.key) })
        }
    }

    static func from(network: Network, address: EthAddress) -> Token {
        if let token = Token.networkAddressToken[network]?[address] {
            return token
        } else {
            return .unknownToken(address)
        }
    }

    static func getTokenAmount(amount: BigUInt, network: Network, address: EthAddress)
        -> TokenAmount
    {
        let token = Token.from(network: network, address: address)
        return TokenAmount(fromWei: amount, ofToken: token)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(description)
    }

    var symbol: String {
        switch self {
        case .usdc:
            return "USDC"
        case .usdt:
            return "USDT"
        case .eth:
            return "ETH"
        case .weth:
            return "WETH"
        case .link:
            return "LINK"
        case .wbtc:
            return "WBTC"
        case .degen:
            return "DEGEN"
        case .cbeth:
            return "cbETH"
        case let .unknownToken(address):
            return "UnknownToken(\(address.description))"
        }
    }

    var decimals: Int {
        switch self {
        case .usdc, .usdt:
            return 6
        case .wbtc:
            return 8
        case .eth, .weth, .link, .degen, .cbeth:
            return 18
        case .unknownToken:
            return 0
        }
    }

    var defaultUsdPrice: Double {
        switch self {
        case .usdc, .usdt:
            return 1.0
        case .eth, .weth, .cbeth:
            return 4000.0
        case .link:
            return 25.0
        case .wbtc:
            return 100_000.0
        case .degen:
            return 2.0
        case .unknownToken:
            return 0
        }
    }

    var description: String {
        return symbol
    }

    func address(network: Network) -> EthAddress? {
        Token.networkTokenAddress[network]?[self]
    }
}

extension BigUInt {
    static let max = BigUInt(1) << 256 - 1
}

struct TokenAmount: Equatable {
    let amount: BigUInt
    let token: Token

    init(fromAmount amount: Double, ofToken token: Token) {
        self.amount = BigUInt(amount * pow(10, Double(token.decimals)))
        self.token = token
    }

    init(fromWei amount: BigUInt, ofToken token: Token) {
        self.amount = amount
        self.token = token
    }

    static func == (lhs: TokenAmount, rhs: TokenAmount) -> Bool {
        return lhs.amount == rhs.amount && lhs.token == rhs.token
    }

    static func amt(_ amount: Double, _ token: Token) -> TokenAmount {
        return TokenAmount(
            fromAmount: amount,
            ofToken: token
        )
    }

    static func max(_ token: Token) -> TokenAmount {
        return TokenAmount(
            fromWei: BigUInt.max,
            ofToken: token
        )
    }
}

enum Given {
    case tokenBalance(Account, TokenAmount, Network)
    case quote(Quote)
    case cometSupply(Account, TokenAmount, Comet, Network)
    case cometBorrow(Account, TokenAmount, Comet, Network)
    case cometReward(Account, TokenAmount, Comet, CometReward, Network)
    case morphoVaultSupply(Account, TokenAmount, MorphoVault, Network)
    case morphoBorrow(Account, TokenAmount, TokenAmount, Network);
    case acrossQuote(TokenAmount, Double)
    case acrossQuoteWithMin(TokenAmount, Double, TokenAmount)
    // Buy Amount, Fee Token, Fee Amount
    case zeroExQuote(TokenAmount, Exchange, Network)
}

indirect enum When {
    case transfer(from: Account, to: Account, amount: TokenAmount, on: Network)
    case cometBorrow(from: Account, market: Comet, borrowAmount: TokenAmount, collateralAmounts: [TokenAmount], on: Network)
    case cometClaimRewards(from: Account)
    case cometRepay(from: Account, market: Comet, repayAmount: TokenAmount, collateralAmounts: [TokenAmount], on: Network)
    case cometSupply(from: Account, market: Comet, amount: TokenAmount, on: Network)
    case cometWithdraw(from: Account, market: Comet, amount: TokenAmount, on: Network)
    case morphoBorrow(from: Account, borrowAmount: TokenAmount, collateralAmount: TokenAmount, on: Network)
    case morphoRepay(from: Account, repayAmount: TokenAmount, collateralAmount: TokenAmount, on: Network)
    case morphoVaultSupply(from: Account, vault: MorphoVault, amount: TokenAmount, on: Network)
    case morphoVaultWithdraw(from: Account, vault: MorphoVault, amount: TokenAmount, on: Network)
    case swap(from: Account, sellAmount: TokenAmount, buyAmount: TokenAmount, exchange: Exchange, on: Network)
    case payWith(currency: Token, When)

    var sender: Account {
        switch self {
        case let .transfer(from, _, _, _):
            return from
        case let .cometSupply(from, _, _, _):
            return from
        case let .cometBorrow(from, _, _, _, _):
            return from
        case let .cometClaimRewards(from):
            return from
        case let .cometRepay(from, _, _, _, _):
            return from
        case let .cometWithdraw(from, _, _, _):
            return from
        case let .morphoBorrow(from, _, _, _):
            return from
        case let .morphoRepay(from, _, _, _):
            return from
        case let .morphoVaultSupply(from, _, _, _):
            return from
        case let .morphoVaultWithdraw(from, _, _, _):
            return from
        case let .swap(from, _, _, _, _):
            return from
        case let .payWith(_, intent):
            return intent.sender
        }
    }

    var paymentAssetSymbol: String {
        switch self {
        case let .payWith(token, _):
            return token.symbol
        case _:
            return "USDC"
        }
    }
}

enum CallExpect {
    case single(Call)
    case multi([Call])
}

enum Expect {
    case revert(QuarkBuilder.RevertReason)
    case success(CallExpect)
}

final class AcceptanceTest: CustomTestArgumentEncodable, CustomStringConvertible, Sendable {
    let name: String
    let given: [Given]
    let when: When
    let expect: Expect
    let only: Bool
    let skip: Bool

    init(
        name: String, given: [Given], when: When, expect: Expect, only: Bool = false,
        skip: Bool = false
    ) {
        self.name = name
        self.given = given
        self.when = when
        self.expect = expect
        self.only = only
        self.skip = skip

        if only, skip {
            fatalError("Cannot set both `only` and `skip` for a test")
        }
    }

    func encodeTestArgument(to encoder: some Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }

    var description: String {
        return name
    }
}

class Context {
    let sender: Account
    var prices: [Token: Double]
    var fees: [Network: Double]
    var paymentToken: Token?
    var tokenPositions: [Network: [Token: [Account: BigUInt]]]
    var cometPositions: [Network: [Comet: [Account: (BigUInt, BigUInt, [Token: BigUInt], [CometReward: BigUInt])]]]
    var morphoPositions: [Network: [Morpho: [Account: (BigUInt, BigUInt)]]]
    var morphoVaultPositions: [Network: [MorphoVault: [Account: BigUInt]]]
    var ffis: EVM.FFIMap = [:]

    let allNetworks: [Network] = [.ethereum, .base, .arbitrum, .optimism]

    var chainAccounts: [QuarkBuilder.Accounts.ChainAccounts] {
        allNetworks.map { network in
            QuarkBuilder.Accounts.ChainAccounts(
                chainId: BigUInt(network.chainId),
                quarkSecrets: [
                    .init(
                        account: sender.address,
                        nonceSecret: Hex(
                            "0x5555555555555555555555555555555555555555555555555555555555555555"
                        )
                    )
                ],
                assetPositionsList: reifyTokenPositions(network: network),
                cometPositions: reifyCometPositions(network: network),
                morphoPositions: reifyMorphoPositions(network: network),
                morphoVaultPositions: reifyMorphoVaultPositions(network: network)
            )
        }
    }

    init(sender: Account) {
        self.sender = sender
        prices = [:]
        fees = [:]
        paymentToken = .none
        tokenPositions = [:]
        cometPositions = [:]
        morphoPositions = [:]
        morphoVaultPositions = [:]
    }

    func given(_ given: Given) {
        switch given {
        case let .tokenBalance(account, amount, network):
            let currentPosition =
                tokenPositions[network, default: [:]][amount.token, default: [:]][account] ?? 0
            tokenPositions[network, default: [:]][amount.token, default: [:]][account] =
                currentPosition + amount.amount
        case let .cometReward(account, rewardOwed, comet, cometReward, network):
            if (cometReward.rewardToken != rewardOwed.token) {
                fatalError("RewardOwed token does not match CometReward token")
            }
            let (currSupply, currBorrow, collaterals, cometRewardsOwed) =
                cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                    0, 0, [:], [:]
                )
            var updatedCometRewardsOwed = cometRewardsOwed
            updatedCometRewardsOwed[cometReward, default: 0] += rewardOwed.amount
            cometPositions[network, default: [:]][comet, default: [:]][account] = (
                currSupply, currBorrow, collaterals, updatedCometRewardsOwed
            )
        case let .cometSupply(account, amount, comet, network):
            if amount.token == comet.baseAsset {
                let (currSupply, currBorrow, collaterals, cometRewardsOwed) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:], [:]
                    )
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply + amount.amount, currBorrow, collaterals, cometRewardsOwed
                )
            } else {
                let (currSupply, currBorrow, collaterals, cometRewardsOwed) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:], [:]
                    )
                var updatedCollaterals = collaterals
                updatedCollaterals[amount.token, default: 0] += amount.amount
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply, currBorrow, updatedCollaterals, cometRewardsOwed
                )
            }
        case let .cometBorrow(account, amount, comet, network):
            if amount.token == comet.baseAsset {
                let (currSupply, currBorrow, collaterals, cometRewardsOwed) =
                    cometPositions[network, default: [:]][comet, default: [:]][account] ?? (
                        0, 0, [:], [:]
                    )
                cometPositions[network, default: [:]][comet, default: [:]][account] = (
                    currSupply, currBorrow + amount.amount, collaterals, cometRewardsOwed
                )
            } else {
                fatalError("Cannot borrow non-base asset")
            }
        case let .morphoBorrow(account, borrowAmount, collateralAmount, network):
            let morpho = Morpho.morpho(collateralAmount.token, borrowAmount.token)
            let (currentBorrow, currentCollateralSupply) = morphoPositions[network, default: [:]][morpho, default: [:]][account, default: (BigUInt(0), BigUInt(0))]
            morphoPositions[network, default: [:]][morpho, default: [:]][account] = (currentBorrow + borrowAmount.amount, currentCollateralSupply + collateralAmount.amount)
        case let .morphoVaultSupply(account, amount, vault, network):
            let currentSupply = morphoVaultPositions[network, default: [:]][vault, default: [:]][account, default: BigUInt(0)]

            morphoVaultPositions[network, default: [:]][vault, default: [:]][account] = currentSupply + amount.amount
        case let .quote(quote):
            prices = quote.prices
            fees = quote.fees
        case let .acrossQuote(gasFee, feePct):
            ffis[EthAddress("0x0000000000000000000000000000000000FF1010")] = { _ in
                .ok(
                    ABI.Value.tuple3(
                        .uint256(gasFee.amount), .uint256(BigUInt(feePct * 1e18)), .uint256(0)
                    ).encoded)
            }
        case let .acrossQuoteWithMin(gasFee, feePct, minAmount):
            ffis[EthAddress("0x0000000000000000000000000000000000FF1010")] = { _ in
                .ok(
                    ABI.Value.tuple3(
                        .uint256(gasFee.amount), .uint256(BigUInt(feePct * 1e18)), .uint256(minAmount.amount)
                    ).encoded)
            }
        case let .zeroExQuote(buyAmount, exchange, network):
            guard let feeTokenAddress = buyAmount.token.address(network: network) else {
                fatalError("Cannot give quote for unknown token")
            }
            let feeAmount = buyAmount.amount / BigUInt(100);
            ffis[EthAddress("0x0000000000000000000000000000000000FF1011")] = { _ in
                .ok(
                    // bytes memory swapData, uint256 buyAmount, address feeToken, uint256 feeAmount
                    ABI.Value.tuple4(
                        .bytes(exchange.swapData), .uint256(buyAmount.amount), .address(feeTokenAddress), .uint256(feeAmount)
                    ).encoded)
            }
        }
    }

    func when(_ when: When) async throws -> Result<
        QuarkBuilder.QuarkBuilderBase.BuilderResult, QuarkBuilder.RevertReason
    > {
        let assetQuotes = prices.map {
            QuarkBuilder.Quotes.AssetQuote(
                symbol: $0.key.symbol, price: BigUInt($0.value * 1e8)
            )
        }

        let networkOperationFees = fees.map {
            QuarkBuilder.Quotes.NetworkOperationFee(
                chainId: BigUInt($0.key.chainId),
                opType: "BASELINE",
                price: BigUInt($0.value * 1e8)
            )
        }

        switch when {
        case let .payWith(token, intent):
            paymentToken = token
            return try await self.when(intent)
        case let .cometBorrow(from, market, borrowAmount, collateralAmounts, network):
            return try await QuarkBuilder.cometBorrow(
                intent: .init(
                    amount: borrowAmount.amount,
                    assetSymbol: borrowAmount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    borrower: from.address,
                    chainId: BigUInt(network.chainId),
                    collateralAmounts: collateralAmounts.map {
                        $0.amount
                    },
                    collateralAssetSymbols: collateralAmounts.map {
                        $0.token.symbol
                    },
                    comet: market.address(network: network),
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .cometClaimRewards(from):
            return try await QuarkBuilder.cometClaimRewards(
                intent: .init(
                    blockTimestamp: BigUInt(1_000_000),
                    claimer: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .cometRepay(from, market, repayAmount, collateralAmounts, network):
            return try await QuarkBuilder.cometRepay(
                intent: .init(
                    amount: repayAmount.amount,
                    assetSymbol: repayAmount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    chainId: BigUInt(network.chainId),
                    collateralAmounts: collateralAmounts.map {
                        $0.amount
                    },
                    collateralAssetSymbols: collateralAmounts.map {
                        $0.token.symbol
                    },
                    comet: market.address(network: network),
                    repayer: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .cometSupply(from, market, amount, network):
            return try await QuarkBuilder.cometSupply(
                intent: .init(
                    amount: amount.amount,
                    assetSymbol: amount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    chainId: BigUInt(network.chainId),
                    comet: market.address(network: network),
                    sender: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .cometWithdraw(from, market, amount, network):
            return try await QuarkBuilder.cometWithdraw(
                intent: .init(
                    amount: amount.amount,
                    assetSymbol: amount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    chainId: BigUInt(network.chainId),
                    comet: market.address(network: network),
                    withdrawer: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )

        case let .morphoBorrow(from, borrowAmount, collateralAmount, network):
            return try await QuarkBuilder.morphoBorrow(
                intent: .init(
                    amount: borrowAmount.amount,
                    assetSymbol: borrowAmount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    borrower: from.address,
                    chainId: BigUInt(network.chainId),
                    collateralAmount: collateralAmount.amount,
                    collateralAssetSymbol: collateralAmount.token.symbol,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .morphoRepay(from, repayAmount, collateralAmount, network):
            return try await QuarkBuilder.morphoRepay(
                intent: .init(
                    amount: repayAmount.amount,
                    assetSymbol: repayAmount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    repayer: from.address,
                    chainId: BigUInt(network.chainId),
                    collateralAmount: collateralAmount.amount,
                    collateralAssetSymbol: collateralAmount.token.symbol,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .morphoVaultSupply(from, _, amount, network):
            return try await QuarkBuilder.morphoVaultSupply(
                intent: .init(
                    amount: amount.amount,
                    assetSymbol: amount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    sender: from.address,
                    chainId: BigUInt(network.chainId),
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .morphoVaultWithdraw(from, _, amount, network):
            return try await QuarkBuilder.morphoVaultWithdraw(
                intent: .init(
                    amount: amount.amount,
                    assetSymbol: amount.token.symbol,
                    blockTimestamp: BigUInt(1_000_000),
                    chainId: BigUInt(network.chainId),
                    withdrawer: from.address,
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .transfer(from, to, amount, network):
            return try await QuarkBuilder.transfer(
                intent: .init(
                    chainId: BigUInt(network.chainId),
                    assetSymbol: amount.token.symbol,
                    amount: amount.amount,
                    sender: from.address,
                    recipient: to.address,
                    blockTimestamp: BigUInt(1_000_000),
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        case let .swap(from, sellAmount, buyAmount, exchange, network):
            guard let sellToken = sellAmount.token.address(network: network),
                let buyToken = buyAmount.token.address(network: network)
            else {
                fatalError("Cannot swap unknown token")
            }

            return try await QuarkBuilder.swap(
                intent: .init(
                    chainId: BigUInt(network.chainId),
                    entryPoint: exchange.entryPoint,
                    swapData: exchange.swapData,
                    sellToken: sellToken,
                    sellAmount: sellAmount.amount,
                    buyToken: buyToken,
                    buyAmount: buyAmount.amount,
                    feeToken: buyToken,
                    feeAmount: buyAmount.amount / BigUInt(100),
                    sender: from.address,
                    isExactOut: false,
                    blockTimestamp: BigUInt(1_000_000),
                    preferAcross: true,
                    paymentAssetSymbol: paymentToken?.symbol ?? when.paymentAssetSymbol
                ),
                chainAccountsList: chainAccounts,
                quote: .init(
                    quoteId: Hex(
                        "0x00000000000000000000000000000000000000000000000000000000000000CC"),
                    issuedAt: 0,
                    expiresAt: BigUInt(Date(timeIntervalSinceNow: 1_000_000).timeIntervalSince1970),
                    assetQuotes: assetQuotes,
                    networkOperationFees: networkOperationFees
                ),
                withFunctions: ffis
            )
        }
    }

    func reifyTokenPositions(network: Network) -> [QuarkBuilder.Accounts.AssetPositions] {
        Token.knownCases.compactMap { token in
            guard let asset = token.address(network: network) else {
                return nil
            }

            return QuarkBuilder.Accounts.AssetPositions(
                asset: asset,
                symbol: token.symbol,
                decimals: BigUInt(token.decimals),
                usdPrice: BigUInt(token.defaultUsdPrice),
                accountBalances: Account.knownCases.map { account in
                    let amount =
                        tokenPositions[network, default: [:]][token, default: [:]][account] ?? 0
                    return QuarkBuilder.Accounts.AccountBalance(
                        account: account.address,
                        balance: amount
                    )
                }
            )
        }
    }

    func reifyCometPositions(network: Network) -> [QuarkBuilder.Accounts.CometPositions] {
        (cometPositions[network] ?? [:]).compactMap { comet, accountPositions in
            var collateralPositions: [Token: [Account: BigUInt]] = [:]
            var cometRewardsOwed: [CometReward: [Account: BigUInt]] = [:]
            for (account, position) in accountPositions {
                for (token, amount) in position.2 {
                    collateralPositions[token, default: [:]][account] = amount
                }
                for (cometReward, rewardOwed) in position.3 {
                    cometRewardsOwed[cometReward, default: [:]][account] = rewardOwed
                }
            }

            guard let baseAsset = comet.baseAsset.address(network: network) else {
                return nil
            }

            return QuarkBuilder.Accounts.CometPositions(
                comet: comet.address(network: network),
                basePosition: QuarkBuilder.Accounts.CometBasePosition(
                    asset: baseAsset,
                    accounts: accountPositions.map { account, _ in account.address },
                    borrowed: accountPositions.map { _, position in position.1 },
                    supplied: accountPositions.map { _, position in position.0 }
                ),
                collateralPositions: collateralPositions.compactMap { token, accountAmounts in
                    guard let asset = token.address(network: network) else {
                        return nil
                    }

                    return QuarkBuilder.Accounts.CometCollateralPosition(
                        asset: asset,
                        accounts: accountAmounts.map { account, _ in account.address },
                        balances: accountAmounts.map { _, amount in amount }
                    )
                },
                cometRewards: cometRewardsOwed.compactMap { cometReward, accountAmounts in
                    guard let asset = cometReward.rewardToken.address(network: network) else {
                        return nil
                    }

                    return QuarkBuilder.Accounts.CometReward(
                        asset: asset,
                        rewardContract: cometReward.address(network: network),
                        accounts: accountAmounts.map { account, _ in account.address },
                        rewardsOwed: accountAmounts.map { _, rewardOwed in rewardOwed }
                    )
                }
            )
        }
    }

    func reifyMorphoVaultPositions(network: Network) -> [QuarkBuilder.Accounts.MorphoVaultPositions] {
        (morphoVaultPositions[network] ?? [:]).compactMap { vault, accountPositions in
            guard let asset = vault.asset(network: network) else {
                return nil
            }

            return QuarkBuilder.Accounts.MorphoVaultPositions(
                asset: asset,
                accounts: accountPositions.map { $0.key.address },
                balances: accountPositions.map { $0.value },
                vault: vault.address(network: network)
            )
        }
    }

    func reifyMorphoPositions(network: Network) -> [QuarkBuilder.Accounts.MorphoPositions] {
        (morphoPositions[network] ?? [:]).compactMap { morpho, morphoPositions in
            guard let borrowTokenAddress = morpho.borrowToken.address(network: network),
                  let collateralTokenAddress = morpho.collateralToken.address(network: network) else {
                return nil
            }

            // currently unused
            let marketId = Hex("0xabcd")

            return QuarkBuilder.Accounts.MorphoPositions(
                 marketId: marketId,
                 morpho: Morpho.address(network),
                 loanToken: borrowTokenAddress,
                 collateralToken: collateralTokenAddress,
                 borrowPosition: QuarkBuilder.Accounts.MorphoBorrowPosition(
                    accounts: morphoPositions.map { $0.key.address },
                    borrowed: morphoPositions.map { $0.value.0 }
                 ),
                 collateralPosition: QuarkBuilder.Accounts.MorphoCollateralPosition(
                    accounts: morphoPositions.map { $0.key.address },
                    balances: morphoPositions.map { $0.value.1 }
                 )
            )
        }
    }
}

enum ANSIColor: String {
    case red = "\u{001B}[31m"
    case green = "\u{001B}[32m"
    case yellow = "\u{001B}[33m"
    case blue = "\u{001B}[34m"
    case reset = "\u{001B}[0m"
}

func colorize(_ text: String, with color: ANSIColor) -> String {
    return "\(color.rawValue)\(text)\(ANSIColor.reset.rawValue)"
}

func customFatalError(_ message: String, file: String = #file, line: Int = #line) -> Never {
    print("Error: \(message)")
    print("Location: \(file):\(line)")
    print("Stack trace:")
    Thread.callStackSymbols.forEach { print($0) }
    fatalError(message)
}

func buildResultToCalls(builderResult: QuarkBuilder.QuarkBuilderBase.BuilderResult) -> [Call] {
    return zip(builderResult.quarkOperations, builderResult.actions).map { operation, action in
        Call.tryDecodeCall(
            scriptAddress: operation.scriptAddress, calldata: operation.scriptCalldata,
            network: Network.fromChainId(BigInt(action.chainId))
        )
    }
}

@Test func testCreate2Address() {
    let address = getScriptAddress(Hex("0xaa"))
    #expect(address == EthAddress("0x103B7e61BBaa2F62028Ebf3Ea7C47dC74Bd3a617"))
}

@Test("Acceptance Tests", arguments: filteredTests)
func testAcceptanceTests(test: AcceptanceTest) async throws {
    let context = Context(sender: test.when.sender)
    for given in test.given {
        context.given(given)
    }
    let result: Result<QuarkBuilder.QuarkBuilderBase.BuilderResult, QuarkBuilder.RevertReason>
    do {
        result = try await context.when(test.when)
    } catch let queryError as EVM.QueryError {
        result = .failure(
            QuarkBuilder.RevertReason.unknownRevert("QueryError", String(describing: queryError)))
    }

    switch (test.expect, result) {
    case let (.revert(expectedRevertReason), .failure(revertReason)):
        #expect(
            revertReason == expectedRevertReason,
            "\n\(colorize("Expected Revert:", with: .yellow))\n\t\(colorize(String(describing: expectedRevertReason), with: .reset))\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(colorize(String(describing: revertReason), with: .reset))\n\n"
        )
    case let (.revert(expectedRevertReason), .success(builderResult)):
        let calls = buildResultToCalls(builderResult: builderResult)
        #expect(
            Bool(false),
            "\n\(colorize("Expected Revert:", with: .yellow))\n\t\(colorize(String(describing: expectedRevertReason), with: .reset))\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(calls.descriptionExt)\n\n"
        )
    case let (.success(callExpect), .failure(revertReason)):
        let expectedCalls =
            switch callExpect {
            case let .single(expectedCall):
                [expectedCall]
            case let .multi(expectedCalls):
                expectedCalls
            }

        #expect(
            Bool(false),
            "\n\(colorize("Expected Result:", with: .yellow))\n\t\(expectedCalls.descriptionExt)\n\n\n\(colorize("Quark Builder Failure:", with: .yellow))\n\t\(colorize(String(describing: revertReason), with: .red))\n\n"
        )
    case let (.success(callExpect), .success(builderResult)):
        // #expect(builderResult.eip712Data.domainSeparator == EIP712Helper.DomainSeparator(name: "Quark", version: "1")) // TODO: Check domain separator?
        // #expect(builderResult.paymentCurrency == "USDC") // TODO: Check payment currency?

        let calls = buildResultToCalls(builderResult: builderResult)
        let expectedCalls =
            switch callExpect {
            case let .single(expectedCall):
                [expectedCall]
            case let .multi(expectedCalls):
                expectedCalls
            }
        #expect(
            expectedCalls == calls,
            "\n\(colorize("Expected Result:", with: .yellow))\n\t\(expectedCalls.descriptionExt)\n\n\n\(colorize("Quark Builder Result:", with: .yellow))\n\t\(calls.descriptionExt)\n\n"
        )
    }
}
