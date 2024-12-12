@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum UniswapSwapActions {
    public struct SwapParamsExactIn: Equatable {
        public static let schema: ABI.Schema = .tuple([.address, .address, .address, .uint256, .uint256, .bytes])

        public let uniswapRouter: EthAddress
        public let recipient: EthAddress
        public let tokenFrom: EthAddress
        public let amount: BigUInt
        public let amountOutMinimum: BigUInt
        public let path: Hex

        public init(uniswapRouter: EthAddress, recipient: EthAddress, tokenFrom: EthAddress, amount: BigUInt, amountOutMinimum: BigUInt, path: Hex) {
            self.uniswapRouter = uniswapRouter
            self.recipient = recipient
            self.tokenFrom = tokenFrom
            self.amount = amount
            self.amountOutMinimum = amountOutMinimum
            self.path = path
        }

        public var encoded: Hex {
            asValue.encoded
        }

        public var asValue: ABI.Value {
            .tuple6(.address(uniswapRouter),
                    .address(recipient),
                    .address(tokenFrom),
                    .uint256(amount),
                    .uint256(amountOutMinimum),
                    .bytes(path))
        }

        public static func decode(hex: Hex) throws -> SwapParamsExactIn {
            if let value = try? schema.decode(hex) {
                return try decodeValue(value)
            }
            // both versions are valid encodings of tuples with dynamic fields ( bytes or string ), so try both decodings
            if case let .tuple1(wrappedValue) = try? ABI.Schema.tuple([schema]).decode(hex) {
                return try decodeValue(wrappedValue)
            }
            // retry original to throw the error
            return try decodeValue(schema.decode(hex))
        }

        public static func decodeValue(_ value: ABI.Value) throws -> SwapParamsExactIn {
            switch value {
            case let .tuple6(.address(uniswapRouter),
                             .address(recipient),
                             .address(tokenFrom),
                             .uint256(amount),
                             .uint256(amountOutMinimum),
                             .bytes(path)):
                return SwapParamsExactIn(uniswapRouter: uniswapRouter, recipient: recipient, tokenFrom: tokenFrom, amount: amount, amountOutMinimum: amountOutMinimum, path: path)
            default:
                throw ABI.DecodeError.mismatchedType(value.schema, schema)
            }
        }
    }

    public struct SwapParamsExactOut: Equatable {
        public static let schema: ABI.Schema = .tuple([.address, .address, .address, .uint256, .uint256, .bytes])

        public let uniswapRouter: EthAddress
        public let recipient: EthAddress
        public let tokenFrom: EthAddress
        public let amount: BigUInt
        public let amountInMaximum: BigUInt
        public let path: Hex

        public init(uniswapRouter: EthAddress, recipient: EthAddress, tokenFrom: EthAddress, amount: BigUInt, amountInMaximum: BigUInt, path: Hex) {
            self.uniswapRouter = uniswapRouter
            self.recipient = recipient
            self.tokenFrom = tokenFrom
            self.amount = amount
            self.amountInMaximum = amountInMaximum
            self.path = path
        }

        public var encoded: Hex {
            asValue.encoded
        }

        public var asValue: ABI.Value {
            .tuple6(.address(uniswapRouter),
                    .address(recipient),
                    .address(tokenFrom),
                    .uint256(amount),
                    .uint256(amountInMaximum),
                    .bytes(path))
        }

        public static func decode(hex: Hex) throws -> SwapParamsExactOut {
            if let value = try? schema.decode(hex) {
                return try decodeValue(value)
            }
            // both versions are valid encodings of tuples with dynamic fields ( bytes or string ), so try both decodings
            if case let .tuple1(wrappedValue) = try? ABI.Schema.tuple([schema]).decode(hex) {
                return try decodeValue(wrappedValue)
            }
            // retry original to throw the error
            return try decodeValue(schema.decode(hex))
        }

        public static func decodeValue(_ value: ABI.Value) throws -> SwapParamsExactOut {
            switch value {
            case let .tuple6(.address(uniswapRouter),
                             .address(recipient),
                             .address(tokenFrom),
                             .uint256(amount),
                             .uint256(amountInMaximum),
                             .bytes(path)):
                return SwapParamsExactOut(uniswapRouter: uniswapRouter, recipient: recipient, tokenFrom: tokenFrom, amount: amount, amountInMaximum: amountInMaximum, path: path)
            default:
                throw ABI.DecodeError.mismatchedType(value.schema, schema)
            }
        }
    }

    public static let creationCode: Hex = "0x608080604052346015576109bb908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c8063bc4610bc146102d05763dfd42a661461002f575f80fd5b346102b95761003d366103e2565b6040810173ffffffffffffffffffffffffffffffffffffffff61005f82610451565b1661007a61006c84610451565b916080850135928391610659565b5f602061013973ffffffffffffffffffffffffffffffffffffffff61009e87610451565b1673ffffffffffffffffffffffffffffffffffffffff6100c160a0890189610472565b91906100e66100d1878c01610451565b91604051946100df866104c3565b3691610587565b83521684820152606088013560408201528560608201526040519485809481937f09b81346000000000000000000000000000000000000000000000000000000008352876004840152602483019061060f565b03925af19081156102c5575f9161028f575b501061015357005b73ffffffffffffffffffffffffffffffffffffffff61017461017b92610451565b1691610451565b90604051905f8073ffffffffffffffffffffffffffffffffffffffff60208501957f095ea7b30000000000000000000000000000000000000000000000000000000087521694856024860152816044860152604485526101dc60648661050c565b84519082855af16101eb610782565b81610260575b5080610256575b15610200575b005b6102516101fe93604051907f095ea7b300000000000000000000000000000000000000000000000000000000602083015260248201525f60448201526044815261024b60648261050c565b826107c9565b6107c9565b50803b15156101f8565b8051801592508215610275575b50505f6101f1565b61028892506020809183010191016107b1565b5f8061026d565b90506020813d6020116102bd575b816102aa6020938361050c565b810103126102b957515f61014b565b5f80fd5b3d915061029d565b6040513d5f823e3d90fd5b346102b9575f60206103aa6102e4366103e2565b73ffffffffffffffffffffffffffffffffffffffff60808161030860408501610451565b169261032461031682610451565b946060830135958691610659565b8261032e82610451565b169361033d60a0830183610472565b949061035b61034d8a8601610451565b91604051976100df896104c3565b865216878501526040840152013560608201526040519485809481937fb858183f000000000000000000000000000000000000000000000000000000008352876004840152602483019061060f565b03925af180156102c5576103ba57005b6101fe9060203d6020116103db575b6103d3818361050c565b8101906105bd565b503d6103c9565b60207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc8201126102b9576004359067ffffffffffffffff82116102b9577ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc8260c0920301126102b95760040190565b3573ffffffffffffffffffffffffffffffffffffffff811681036102b95790565b9035907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1813603018212156102b9570180359067ffffffffffffffff82116102b9576020019181360383136102b957565b6080810190811067ffffffffffffffff8211176104df57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176104df57604052565b67ffffffffffffffff81116104df57601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200190565b9291926105938261054d565b916105a1604051938461050c565b8294818452818301116102b9578281602093845f960137010152565b908160209103126102b9575190565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b9060608061062684516080855260808501906105cc565b9373ffffffffffffffffffffffffffffffffffffffff602082015116602085015260408101516040850152015191015290565b6040519173ffffffffffffffffffffffffffffffffffffffff60208401917f095ea7b300000000000000000000000000000000000000000000000000000000835216938460248501526044840152604483526106b660648461050c565b5f8073ffffffffffffffffffffffffffffffffffffffff84169285519082855af1906106e0610782565b82610750575b5081610745575b50156106f857505050565b61025161074393604051907f095ea7b300000000000000000000000000000000000000000000000000000000602083015260248201525f60448201526044815261024b60648261050c565b565b90503b15155f6106ed565b80519192508115918215610768575b5050905f6106e6565b61077b92506020809183010191016107b1565b5f8061075f565b3d156107ac573d906107938261054d565b916107a1604051938461050c565b82523d5f602084013e565b606090565b908160209103126102b9575180151581036102b95790565b9073ffffffffffffffffffffffffffffffffffffffff61083792165f80604051936107f560408661050c565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af1610831610782565b916108eb565b80519081159182156108d1575b50501561084d57565b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b6108e492506020809183010191016107b1565b5f80610844565b9192901561096657508151156108ff575090565b3b156109085790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156109795750805190602001fd5b6109b7906040519182917f08c379a00000000000000000000000000000000000000000000000000000000083526020600484015260248301906105cc565b0390fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c8063bc4610bc146102d05763dfd42a661461002f575f80fd5b346102b95761003d366103e2565b6040810173ffffffffffffffffffffffffffffffffffffffff61005f82610451565b1661007a61006c84610451565b916080850135928391610659565b5f602061013973ffffffffffffffffffffffffffffffffffffffff61009e87610451565b1673ffffffffffffffffffffffffffffffffffffffff6100c160a0890189610472565b91906100e66100d1878c01610451565b91604051946100df866104c3565b3691610587565b83521684820152606088013560408201528560608201526040519485809481937f09b81346000000000000000000000000000000000000000000000000000000008352876004840152602483019061060f565b03925af19081156102c5575f9161028f575b501061015357005b73ffffffffffffffffffffffffffffffffffffffff61017461017b92610451565b1691610451565b90604051905f8073ffffffffffffffffffffffffffffffffffffffff60208501957f095ea7b30000000000000000000000000000000000000000000000000000000087521694856024860152816044860152604485526101dc60648661050c565b84519082855af16101eb610782565b81610260575b5080610256575b15610200575b005b6102516101fe93604051907f095ea7b300000000000000000000000000000000000000000000000000000000602083015260248201525f60448201526044815261024b60648261050c565b826107c9565b6107c9565b50803b15156101f8565b8051801592508215610275575b50505f6101f1565b61028892506020809183010191016107b1565b5f8061026d565b90506020813d6020116102bd575b816102aa6020938361050c565b810103126102b957515f61014b565b5f80fd5b3d915061029d565b6040513d5f823e3d90fd5b346102b9575f60206103aa6102e4366103e2565b73ffffffffffffffffffffffffffffffffffffffff60808161030860408501610451565b169261032461031682610451565b946060830135958691610659565b8261032e82610451565b169361033d60a0830183610472565b949061035b61034d8a8601610451565b91604051976100df896104c3565b865216878501526040840152013560608201526040519485809481937fb858183f000000000000000000000000000000000000000000000000000000008352876004840152602483019061060f565b03925af180156102c5576103ba57005b6101fe9060203d6020116103db575b6103d3818361050c565b8101906105bd565b503d6103c9565b60207ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc8201126102b9576004359067ffffffffffffffff82116102b9577ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc8260c0920301126102b95760040190565b3573ffffffffffffffffffffffffffffffffffffffff811681036102b95790565b9035907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe1813603018212156102b9570180359067ffffffffffffffff82116102b9576020019181360383136102b957565b6080810190811067ffffffffffffffff8211176104df57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176104df57604052565b67ffffffffffffffff81116104df57601f017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200190565b9291926105938261054d565b916105a1604051938461050c565b8294818452818301116102b9578281602093845f960137010152565b908160209103126102b9575190565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b9060608061062684516080855260808501906105cc565b9373ffffffffffffffffffffffffffffffffffffffff602082015116602085015260408101516040850152015191015290565b6040519173ffffffffffffffffffffffffffffffffffffffff60208401917f095ea7b300000000000000000000000000000000000000000000000000000000835216938460248501526044840152604483526106b660648461050c565b5f8073ffffffffffffffffffffffffffffffffffffffff84169285519082855af1906106e0610782565b82610750575b5081610745575b50156106f857505050565b61025161074393604051907f095ea7b300000000000000000000000000000000000000000000000000000000602083015260248201525f60448201526044815261024b60648261050c565b565b90503b15155f6106ed565b80519192508115918215610768575b5050905f6106e6565b61077b92506020809183010191016107b1565b5f8061075f565b3d156107ac573d906107938261054d565b916107a1604051938461050c565b82523d5f602084013e565b606090565b908160209103126102b9575180151581036102b95790565b9073ffffffffffffffffffffffffffffffffffffffff61083792165f80604051936107f560408661050c565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af1610831610782565b916108eb565b80519081159182156108d1575b50501561084d57565b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b6108e492506020809183010191016107b1565b5f80610844565b9192901561096657508151156108ff575090565b3b156109085790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156109795750805190602001fd5b6109b7906040519182917f08c379a00000000000000000000000000000000000000000000000000000000083526020600484015260248301906105cc565b0390fd"

    public enum RevertReason: Equatable, Error {
        case unknownRevert(String, String)
    }

    public static func rewrapError(_ error: ABI.Function, value: ABI.Value) -> RevertReason {
        switch (error, value) {
        case let (e, v):
            return .unknownRevert(e.name, String(describing: v))
        }
    }

    public static let errors: [ABI.Function] = []
    public static let functions: [ABI.Function] = [swapAssetExactInFn, swapAssetExactOutFn]
    public static let swapAssetExactInFn = ABI.Function(
        name: "swapAssetExactIn",
        inputs: [.tuple([.address, .address, .address, .uint256, .uint256, .bytes])],
        outputs: []
    )

    public static func swapAssetExactIn(params: SwapParamsExactIn, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try swapAssetExactInFn.encoded(with: [params.asValue])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try swapAssetExactInFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, swapAssetExactInFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func swapAssetExactInDecode(input: Hex) throws -> (SwapParamsExactIn) {
        let decodedInput = try swapAssetExactInFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple1(.tuple6(.address(uniswapRouter),
                                 .address(recipient),
                                 .address(tokenFrom),
                                 .uint256(amount),
                                 .uint256(amountOutMinimum),
                                 .bytes(path))):
            return try (SwapParamsExactIn(uniswapRouter: uniswapRouter, recipient: recipient, tokenFrom: tokenFrom, amount: amount, amountOutMinimum: amountOutMinimum, path: path))
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, swapAssetExactInFn.inputTuple)
        }
    }

    public static let swapAssetExactOutFn = ABI.Function(
        name: "swapAssetExactOut",
        inputs: [.tuple([.address, .address, .address, .uint256, .uint256, .bytes])],
        outputs: []
    )

    public static func swapAssetExactOut(params: SwapParamsExactOut, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try swapAssetExactOutFn.encoded(with: [params.asValue])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try swapAssetExactOutFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, swapAssetExactOutFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func swapAssetExactOutDecode(input: Hex) throws -> (SwapParamsExactOut) {
        let decodedInput = try swapAssetExactOutFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple1(.tuple6(.address(uniswapRouter),
                                 .address(recipient),
                                 .address(tokenFrom),
                                 .uint256(amount),
                                 .uint256(amountInMaximum),
                                 .bytes(path))):
            return try (SwapParamsExactOut(uniswapRouter: uniswapRouter, recipient: recipient, tokenFrom: tokenFrom, amount: amount, amountInMaximum: amountInMaximum, path: path))
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, swapAssetExactOutFn.inputTuple)
        }
    }
}
