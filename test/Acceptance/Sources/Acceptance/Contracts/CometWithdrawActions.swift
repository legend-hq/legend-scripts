@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum CometWithdrawActions {
    public static let creationCode: Hex = "0x60808060405234601557610605908161001a8239f35b5f80fdfe6080806040526004361015610012575f80fd5b5f905f3560e01c90816306c0b3cc146103d657508063347a377f1461022c57806346f711ad146101305763d9caed121461004a575f80fd5b3461011e5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e57806100826104c0565b73ffffffffffffffffffffffffffffffffffffffff61009f6104e3565b9116803b1561012c576040517ff3fef3a300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9290921660048301526044803560248401528391839190829084905af180156101215761010d5750f35b816101179161055a565b61011e5780f35b80fd5b6040513d84823e3d90fd5b5050fd5b503461011e5760a07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e57806101696104c0565b6101716104e3565b610179610506565b916064359073ffffffffffffffffffffffffffffffffffffffff82168092036102285773ffffffffffffffffffffffffffffffffffffffff16803b156102285784928360849273ffffffffffffffffffffffffffffffffffffffff948560405198899788967f264413180000000000000000000000000000000000000000000000000000000088521660048701521660248501526044840152833560648401525af180156101215761010d5750f35b8480fd5b503461011e5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e576102646104c0565b60243567ffffffffffffffff81116103d257610284903690600401610529565b9060443567ffffffffffffffff8111610228576102a5903690600401610529565b90928181036103aa57908592949173ffffffffffffffffffffffffffffffffffffffff849316925b8181106102d8578480f35b6102e38183896105c8565b3573ffffffffffffffffffffffffffffffffffffffff811681036103a65761030c8285896105c8565b3590853b156103a2576040517ff3fef3a300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9190911660048201526024810191909152858160448183895af1908115610397578691610382575b50506001016102cd565b8161038c9161055a565b61022857845f610378565b6040513d88823e3d90fd5b8680fd5b8580fd5b6004867fb4fa3fb3000000000000000000000000000000000000000000000000000000008152fd5b8280fd5b9050346104bc5760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126104bc5761040f6104c0565b6104176104e3565b9073ffffffffffffffffffffffffffffffffffffffff610435610506565b9116803b156104bc57835f60649273ffffffffffffffffffffffffffffffffffffffff83958184987fc3b35a7e000000000000000000000000000000000000000000000000000000008752166004860152166024840152833560448401525af180156104b1576104a3575080f35b6104af91505f9061055a565b005b6040513d5f823e3d90fd5b5f80fd5b6004359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b6024359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b6044359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b9181601f840112156104bc5782359167ffffffffffffffff83116104bc576020808501948460051b0101116104bc57565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761059b57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b91908110156105d85760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd"
    public static let runtimeCode: Hex = "0x6080806040526004361015610012575f80fd5b5f905f3560e01c90816306c0b3cc146103d657508063347a377f1461022c57806346f711ad146101305763d9caed121461004a575f80fd5b3461011e5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e57806100826104c0565b73ffffffffffffffffffffffffffffffffffffffff61009f6104e3565b9116803b1561012c576040517ff3fef3a300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9290921660048301526044803560248401528391839190829084905af180156101215761010d5750f35b816101179161055a565b61011e5780f35b80fd5b6040513d84823e3d90fd5b5050fd5b503461011e5760a07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e57806101696104c0565b6101716104e3565b610179610506565b916064359073ffffffffffffffffffffffffffffffffffffffff82168092036102285773ffffffffffffffffffffffffffffffffffffffff16803b156102285784928360849273ffffffffffffffffffffffffffffffffffffffff948560405198899788967f264413180000000000000000000000000000000000000000000000000000000088521660048701521660248501526044840152833560648401525af180156101215761010d5750f35b8480fd5b503461011e5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261011e576102646104c0565b60243567ffffffffffffffff81116103d257610284903690600401610529565b9060443567ffffffffffffffff8111610228576102a5903690600401610529565b90928181036103aa57908592949173ffffffffffffffffffffffffffffffffffffffff849316925b8181106102d8578480f35b6102e38183896105c8565b3573ffffffffffffffffffffffffffffffffffffffff811681036103a65761030c8285896105c8565b3590853b156103a2576040517ff3fef3a300000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9190911660048201526024810191909152858160448183895af1908115610397578691610382575b50506001016102cd565b8161038c9161055a565b61022857845f610378565b6040513d88823e3d90fd5b8680fd5b8580fd5b6004867fb4fa3fb3000000000000000000000000000000000000000000000000000000008152fd5b8280fd5b9050346104bc5760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126104bc5761040f6104c0565b6104176104e3565b9073ffffffffffffffffffffffffffffffffffffffff610435610506565b9116803b156104bc57835f60649273ffffffffffffffffffffffffffffffffffffffff83958184987fc3b35a7e000000000000000000000000000000000000000000000000000000008752166004860152166024840152833560448401525af180156104b1576104a3575080f35b6104af91505f9061055a565b005b6040513d5f823e3d90fd5b5f80fd5b6004359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b6024359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b6044359073ffffffffffffffffffffffffffffffffffffffff821682036104bc57565b9181601f840112156104bc5782359167ffffffffffffffff83116104bc576020808501948460051b0101116104bc57565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761059b57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b91908110156105d85760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd"

    public static let InvalidInputError = ABI.Function(
        name: "InvalidInput",
        inputs: []
    )

    public enum RevertReason: Equatable, Error {
        case invalidInput
        case unknownRevert(String, String)
    }

    public static func rewrapError(_ error: ABI.Function, value: ABI.Value) -> RevertReason {
        switch (error, value) {
        case (InvalidInputError, _):
            return .invalidInput
        case let (e, v):
            return .unknownRevert(e.name, String(describing: v))
        }
    }

    public static let errors: [ABI.Function] = [InvalidInputError]
    public static let functions: [ABI.Function] = [withdrawFn, withdrawFromFn, withdrawMultipleAssetsFn, withdrawToFn]
    public static let withdrawFn = ABI.Function(
        name: "withdraw",
        inputs: [.address, .address, .uint256],
        outputs: []
    )

    public static func withdraw(comet: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try withdrawFn.encoded(with: [.address(comet), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try withdrawFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, withdrawFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func withdrawDecode(input: Hex) throws -> (EthAddress, EthAddress, BigUInt) {
        let decodedInput = try withdrawFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.address(comet), .address(asset), .uint256(amount)):
            return (comet, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, withdrawFn.inputTuple)
        }
    }

    public static let withdrawFromFn = ABI.Function(
        name: "withdrawFrom",
        inputs: [.address, .address, .address, .address, .uint256],
        outputs: []
    )

    public static func withdrawFrom(comet: EthAddress, from: EthAddress, to: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try withdrawFromFn.encoded(with: [.address(comet), .address(from), .address(to), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try withdrawFromFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, withdrawFromFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func withdrawFromDecode(input: Hex) throws -> (EthAddress, EthAddress, EthAddress, EthAddress, BigUInt) {
        let decodedInput = try withdrawFromFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple5(.address(comet), .address(from), .address(to), .address(asset), .uint256(amount)):
            return (comet, from, to, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, withdrawFromFn.inputTuple)
        }
    }

    public static let withdrawMultipleAssetsFn = ABI.Function(
        name: "withdrawMultipleAssets",
        inputs: [.address, .array(.address), .array(.uint256)],
        outputs: []
    )

    public static func withdrawMultipleAssets(comet: EthAddress, assets: [EthAddress], amounts: [BigUInt], withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try withdrawMultipleAssetsFn.encoded(with: [.address(comet), .array(.address, assets.map {
                .address($0)
            }), .array(.uint256, amounts.map {
                .uint256($0)
            })])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try withdrawMultipleAssetsFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, withdrawMultipleAssetsFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func withdrawMultipleAssetsDecode(input: Hex) throws -> (EthAddress, [EthAddress], [BigUInt]) {
        let decodedInput = try withdrawMultipleAssetsFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.address(comet), .array(.address, assets), .array(.uint256, amounts)):
            return (comet, assets.map { $0.asEthAddress! }, amounts.map { $0.asBigUInt! })
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, withdrawMultipleAssetsFn.inputTuple)
        }
    }

    public static let withdrawToFn = ABI.Function(
        name: "withdrawTo",
        inputs: [.address, .address, .address, .uint256],
        outputs: []
    )

    public static func withdrawTo(comet: EthAddress, to: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try withdrawToFn.encoded(with: [.address(comet), .address(to), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try withdrawToFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, withdrawToFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func withdrawToDecode(input: Hex) throws -> (EthAddress, EthAddress, EthAddress, BigUInt) {
        let decodedInput = try withdrawToFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple4(.address(comet), .address(to), .address(asset), .uint256(amount)):
            return (comet, to, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, withdrawToFn.inputTuple)
        }
    }
}
