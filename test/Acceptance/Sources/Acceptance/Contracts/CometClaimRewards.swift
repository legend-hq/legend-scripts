@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum CometClaimRewards {
    public static let creationCode: Hex = "0x60808060405234601557610283908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c637a53b63714610024575f80fd5b346101c85760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101c85760043567ffffffffffffffff81116101c8576100739036906004016101f4565b9060243567ffffffffffffffff81116101c8576100949036906004016101f4565b6044359373ffffffffffffffffffffffffffffffffffffffff85168095036101c8578181036101cc575f5b8181106100c857005b73ffffffffffffffffffffffffffffffffffffffff6100f06100eb838589610225565b610262565b16906101006100eb828688610225565b823b156101c85773ffffffffffffffffffffffffffffffffffffffff60645f928360405196879485937fb7034f7e0000000000000000000000000000000000000000000000000000000085521660048401528c6024840152600160448401525af180156101bd57610176575b60019150016100bf565b67ffffffffffffffff82116101905760019160405261016c565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b6040513d5f823e3d90fd5b5f80fd5b7fb4fa3fb3000000000000000000000000000000000000000000000000000000005f5260045ffd5b9181601f840112156101c85782359167ffffffffffffffff83116101c8576020808501948460051b0101116101c857565b91908110156102355760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b3573ffffffffffffffffffffffffffffffffffffffff811681036101c8579056"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c637a53b63714610024575f80fd5b346101c85760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101c85760043567ffffffffffffffff81116101c8576100739036906004016101f4565b9060243567ffffffffffffffff81116101c8576100949036906004016101f4565b6044359373ffffffffffffffffffffffffffffffffffffffff85168095036101c8578181036101cc575f5b8181106100c857005b73ffffffffffffffffffffffffffffffffffffffff6100f06100eb838589610225565b610262565b16906101006100eb828688610225565b823b156101c85773ffffffffffffffffffffffffffffffffffffffff60645f928360405196879485937fb7034f7e0000000000000000000000000000000000000000000000000000000085521660048401528c6024840152600160448401525af180156101bd57610176575b60019150016100bf565b67ffffffffffffffff82116101905760019160405261016c565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b6040513d5f823e3d90fd5b5f80fd5b7fb4fa3fb3000000000000000000000000000000000000000000000000000000005f5260045ffd5b9181601f840112156101c85782359167ffffffffffffffff83116101c8576020808501948460051b0101116101c857565b91908110156102355760051b0190565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b3573ffffffffffffffffffffffffffffffffffffffff811681036101c8579056"

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
    public static let functions: [ABI.Function] = [claimFn]
    public static let claimFn = ABI.Function(
        name: "claim",
        inputs: [.array(.address), .array(.address), .address],
        outputs: []
    )

    public static func claim(cometRewards: [EthAddress], comets: [EthAddress], recipient: EthAddress, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try claimFn.encoded(with: [.array(.address, cometRewards.map {
                .address($0)
            }), .array(.address, comets.map {
                .address($0)
            }), .address(recipient)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try claimFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, claimFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func claimDecode(input: Hex) throws -> ([EthAddress], [EthAddress], EthAddress) {
        let decodedInput = try claimFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.array(.address, cometRewards), .array(.address, comets), .address(recipient)):
            return (cometRewards.map { $0.asEthAddress! }, comets.map { $0.asEthAddress! }, recipient)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, claimFn.inputTuple)
        }
    }
}
