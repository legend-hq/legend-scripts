@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum ApproveAndSwap {
    public static let creationCode: Hex = "0x608080604052346015576105ed908161001a8239f35b5f80fdfe60806040526004361015610011575f80fd5b5f3560e01c639bc2f50914610024575f80fd5b346102c35760c03660031901126102c3576004356001600160a01b038116908181036102c3576024356001600160a01b03811691908290036102c3576064356001600160a01b03811691908290036102c3576084359160a4359167ffffffffffffffff83116102c357366023840112156102c35782600401359267ffffffffffffffff84116102c35736602485830101116102c3576040515f806020830163095ea7b360e01b81528a60248501526044356044850152604484526100e96064856103bb565b835190828b5af16100f86103f1565b8161038c575b5080610382575b1561033e575b506040516370a0823160e01b815230600482015293602085602481875afa9485156102cf575f95610303575b509160245f809493848295604051948593018337810182815203925af161015c6103f1565b90156102da575090602060249392604051948580926370a0823160e01b82523060048301525afa9283156102cf575f93610297575b5082039182116102835780821061026e575050604051905f806020840163095ea7b360e01b8152856024860152816044860152604485526101d36064866103bb565b84519082855af16101e26103f1565b8161023f575b5080610235575b156101f657005b61022e610233936040519063095ea7b360e01b602083015260248201525f6044820152604481526102286064826103bb565b8261046c565b61046c565b005b50803b15156101ef565b8051801592508215610254575b50505f6101e8565b6102679250602080918301019101610454565b5f8061024c565b6342e0f17d60e01b5f5260045260245260445ffd5b634e487b7160e01b5f52601160045260245ffd5b9092506020813d6020116102c7575b816102b3602093836103bb565b810103126102c35751915f610191565b5f80fd5b3d91506102a6565b6040513d5f823e3d90fd5b60405163bfa5626560e01b8152602060048201529081906102ff906024830190610430565b0390fd5b91929094506020823d602011610336575b81610321602093836103bb565b810103126102c3579051939091906024610137565b3d9150610314565b61037c9061037660405163095ea7b360e01b60208201528a60248201525f6044820152604481526103706064826103bb565b8961046c565b8761046c565b5f61010b565b50863b1515610105565b80518015925082156103a1575b50505f6100fe565b6103b49250602080918301019101610454565b5f80610399565b90601f8019910116810190811067ffffffffffffffff8211176103dd57604052565b634e487b7160e01b5f52604160045260245ffd5b3d1561042b573d9067ffffffffffffffff82116103dd5760405191610420601f8201601f1916602001846103bb565b82523d5f602084013e565b606090565b805180835260209291819084018484015e5f828201840152601f01601f1916010190565b908160209103126102c3575180151581036102c35790565b906104cc9160018060a01b03165f806040519361048a6040866103bb565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af16104c66103f1565b91610554565b805190811591821561053a575b5050156104e257565b60405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608490fd5b61054d9250602080918301019101610454565b5f806104d9565b919290156105b65750815115610568575090565b3b156105715790565b60405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606490fd5b8251909150156105c95750805190602001fd5b60405162461bcd60e51b8152602060048201529081906102ff90602483019061043056"
    public static let runtimeCode: Hex = "0x60806040526004361015610011575f80fd5b5f3560e01c639bc2f50914610024575f80fd5b346102c35760c03660031901126102c3576004356001600160a01b038116908181036102c3576024356001600160a01b03811691908290036102c3576064356001600160a01b03811691908290036102c3576084359160a4359167ffffffffffffffff83116102c357366023840112156102c35782600401359267ffffffffffffffff84116102c35736602485830101116102c3576040515f806020830163095ea7b360e01b81528a60248501526044356044850152604484526100e96064856103bb565b835190828b5af16100f86103f1565b8161038c575b5080610382575b1561033e575b506040516370a0823160e01b815230600482015293602085602481875afa9485156102cf575f95610303575b509160245f809493848295604051948593018337810182815203925af161015c6103f1565b90156102da575090602060249392604051948580926370a0823160e01b82523060048301525afa9283156102cf575f93610297575b5082039182116102835780821061026e575050604051905f806020840163095ea7b360e01b8152856024860152816044860152604485526101d36064866103bb565b84519082855af16101e26103f1565b8161023f575b5080610235575b156101f657005b61022e610233936040519063095ea7b360e01b602083015260248201525f6044820152604481526102286064826103bb565b8261046c565b61046c565b005b50803b15156101ef565b8051801592508215610254575b50505f6101e8565b6102679250602080918301019101610454565b5f8061024c565b6342e0f17d60e01b5f5260045260245260445ffd5b634e487b7160e01b5f52601160045260245ffd5b9092506020813d6020116102c7575b816102b3602093836103bb565b810103126102c35751915f610191565b5f80fd5b3d91506102a6565b6040513d5f823e3d90fd5b60405163bfa5626560e01b8152602060048201529081906102ff906024830190610430565b0390fd5b91929094506020823d602011610336575b81610321602093836103bb565b810103126102c3579051939091906024610137565b3d9150610314565b61037c9061037660405163095ea7b360e01b60208201528a60248201525f6044820152604481526103706064826103bb565b8961046c565b8761046c565b5f61010b565b50863b1515610105565b80518015925082156103a1575b50505f6100fe565b6103b49250602080918301019101610454565b5f80610399565b90601f8019910116810190811067ffffffffffffffff8211176103dd57604052565b634e487b7160e01b5f52604160045260245ffd5b3d1561042b573d9067ffffffffffffffff82116103dd5760405191610420601f8201601f1916602001846103bb565b82523d5f602084013e565b606090565b805180835260209291819084018484015e5f828201840152601f01601f1916010190565b908160209103126102c3575180151581036102c35790565b906104cc9160018060a01b03165f806040519361048a6040866103bb565b602085527f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564602086015260208151910182855af16104c66103f1565b91610554565b805190811591821561053a575b5050156104e257565b60405162461bcd60e51b815260206004820152602a60248201527f5361666545524332303a204552433230206f7065726174696f6e20646964206e6044820152691bdd081cdd58d8d9595960b21b6064820152608490fd5b61054d9250602080918301019101610454565b5f806104d9565b919290156105b65750815115610568575090565b3b156105715790565b60405162461bcd60e51b815260206004820152601d60248201527f416464726573733a2063616c6c20746f206e6f6e2d636f6e74726163740000006044820152606490fd5b8251909150156105c95750805190602001fd5b60405162461bcd60e51b8152602060048201529081906102ff90602483019061043056"

    public static let ApproveAndSwapFailedError = ABI.Function(
            name: "ApproveAndSwapFailed",
            inputs: [.bytes]
    )

    public static let TooMuchSlippageError = ABI.Function(
            name: "TooMuchSlippage",
            inputs: [.uint256, .uint256]
    )


    public enum RevertReason : Equatable, Error {
        case approveAndSwapFailed(Hex)
        case tooMuchSlippage(BigUInt, BigUInt)
        case unknownRevert(String, String)
    }
    public static func rewrapError(_ error: ABI.Function, value: ABI.Value) -> RevertReason {
        switch (error, value) {
        case (ApproveAndSwapFailedError, let .tuple1(.bytes(data))):
            return .approveAndSwapFailed(data)
            case (TooMuchSlippageError, let .tuple2(.uint256(expectedBuyAmount), .uint256(actualBuyAmount))):
            return .tooMuchSlippage(expectedBuyAmount, actualBuyAmount)
            case let (e, v):
            return .unknownRevert(e.name, String(describing: v))
            }
    }
    public static let errors: [ABI.Function] = [ApproveAndSwapFailedError, TooMuchSlippageError]
    public static let functions: [ABI.Function] = [runFn]
    public static let runFn = ABI.Function(
            name: "run",
            inputs: [.address, .address, .uint256, .address, .uint256, .bytes],
            outputs: []
    )

    public static func run(to: EthAddress, sellToken: EthAddress, sellAmount: BigUInt, buyToken: EthAddress, buyAmount: BigUInt, data: Hex, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<(), RevertReason> {
            do {
                let query = try runFn.encoded(with: [.address(to), .address(sellToken), .uint256(sellAmount), .address(buyToken), .uint256(buyAmount), .bytes(data)])
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


    public static func runDecode(input: Hex) throws -> (EthAddress, EthAddress, BigUInt, EthAddress, BigUInt, Hex) {
        let decodedInput = try runFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple6(.address(to), .address(sellToken), .uint256(sellAmount), .address(buyToken), .uint256(buyAmount), .bytes(data)):
            return  (to, sellToken, sellAmount, buyToken, buyAmount, data)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, runFn.inputTuple)
        }
    }

    }