@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum Multicall {
    public static let creationCode: Hex = "0x60a08060405234602157306080526104fe908161002682396080518160ac0152f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c634d618e3b14610024575f80fd5b346103575760407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103575760043567ffffffffffffffff8111610357576100739036906004016103e9565b9060243567ffffffffffffffff8111610357576100949036906004016103e9565b9273ffffffffffffffffffffffffffffffffffffffff7f00000000000000000000000000000000000000000000000000000000000000001630146103c157838103610399576100ea6100e5826104a1565b61045d565b938185527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0610118836104a1565b015f5b8181106103885750505f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe184360301905b8381106101d657866040518091602082016020835281518091526040830190602060408260051b8601019301915f905b82821061018b57505050500390f35b919360206101c6827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc06001959799849503018652885161041a565b960192019201859493919261017c565b6101e96101e48286896104b9565b6104c9565b8382101561035b578160051b860135838112156103575786019081359167ffffffffffffffff83116103575760200190823603821361035757825f939284936040519283928337810184815203915af43d1561034f573d9067ffffffffffffffff82116103225761028160207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8501160161045d565b9182523d5f602084013e5b156102b1579060019161029f828a6104ea565b526102aa81896104ea565b500161014c565b9061031e6102c36101e483888b6104b9565b9273ffffffffffffffffffffffffffffffffffffffff6040519485947f61d3730e000000000000000000000000000000000000000000000000000000008652600486015216602484015260606044840152606483019061041a565b0390fd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b60609061028c565b5f80fd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b806060602080938a0101520161011b565b7fb4fa3fb3000000000000000000000000000000000000000000000000000000005f5260045ffd5b7fb870face000000000000000000000000000000000000000000000000000000005f5260045ffd5b9181601f840112156103575782359167ffffffffffffffff8311610357576020808501948460051b01011161035757565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f604051930116820182811067ffffffffffffffff82111761032257604052565b67ffffffffffffffff81116103225760051b60200190565b919081101561035b5760051b0190565b3573ffffffffffffffffffffffffffffffffffffffff811681036103575790565b805182101561035b5760209160051b01019056"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c634d618e3b14610024575f80fd5b346103575760407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103575760043567ffffffffffffffff8111610357576100739036906004016103e9565b9060243567ffffffffffffffff8111610357576100949036906004016103e9565b9273ffffffffffffffffffffffffffffffffffffffff7f00000000000000000000000000000000000000000000000000000000000000001630146103c157838103610399576100ea6100e5826104a1565b61045d565b938185527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0610118836104a1565b015f5b8181106103885750505f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe184360301905b8381106101d657866040518091602082016020835281518091526040830190602060408260051b8601019301915f905b82821061018b57505050500390f35b919360206101c6827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc06001959799849503018652885161041a565b960192019201859493919261017c565b6101e96101e48286896104b9565b6104c9565b8382101561035b578160051b860135838112156103575786019081359167ffffffffffffffff83116103575760200190823603821361035757825f939284936040519283928337810184815203915af43d1561034f573d9067ffffffffffffffff82116103225761028160207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f8501160161045d565b9182523d5f602084013e5b156102b1579060019161029f828a6104ea565b526102aa81896104ea565b500161014c565b9061031e6102c36101e483888b6104b9565b9273ffffffffffffffffffffffffffffffffffffffff6040519485947f61d3730e000000000000000000000000000000000000000000000000000000008652600486015216602484015260606044840152606483019061041a565b0390fd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b60609061028c565b5f80fd5b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b806060602080938a0101520161011b565b7fb4fa3fb3000000000000000000000000000000000000000000000000000000005f5260045ffd5b7fb870face000000000000000000000000000000000000000000000000000000005f5260045ffd5b9181601f840112156103575782359167ffffffffffffffff8311610357576020808501948460051b01011161035757565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f604051930116820182811067ffffffffffffffff82111761032257604052565b67ffffffffffffffff81116103225760051b60200190565b919081101561035b5760051b0190565b3573ffffffffffffffffffffffffffffffffffffffff811681036103575790565b805182101561035b5760209160051b01019056"

    public static let AlreadyInitializedError = ABI.Function(
        name: "AlreadyInitialized",
        inputs: []
    )

    public static let InvalidCallContextError = ABI.Function(
        name: "InvalidCallContext",
        inputs: []
    )

    public static let InvalidInputError = ABI.Function(
        name: "InvalidInput",
        inputs: []
    )

    public static let MulticallErrorError = ABI.Function(
        name: "MulticallError",
        inputs: [.uint256, .address, .bytes]
    )

    public enum RevertReason: Equatable, Error {
        case alreadyInitialized
        case invalidCallContext
        case invalidInput
        case multicallError(BigUInt, EthAddress, Hex)
        case unknownRevert(String, String)
    }

    public static func rewrapError(_ error: ABI.Function, value: ABI.Value) -> RevertReason {
        switch (error, value) {
        case (AlreadyInitializedError, _):
            return .alreadyInitialized
        case (InvalidCallContextError, _):
            return .invalidCallContext
        case (InvalidInputError, _):
            return .invalidInput
        case (MulticallErrorError, let .tuple3(.uint256(callIndex), .address(callContract), .bytes(err))):
            return .multicallError(callIndex, callContract, err)
        case let (e, v):
            return .unknownRevert(e.name, String(describing: v))
        }
    }

    public static let errors: [ABI.Function] = [AlreadyInitializedError, InvalidCallContextError, InvalidInputError, MulticallErrorError]
    public static let functions: [ABI.Function] = [runFn]
    public static let runFn = ABI.Function(
        name: "run",
        inputs: [.array(.address), .array(.bytes)],
        outputs: [.array(.bytes)]
    )

    public static func run(callContracts: [EthAddress], callDatas: [Hex], withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<[Hex], RevertReason> {
        do {
            let query = try runFn.encoded(with: [.array(.address, callContracts.map {
                .address($0)
            }), .array(.bytes, callDatas.map {
                .bytes($0)
            })])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try runFn.decode(output: result)

            switch decoded {
            case let .tuple1(.array(.bytes, var0)):
                return .success(var0.map {
                    $0.asHex!
                })
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, runFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func runDecode(input: Hex) throws -> ([EthAddress], [Hex]) {
        let decodedInput = try runFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple2(.array(.address, callContracts), .array(.bytes, callDatas)):
            return (callContracts.map { $0.asEthAddress! }, callDatas.map { $0.asHex! })
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, runFn.inputTuple)
        }
    }
}
