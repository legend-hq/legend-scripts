@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum CometSupplyMultipleAssetsAndBorrow {
    public static let creationCode: Hex = "0x60808060405234601557610561908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c63ff20388514610024575f80fd5b346101185760a0366003190112610118576004356001600160a01b038116908181036101185760243567ffffffffffffffff81116101185761006a9036906004016102cf565b9160443567ffffffffffffffff81116101185761008b9036906004016102cf565b606435946001600160a01b038616860361011857608435948282036102c0575f5b82811061011c57888888806100bd57005b823b156101185760405163f3fef3a360e01b81526001600160a01b039290921660048301526024820152905f908290604490829084905af1801561010d5761010157005b5f61010b91610338565b005b6040513d5f823e3d90fd5b5f80fd5b610127818587610300565b35610135575b6001016100ac565b6001600160a01b0361015061014b838686610300565b610324565b166101985f80896101a6610165878b8d610300565b60405163095ea7b360e01b602082019081526001600160a01b039094166024820152903560448201529485906064820190565b03601f198101865285610338565b83519082865af16101b561036e565b81610291575b5080610287575b15610243575b50506101d861014b828585610300565b906101e4818688610300565b35918a3b1561011857604051631e573fb760e31b81526001600160a01b0391909116600482015260248101929092525f82604481838e5af191821561010d57600192610233575b50905061012d565b5f61023d91610338565b5f61022b565b6102809161027b60405163095ea7b360e01b60208201528d60248201525f604482015260448152610275606482610338565b826103c5565b6103c5565b5f806101c8565b50813b15156101c2565b80518015925082156102a6575b50505f6101bb565b6102b992506020809183010191016103ad565b5f8061029e565b63b4fa3fb360e01b5f5260045ffd5b9181601f840112156101185782359167ffffffffffffffff8311610118576020808501948460051b01011161011857565b91908110156103105760051b0190565b634e487b7160e01b5f52603260045260245ffd5b356001600160a01b03811681036101185790565b90601f8019910116810190811067ffffffffffffffff82111761035a57604052565b634e487b7160e01b5f52604160045260245ffd5b3d156103a8573d9067ffffffffffffffff821161035a576040519161039d601f8201601f191660200184610338565b82523d5f602084013e565b606090565b90816020910312610118575180151581036101185790565b906104259160018060a01b03165f80604051936103e3604086610338565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af161041f61036e565b916104ad565b8051908115918215610493575b50501561043b57565b60405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608490fd5b6104a692506020809183010191016103ad565b5f80610432565b9192901561050f57508151156104c1575090565b3b156104ca5790565b60405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606490fd5b8251909150156105225750805190602001fd5b604460209160405192839162461bcd60e51b83528160048401528051918291826024860152018484015e5f828201840152601f01601f19168101030190fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c63ff20388514610024575f80fd5b346101185760a0366003190112610118576004356001600160a01b038116908181036101185760243567ffffffffffffffff81116101185761006a9036906004016102cf565b9160443567ffffffffffffffff81116101185761008b9036906004016102cf565b606435946001600160a01b038616860361011857608435948282036102c0575f5b82811061011c57888888806100bd57005b823b156101185760405163f3fef3a360e01b81526001600160a01b039290921660048301526024820152905f908290604490829084905af1801561010d5761010157005b5f61010b91610338565b005b6040513d5f823e3d90fd5b5f80fd5b610127818587610300565b35610135575b6001016100ac565b6001600160a01b0361015061014b838686610300565b610324565b166101985f80896101a6610165878b8d610300565b60405163095ea7b360e01b602082019081526001600160a01b039094166024820152903560448201529485906064820190565b03601f198101865285610338565b83519082865af16101b561036e565b81610291575b5080610287575b15610243575b50506101d861014b828585610300565b906101e4818688610300565b35918a3b1561011857604051631e573fb760e31b81526001600160a01b0391909116600482015260248101929092525f82604481838e5af191821561010d57600192610233575b50905061012d565b5f61023d91610338565b5f61022b565b6102809161027b60405163095ea7b360e01b60208201528d60248201525f604482015260448152610275606482610338565b826103c5565b6103c5565b5f806101c8565b50813b15156101c2565b80518015925082156102a6575b50505f6101bb565b6102b992506020809183010191016103ad565b5f8061029e565b63b4fa3fb360e01b5f5260045ffd5b9181601f840112156101185782359167ffffffffffffffff8311610118576020808501948460051b01011161011857565b91908110156103105760051b0190565b634e487b7160e01b5f52603260045260245ffd5b356001600160a01b03811681036101185790565b90601f8019910116810190811067ffffffffffffffff82111761035a57604052565b634e487b7160e01b5f52604160045260245ffd5b3d156103a8573d9067ffffffffffffffff821161035a576040519161039d601f8201601f191660200184610338565b82523d5f602084013e565b606090565b90816020910312610118575180151581036101185790565b906104259160018060a01b03165f80604051936103e3604086610338565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af161041f61036e565b916104ad565b8051908115918215610493575b50501561043b57565b60405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608490fd5b6104a692506020809183010191016103ad565b5f80610432565b9192901561050f57508151156104c1575090565b3b156104ca5790565b60405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606490fd5b8251909150156105225750805190602001fd5b604460209160405192839162461bcd60e51b83528160048401528051918291826024860152018484015e5f828201840152601f01601f19168101030190fd"

    public static let InvalidInputError = ABI.Function(
            name: "InvalidInput",
            inputs: []
    )


    public enum RevertReason : Equatable, Error {
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
    public static let functions: [ABI.Function] = [runFn]
    public static let runFn = ABI.Function(
            name: "run",
            inputs: [.address, .array(.address), .array(.uint256), .address, .uint256],
            outputs: []
    )

    public static func run(comet: EthAddress, assets: [EthAddress], amounts: [BigUInt], baseAsset: EthAddress, borrow: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<(), RevertReason> {
            do {
                let query = try runFn.encoded(with: [.address(comet), .array(.address, assets.map {
                                    .address($0)
                                }), .array(.uint256, amounts.map {
                                    .uint256($0)
                                }), .address(baseAsset), .uint256(borrow)])
                let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
                let decoded = try runFn.decode(output: result)

                switch decoded {
                case  .tuple0:
                    return .success(())
                default:
                    throw ABI.DecodeError.mismatchedType(decoded.schema, runFn.outputTuple)
                }
            } catch let EVM.QueryError.error(e, v) {
                return .failure(rewrapError(e, value: v))
            }
    }


    public static func runDecode(input: Hex) throws -> (EthAddress, [EthAddress], [BigUInt], EthAddress, BigUInt) {
        let decodedInput = try runFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple5(.address(comet), .array(.address, assets), .array(.uint256, amounts), .address(baseAsset), .uint256(borrow)):
            return  (comet, assets.map { $0.asEthAddress! }, amounts.map { $0.asBigUInt! }, baseAsset, borrow)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, runFn.inputTuple)
        }
    }

    }