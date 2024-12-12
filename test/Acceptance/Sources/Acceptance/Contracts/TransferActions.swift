@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum TransferActions {
    public static let creationCode: Hex = "0x6080806040523460155761052d908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c806392940bf9146101375763ae77a7081461002f575f80fd5b346101335760407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261013357610066610330565b7f951ae9fc8e231369dc30d9a40f12c78bb800223594870e32a7cda666d14d45d4906001825c1461010b575f808080936001865d73ffffffffffffffffffffffffffffffffffffffff60243591165af16100be6103c1565b90156100c9575f825d005b610107906040519182917f9a367e1700000000000000000000000000000000000000000000000000000000835260206004840152602483019061041e565b0390fd5b7f37ed32e8000000000000000000000000000000000000000000000000000000005f5260045ffd5b5f80fd5b346101335760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101335761016e610330565b6024359073ffffffffffffffffffffffffffffffffffffffff8216809203610133577f951ae9fc8e231369dc30d9a40f12c78bb800223594870e32a7cda666d14d45d4916001835c1461010b5773ffffffffffffffffffffffffffffffffffffffff610270926001855d165f806040519360208501907fa9059cbb0000000000000000000000000000000000000000000000000000000082526024860152604435604486015260448552610223606486610353565b60405194610232604087610353565b602086527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c65646020870152519082855af161026a6103c1565b91610461565b805190811591821561030d575b505015610289575f905d005b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b81925090602091810103126101335760200151801515810361013357828061027d565b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361013357565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761039457604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b3d15610419573d9067ffffffffffffffff8211610394576040519161040e601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200184610353565b82523d5f602084013e565b606090565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b919290156104dc5750815115610475575090565b3b1561047e5790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156104ef5750805190602001fd5b610107906040519182917f08c379a000000000000000000000000000000000000000000000000000000000835260206004840152602483019061041e56"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c806392940bf9146101375763ae77a7081461002f575f80fd5b346101335760407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261013357610066610330565b7f951ae9fc8e231369dc30d9a40f12c78bb800223594870e32a7cda666d14d45d4906001825c1461010b575f808080936001865d73ffffffffffffffffffffffffffffffffffffffff60243591165af16100be6103c1565b90156100c9575f825d005b610107906040519182917f9a367e1700000000000000000000000000000000000000000000000000000000835260206004840152602483019061041e565b0390fd5b7f37ed32e8000000000000000000000000000000000000000000000000000000005f5260045ffd5b5f80fd5b346101335760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126101335761016e610330565b6024359073ffffffffffffffffffffffffffffffffffffffff8216809203610133577f951ae9fc8e231369dc30d9a40f12c78bb800223594870e32a7cda666d14d45d4916001835c1461010b5773ffffffffffffffffffffffffffffffffffffffff610270926001855d165f806040519360208501907fa9059cbb0000000000000000000000000000000000000000000000000000000082526024860152604435604486015260448552610223606486610353565b60405194610232604087610353565b602086527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c65646020870152519082855af161026a6103c1565b91610461565b805190811591821561030d575b505015610289575f905d005b60846040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e60448201527f6f742073756363656564000000000000000000000000000000000000000000006064820152fd5b81925090602091810103126101335760200151801515810361013357828061027d565b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361013357565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff82111761039457604052565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b3d15610419573d9067ffffffffffffffff8211610394576040519161040e601f82017fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe01660200184610353565b82523d5f602084013e565b606090565b907fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f602080948051918291828752018686015e5f8582860101520116010190565b919290156104dc5750815115610475575090565b3b1561047e5790565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152fd5b8251909150156104ef5750805190602001fd5b610107906040519182917f08c379a000000000000000000000000000000000000000000000000000000000835260206004840152602483019061041e56"

    public static let ReentrantCallError = ABI.Function(
        name: "ReentrantCall",
        inputs: []
    )

    public static let TransferFailedError = ABI.Function(
        name: "TransferFailed",
        inputs: [.bytes]
    )

    public enum RevertReason: Equatable, Error {
        case reentrantCall
        case transferFailed(Hex)
        case unknownRevert(String, String)
    }

    public static func rewrapError(_ error: ABI.Function, value: ABI.Value) -> RevertReason {
        switch (error, value) {
        case (ReentrantCallError, _):
            return .reentrantCall
        case (TransferFailedError, let .tuple1(.bytes(data))):
            return .transferFailed(data)
        case let (e, v):
            return .unknownRevert(e.name, String(describing: v))
        }
    }

    public static let errors: [ABI.Function] = [ReentrantCallError, TransferFailedError]
    public static let functions: [ABI.Function] = [transferERC20TokenFn, transferNativeTokenFn]
    public static let transferERC20TokenFn = ABI.Function(
        name: "transferERC20Token",
        inputs: [.address, .address, .uint256],
        outputs: []
    )

    public static func transferERC20Token(token: EthAddress, recipient: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try transferERC20TokenFn.encoded(with: [.address(token), .address(recipient), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try transferERC20TokenFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, transferERC20TokenFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func transferERC20TokenDecode(input: Hex) throws -> (EthAddress, EthAddress, BigUInt) {
        let decodedInput = try transferERC20TokenFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple3(.address(token), .address(recipient), .uint256(amount)):
            return (token, recipient, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, transferERC20TokenFn.inputTuple)
        }
    }

    public static let transferNativeTokenFn = ABI.Function(
        name: "transferNativeToken",
        inputs: [.address, .uint256],
        outputs: []
    )

    public static func transferNativeToken(recipient: EthAddress, amount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try transferNativeTokenFn.encoded(with: [.address(recipient), .uint256(amount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try transferNativeTokenFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, transferNativeTokenFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func transferNativeTokenDecode(input: Hex) throws -> (EthAddress, BigUInt) {
        let decodedInput = try transferNativeTokenFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple2(.address(recipient), .uint256(amount)):
            return (recipient, amount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, transferNativeTokenFn.inputTuple)
        }
    }
}
