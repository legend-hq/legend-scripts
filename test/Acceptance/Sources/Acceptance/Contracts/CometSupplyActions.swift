@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum CometSupplyActions {
    public static let creationCode: Hex = "0x60808060405234601557610a4f908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f5f3560e01c80630c0a769b1461040f57806350a4548914610317578063c3da3590146101465763f1afb11f14610046575f80fd5b346101345760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610134578061007e610500565b610086610523565b61008e610546565b73ffffffffffffffffffffffffffffffffffffffff806064359216936100b5838287610666565b16803b156101425784928360649273ffffffffffffffffffffffffffffffffffffffff9460405197889687957f4232cd63000000000000000000000000000000000000000000000000000000008752166004860152602485015260448401525af18015610137576101235750f35b8161012d9161059a565b6101345780f35b80fd5b6040513d84823e3d90fd5b8480fd5b50346101345760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101345761017e610500565b60243567ffffffffffffffff81116103135761019e903690600401610569565b60449291923567ffffffffffffffff8111610142576101c1903690600401610569565b9390928483036102eb579193859273ffffffffffffffffffffffffffffffffffffffff81169291845b8781106101f5578580f35b61023473ffffffffffffffffffffffffffffffffffffffff61022061021b848c89610608565b610645565b168461022d84868c610608565b3591610666565b61024261021b828a87610608565b61024d82848a610608565b3590863b156102e7576040517ff2b9fdb800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff91909116600482015260248101919091528681604481838a5af19081156102dc5787916102c3575b50506001016101ea565b816102cd9161059a565b6102d857855f6102b9565b8580fd5b6040513d89823e3d90fd5b8780fd5b6004867fb4fa3fb3000000000000000000000000000000000000000000000000000000008152fd5b8280fd5b50346101345760a07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101345780610350610500565b610358610523565b610360610546565b916064359073ffffffffffffffffffffffffffffffffffffffff82168092036101425773ffffffffffffffffffffffffffffffffffffffff16803b156101425784928360849273ffffffffffffffffffffffffffffffffffffffff948560405198899788967f903231770000000000000000000000000000000000000000000000000000000088521660048701521660248501526044840152833560648401525af18015610137576101235750f35b50346104fc5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126104fc57610447610500565b61044f610523565b73ffffffffffffffffffffffffffffffffffffffff604435926104758482848616610666565b1691823b156104fc576040517ff2b9fdb800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9290921660048301526024820152905f908290604490829084905af180156104f1576104e3575080f35b6104ef91505f9061059a565b005b6040513d5f823e3d90fd5b5f80fd5b6004359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b6024359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b6044359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b9181601f840112156104fc5782359167ffffffffffffffff83116104fc576020808501948460051b0101116104fc57565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176105db57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b91908110156106185760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b3573ffffffffffffffffffffffffffffffffffffffff811681036104fc5790565b6040517f095ea7b3000000000000000000000000000000000000000000000000000000006020820190815273ffffffffffffffffffffffffffffffffffffffff8416602483015260448083019590955293815291926106c660648461059a565b5f8073ffffffffffffffffffffffffffffffffffffffff84169285519082855af1906106f06107b3565b82610781575b5081610776575b501561070857505050565b61076f6107749373ffffffffffffffffffffffffffffffffffffffff604051917f095ea7b30000000000000000000000000000000000000000000000000000000060208401521660248201525f60448201526044815261076960648261059a565b82610828565b610828565b565b90503b15155f6106fd565b80519192508115918215610799575b5050905f6106f6565b6107ac9250602080918301019101610810565b5f80610790565b3d1561080b573d9067ffffffffffffffff82116105db5760405191610800601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0166020018461059a565b82523d5f602084013e565b606090565b908160209103126104fc575180151581036104fc5790565b9073ffffffffffffffffffffffffffffffffffffffff61089692165f806040519361085460408661059a565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af16108906107b3565b9161094a565b8051908115918215610930575b5050156108ac57565b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b6109439250602080918301019101610810565b5f806108a3565b919290156109c5575081511561095e575090565b3b156109675790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156109d85750805190602001fd5b60446020917fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f6040519485937f08c379a00000000000000000000000000000000000000000000000000000000085528160048601528051918291826024880152018686015e5f85828601015201168101030190fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f5f3560e01c80630c0a769b1461040f57806350a4548914610317578063c3da3590146101465763f1afb11f14610046575f80fd5b346101345760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610134578061007e610500565b610086610523565b61008e610546565b73ffffffffffffffffffffffffffffffffffffffff806064359216936100b5838287610666565b16803b156101425784928360649273ffffffffffffffffffffffffffffffffffffffff9460405197889687957f4232cd63000000000000000000000000000000000000000000000000000000008752166004860152602485015260448401525af18015610137576101235750f35b8161012d9161059a565b6101345780f35b80fd5b6040513d84823e3d90fd5b8480fd5b50346101345760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101345761017e610500565b60243567ffffffffffffffff81116103135761019e903690600401610569565b60449291923567ffffffffffffffff8111610142576101c1903690600401610569565b9390928483036102eb579193859273ffffffffffffffffffffffffffffffffffffffff81169291845b8781106101f5578580f35b61023473ffffffffffffffffffffffffffffffffffffffff61022061021b848c89610608565b610645565b168461022d84868c610608565b3591610666565b61024261021b828a87610608565b61024d82848a610608565b3590863b156102e7576040517ff2b9fdb800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff91909116600482015260248101919091528681604481838a5af19081156102dc5787916102c3575b50506001016101ea565b816102cd9161059a565b6102d857855f6102b9565b8580fd5b6040513d89823e3d90fd5b8780fd5b6004867fb4fa3fb3000000000000000000000000000000000000000000000000000000008152fd5b8280fd5b50346101345760a07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101345780610350610500565b610358610523565b610360610546565b916064359073ffffffffffffffffffffffffffffffffffffffff82168092036101425773ffffffffffffffffffffffffffffffffffffffff16803b156101425784928360849273ffffffffffffffffffffffffffffffffffffffff948560405198899788967f903231770000000000000000000000000000000000000000000000000000000088521660048701521660248501526044840152833560648401525af18015610137576101235750f35b50346104fc5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126104fc57610447610500565b61044f610523565b73ffffffffffffffffffffffffffffffffffffffff604435926104758482848616610666565b1691823b156104fc576040517ff2b9fdb800000000000000000000000000000000000000000000000000000000815273ffffffffffffffffffffffffffffffffffffffff9290921660048301526024820152905f908290604490829084905af180156104f1576104e3575080f35b6104ef91505f9061059a565b005b6040513d5f823e3d90fd5b5f80fd5b6004359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b6024359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b6044359073ffffffffffffffffffffffffffffffffffffffff821682036104fc57565b9181601f840112156104fc5782359167ffffffffffffffff83116104fc576020808501948460051b0101116104fc57565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176105db57604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b91908110156106185760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b3573ffffffffffffffffffffffffffffffffffffffff811681036104fc5790565b6040517f095ea7b3000000000000000000000000000000000000000000000000000000006020820190815273ffffffffffffffffffffffffffffffffffffffff8416602483015260448083019590955293815291926106c660648461059a565b5f8073ffffffffffffffffffffffffffffffffffffffff84169285519082855af1906106f06107b3565b82610781575b5081610776575b501561070857505050565b61076f6107749373ffffffffffffffffffffffffffffffffffffffff604051917f095ea7b30000000000000000000000000000000000000000000000000000000060208401521660248201525f60448201526044815261076960648261059a565b82610828565b610828565b565b90503b15155f6106fd565b80519192508115918215610799575b5050905f6106f6565b6107ac9250602080918301019101610810565b5f80610790565b3d1561080b573d9067ffffffffffffffff82116105db5760405191610800601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0166020018461059a565b82523d5f602084013e565b606090565b908160209103126104fc575180151581036104fc5790565b9073ffffffffffffffffffffffffffffffffffffffff61089692165f806040519361085460408661059a565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af16108906107b3565b9161094a565b8051908115918215610930575b5050156108ac57565b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b6109439250602080918301019101610810565b5f806108a3565b919290156109c5575081511561095e575090565b3b156109675790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156109d85750805190602001fd5b60446020917fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f6040519485937f08c379a00000000000000000000000000000000000000000000000000000000085528160048601528051918291826024880152018686015e5f85828601015201168101030190fd"

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
    public static let functions: [ABI.Function] = [supplyFn, supplyFromFn, supplyMultipleAssetsFn, supplyToFn]
    public static let supplyFn = ABI.Function(
        name: "supply",
        inputs: [.address, .address, .uint256],
        outputs: []
    )

    public static func supply(comet: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try supplyFn.encoded(with: [.address(comet), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try supplyFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, supplyFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func supplyDecode(input: Hex) throws -> (EthAddress, EthAddress, BigUInt) {
        let decodedInput = try supplyFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.address(comet), .address(asset), .uint256(amount)):
            return (comet, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, supplyFn.inputTuple)
        }
    }

    public static let supplyFromFn = ABI.Function(
        name: "supplyFrom",
        inputs: [.address, .address, .address, .address, .uint256],
        outputs: []
    )

    public static func supplyFrom(comet: EthAddress, from: EthAddress, to: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try supplyFromFn.encoded(with: [.address(comet), .address(from), .address(to), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try supplyFromFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, supplyFromFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func supplyFromDecode(input: Hex) throws -> (EthAddress, EthAddress, EthAddress, EthAddress, BigUInt) {
        let decodedInput = try supplyFromFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple5(.address(comet), .address(from), .address(to), .address(asset), .uint256(amount)):
            return (comet, from, to, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, supplyFromFn.inputTuple)
        }
    }

    public static let supplyMultipleAssetsFn = ABI.Function(
        name: "supplyMultipleAssets",
        inputs: [.address, .array(.address), .array(.uint256)],
        outputs: []
    )

    public static func supplyMultipleAssets(comet: EthAddress, assets: [EthAddress], amounts: [BigUInt], withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try supplyMultipleAssetsFn.encoded(with: [.address(comet), .array(.address, assets.map {
                .address($0)
            }), .array(.uint256, amounts.map {
                .uint256($0)
            })])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try supplyMultipleAssetsFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, supplyMultipleAssetsFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func supplyMultipleAssetsDecode(input: Hex) throws -> (EthAddress, [EthAddress], [BigUInt]) {
        let decodedInput = try supplyMultipleAssetsFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.address(comet), .array(.address, assets), .array(.uint256, amounts)):
            return (comet, assets.map { $0.asEthAddress! }, amounts.map { $0.asBigUInt! })
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, supplyMultipleAssetsFn.inputTuple)
        }
    }

    public static let supplyToFn = ABI.Function(
        name: "supplyTo",
        inputs: [.address, .address, .address, .uint256],
        outputs: []
    )

    public static func supplyTo(comet: EthAddress, to: EthAddress, asset: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try supplyToFn.encoded(with: [.address(comet), .address(to), .address(asset), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try supplyToFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, supplyToFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func supplyToDecode(input: Hex) throws -> (EthAddress, EthAddress, EthAddress, BigUInt) {
        let decodedInput = try supplyToFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple4(.address(comet), .address(to), .address(asset), .uint256(amount)):
            return (comet, to, asset, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, supplyToFn.inputTuple)
        }
    }
}
