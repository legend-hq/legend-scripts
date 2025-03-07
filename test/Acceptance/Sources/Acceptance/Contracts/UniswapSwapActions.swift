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

    public static let creationCode: Hex = "0x608060405234601c57600e6020565b6110a561002b82396110a590f35b6026565b60405190565b5f80fdfe60806040526004361015610013575b610153565b61001d5f3561003c565b8063bc4610bc146100375763dfd42a660361000e57610120565b6100a5565b60e01c90565b60405190565b5f80fd5b5f80fd5b5f80fd5b5f80fd5b908160c09103126100665790565b610054565b9060208282031261009b575f82013567ffffffffffffffff8111610096576100939201610058565b90565b610050565b61004c565b5f0190565b346100d3576100bd6100b836600461006b565b6104db565b6100c5610042565b806100cf816100a0565b0390f35b610048565b908160c09103126100e65790565b610054565b9060208282031261011b575f82013567ffffffffffffffff81116101165761011392016100d8565b90565b610050565b61004c565b3461014e576101386101333660046100eb565b61078b565b610140610042565b8061014a816100a0565b0390f35b610048565b5f80fd5b90565b61016381610157565b0361016a57565b5f80fd5b356101788161015a565b90565b73ffffffffffffffffffffffffffffffffffffffff1690565b61019d9061017b565b90565b6101a981610194565b036101b057565b5f80fd5b356101be816101a0565b90565b90565b6101d86101d36101dd9261017b565b6101c1565b61017b565b90565b6101e9906101c4565b90565b6101f5906101e0565b90565b610201906101c4565b90565b61020d906101f8565b90565b610219906101f8565b90565b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b9061025d9061021c565b810190811067ffffffffffffffff82111761027757604052565b610226565b60e01b90565b9050519061028f8261015a565b565b906020828203126102aa576102a7915f01610282565b90565b61004c565b6102b890610194565b9052565b91906102cf905f602085019401906102af565b565b6102d9610042565b3d5f823e3d90fd5b6102ea906101c4565b90565b6102f6906102e1565b90565b610302906101f8565b90565b5f80fd5b5f80fd5b5f80fd5b903590600160200381360303821215610353570180359067ffffffffffffffff821161034e5760200191600182023603831361034957565b61030d565b610309565b610305565b9061036b610364610042565b9283610253565b565b6103776080610358565b90565b5f80fd5b67ffffffffffffffff811161039c5761039860209161021c565b0190565b610226565b90825f939282370152565b909291926103c16103bc8261037e565b610358565b938185526020850190828401116103dd576103db926103a1565b565b61037a565b6103ed9136916103ac565b90565b52565b906103fd90610194565b9052565b9061040b90610157565b9052565b5190565b60209181520190565b90825f9392825e0152565b61044661044f6020936104549361043d8161040f565b93848093610413565b9586910161041c565b61021c565b0190565b61046190610194565b9052565b61046e90610157565b9052565b906104c090606080610491608084015f8701518582035f870152610427565b946104a460208201516020860190610458565b6104b660408201516040860190610465565b0151910190610465565b90565b6104d89160208201915f818403910152610472565b90565b6104e76060820161016e565b8061051a6105147fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff610157565b91610157565b1461064d575b6020908261055b61053e610539604061060a97016101b4565b6101ec565b6105495f84016101b4565b6105556060850161016e565b916109f1565b6105ff5f61057a6105756105708386016101b4565b6102ed565b6102f9565b926105eb6105d96105e263b858183f936105988160a0810190610311565b9390996105d16105c96105ba60808f6105b29088016101b4565b94960161016e565b966105c361036d565b9d6103e2565b898d016103f0565b8b8b016103f3565b60408901610401565b60608701610401565b6105f3610042565b9687958694859361027c565b8352600483016104c3565b03925af180156106485761061c575b50565b61063c9060203d8111610641575b6106348183610253565b810190610291565b610619565b503d61062a565b6102d1565b506106a1602061066f61066a610665604086016101b4565b6101ec565b610204565b6370a082319061069661068130610210565b9261068a610042565b9586948593849361027c565b8352600483016102bc565b03915afa9182156106f15761060a926020925f916106c4575b5091509150610520565b6106e49150833d81116106ea575b6106dc8183610253565b810190610291565b5f6106ba565b503d6106d2565b6102d1565b6107006080610358565b90565b9061075190606080610722608084015f8701518582035f870152610427565b9461073560208201516020860190610458565b61074760408201516040860190610465565b0151910190610465565b90565b6107699160208201915f818403910152610703565b90565b90565b61078361077e6107889261076c565b6101c1565b610157565b90565b6107bf6107a261079d604084016101b4565b6101ec565b6107ad5f84016101b4565b6107b96080850161016e565b916109f1565b61087c602061085d6107e26107dd6107d85f87016101b4565b6102ed565b6102f9565b6108715f6309b813466107f98860a0810190610311565b6108548a61084b61080e8b839b969b016101b4565b61084361083b61082c60806108256060880161016e565b960161016e565b966108356106f6565b9d6103e2565b898d016103f0565b8b8b016103f3565b60408901610401565b60608701610401565b610865610042565b9687958694859361027c565b835260048301610754565b03925af190811561091b575f916108ed575b506108ac6108a66108a16080850161016e565b610157565b91610157565b106108b5575b50565b806108d85f6108d16108cc60406108e796016101b4565b6101ec565b92016101b4565b6108e15f61076f565b916109f1565b5f6108b2565b61090e915060203d8111610914575b6109068183610253565b810190610291565b5f61088e565b503d6108fc565b6102d1565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b61096261095d61096792610920565b61027c565b610929565b90565b61097390610157565b9052565b91602061099892949361099160408201965f8301906102af565b019061096a565b565b151590565b60ff1690565b6109b96109b46109be9261076c565b6101c1565b61099f565b90565b6109ca906109a5565b9052565b9160206109ef9294936109e860408201965f8301906102af565b01906109c1565b565b9091610a32600491610a23610a0963095ea7b361094e565b9186610a13610042565b9586946020860190815201610977565b60208201810382520382610253565b90610a47610a41828490610b35565b1561099a565b610a51575b505050565b610a9e6004610aa394610a998491610a8a610a6f63095ea7b361094e565b915f90610a7a610042565b96879460208601908152016109ce565b60208201810382520383610253565b610d27565b610d27565b5f8080610a4c565b5f90565b90610ac1610abc8361037e565b610358565b918252565b606090565b3d5f14610ae657610adb3d610aaf565b903d5f602084013e5b565b610aee610ac6565b90610ae4565b610afd8161099a565b03610b0457565b5f80fd5b90505190610b1582610af4565b565b90602082820312610b3057610b2d915f01610b08565b90565b61004c565b905f8091610b41610aab565b50610b4b84610204565b9082602082019151925af1610b5e610acb565b81610b89575b509081610b70575b5090565b610b839150610b7e90610204565b610d93565b5f610b6c565b9050610b948161040f565b610ba6610ba05f61076f565b91610157565b14908115610bb6575b505f610b64565b610bd191506020610bc68261040f565b818301019101610b17565b5f610baf565b67ffffffffffffffff8111610bf557610bf160209161021c565b0190565b610226565b90610c0c610c0783610bd7565b610358565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b610c426020610bfa565b90610c4f60208301610c11565b565b610c59610c38565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b610cbf602a604092610c5c565b610cc881610c65565b0190565b610ce19060208101905f818303910152610cb2565b90565b15610ceb57565b610cf3610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610d2360048201610ccc565b0390fd5b610d7091610d37610d4692610204565b90610d40610c51565b91610db3565b610d4f8161040f565b610d61610d5b5f61076f565b91610157565b14908115610d72575b50610ce4565b565b610d8d91506020610d828261040f565b818301019101610b17565b5f610d6a565b610d9b610aab565b503b610daf610da95f61076f565b91610157565b1190565b90610dd29291610dc1610ac6565b5090610dcc5f61076f565b91610ea3565b90565b610dde906101f8565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b610e3b6026604092610c5c565b610e4481610de1565b0190565b610e5d9060208101905f818303910152610e2e565b90565b15610e6757565b610e6f610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610e9f60048201610e48565b0390fd5b915f8091610ef99593610eb4610ac6565b50610edb610ec130610dd5565b31610ed4610ece85610157565b91610157565b1015610e60565b8591602082019151925af191610eef610acb565b9092909192610f98565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b610f30601d602092610c5c565b610f3981610efc565b0190565b610f529060208101905f818303910152610f23565b90565b15610f5c57565b610f64610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610f9460048201610f3d565b0390fd5b919290610fa3610ac6565b505f14610fe75750610fb48261040f565b610fc6610fc05f61076f565b91610157565b14610fd0575b5090565b610fdc610fe191610d93565b610f55565b5f610fcc565b8261103a565b5190565b61101061101960209361101e9361100781610fed565b93848093610c5c565b9586910161041c565b61021c565b0190565b6110379160208201915f818403910152610ff1565b90565b906110448261040f565b6110566110505f61076f565b91610157565b115f146110665750805190602001fd5b6110a190611072610042565b9182917f08c379a000000000000000000000000000000000000000000000000000000000835260048301611022565b0390fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610013575b610153565b61001d5f3561003c565b8063bc4610bc146100375763dfd42a660361000e57610120565b6100a5565b60e01c90565b60405190565b5f80fd5b5f80fd5b5f80fd5b5f80fd5b908160c09103126100665790565b610054565b9060208282031261009b575f82013567ffffffffffffffff8111610096576100939201610058565b90565b610050565b61004c565b5f0190565b346100d3576100bd6100b836600461006b565b6104db565b6100c5610042565b806100cf816100a0565b0390f35b610048565b908160c09103126100e65790565b610054565b9060208282031261011b575f82013567ffffffffffffffff81116101165761011392016100d8565b90565b610050565b61004c565b3461014e576101386101333660046100eb565b61078b565b610140610042565b8061014a816100a0565b0390f35b610048565b5f80fd5b90565b61016381610157565b0361016a57565b5f80fd5b356101788161015a565b90565b73ffffffffffffffffffffffffffffffffffffffff1690565b61019d9061017b565b90565b6101a981610194565b036101b057565b5f80fd5b356101be816101a0565b90565b90565b6101d86101d36101dd9261017b565b6101c1565b61017b565b90565b6101e9906101c4565b90565b6101f5906101e0565b90565b610201906101c4565b90565b61020d906101f8565b90565b610219906101f8565b90565b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b9061025d9061021c565b810190811067ffffffffffffffff82111761027757604052565b610226565b60e01b90565b9050519061028f8261015a565b565b906020828203126102aa576102a7915f01610282565b90565b61004c565b6102b890610194565b9052565b91906102cf905f602085019401906102af565b565b6102d9610042565b3d5f823e3d90fd5b6102ea906101c4565b90565b6102f6906102e1565b90565b610302906101f8565b90565b5f80fd5b5f80fd5b5f80fd5b903590600160200381360303821215610353570180359067ffffffffffffffff821161034e5760200191600182023603831361034957565b61030d565b610309565b610305565b9061036b610364610042565b9283610253565b565b6103776080610358565b90565b5f80fd5b67ffffffffffffffff811161039c5761039860209161021c565b0190565b610226565b90825f939282370152565b909291926103c16103bc8261037e565b610358565b938185526020850190828401116103dd576103db926103a1565b565b61037a565b6103ed9136916103ac565b90565b52565b906103fd90610194565b9052565b9061040b90610157565b9052565b5190565b60209181520190565b90825f9392825e0152565b61044661044f6020936104549361043d8161040f565b93848093610413565b9586910161041c565b61021c565b0190565b61046190610194565b9052565b61046e90610157565b9052565b906104c090606080610491608084015f8701518582035f870152610427565b946104a460208201516020860190610458565b6104b660408201516040860190610465565b0151910190610465565b90565b6104d89160208201915f818403910152610472565b90565b6104e76060820161016e565b8061051a6105147fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff610157565b91610157565b1461064d575b6020908261055b61053e610539604061060a97016101b4565b6101ec565b6105495f84016101b4565b6105556060850161016e565b916109f1565b6105ff5f61057a6105756105708386016101b4565b6102ed565b6102f9565b926105eb6105d96105e263b858183f936105988160a0810190610311565b9390996105d16105c96105ba60808f6105b29088016101b4565b94960161016e565b966105c361036d565b9d6103e2565b898d016103f0565b8b8b016103f3565b60408901610401565b60608701610401565b6105f3610042565b9687958694859361027c565b8352600483016104c3565b03925af180156106485761061c575b50565b61063c9060203d8111610641575b6106348183610253565b810190610291565b610619565b503d61062a565b6102d1565b506106a1602061066f61066a610665604086016101b4565b6101ec565b610204565b6370a082319061069661068130610210565b9261068a610042565b9586948593849361027c565b8352600483016102bc565b03915afa9182156106f15761060a926020925f916106c4575b5091509150610520565b6106e49150833d81116106ea575b6106dc8183610253565b810190610291565b5f6106ba565b503d6106d2565b6102d1565b6107006080610358565b90565b9061075190606080610722608084015f8701518582035f870152610427565b9461073560208201516020860190610458565b61074760408201516040860190610465565b0151910190610465565b90565b6107699160208201915f818403910152610703565b90565b90565b61078361077e6107889261076c565b6101c1565b610157565b90565b6107bf6107a261079d604084016101b4565b6101ec565b6107ad5f84016101b4565b6107b96080850161016e565b916109f1565b61087c602061085d6107e26107dd6107d85f87016101b4565b6102ed565b6102f9565b6108715f6309b813466107f98860a0810190610311565b6108548a61084b61080e8b839b969b016101b4565b61084361083b61082c60806108256060880161016e565b960161016e565b966108356106f6565b9d6103e2565b898d016103f0565b8b8b016103f3565b60408901610401565b60608701610401565b610865610042565b9687958694859361027c565b835260048301610754565b03925af190811561091b575f916108ed575b506108ac6108a66108a16080850161016e565b610157565b91610157565b106108b5575b50565b806108d85f6108d16108cc60406108e796016101b4565b6101ec565b92016101b4565b6108e15f61076f565b916109f1565b5f6108b2565b61090e915060203d8111610914575b6109068183610253565b810190610291565b5f61088e565b503d6108fc565b6102d1565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b61096261095d61096792610920565b61027c565b610929565b90565b61097390610157565b9052565b91602061099892949361099160408201965f8301906102af565b019061096a565b565b151590565b60ff1690565b6109b96109b46109be9261076c565b6101c1565b61099f565b90565b6109ca906109a5565b9052565b9160206109ef9294936109e860408201965f8301906102af565b01906109c1565b565b9091610a32600491610a23610a0963095ea7b361094e565b9186610a13610042565b9586946020860190815201610977565b60208201810382520382610253565b90610a47610a41828490610b35565b1561099a565b610a51575b505050565b610a9e6004610aa394610a998491610a8a610a6f63095ea7b361094e565b915f90610a7a610042565b96879460208601908152016109ce565b60208201810382520383610253565b610d27565b610d27565b5f8080610a4c565b5f90565b90610ac1610abc8361037e565b610358565b918252565b606090565b3d5f14610ae657610adb3d610aaf565b903d5f602084013e5b565b610aee610ac6565b90610ae4565b610afd8161099a565b03610b0457565b5f80fd5b90505190610b1582610af4565b565b90602082820312610b3057610b2d915f01610b08565b90565b61004c565b905f8091610b41610aab565b50610b4b84610204565b9082602082019151925af1610b5e610acb565b81610b89575b509081610b70575b5090565b610b839150610b7e90610204565b610d93565b5f610b6c565b9050610b948161040f565b610ba6610ba05f61076f565b91610157565b14908115610bb6575b505f610b64565b610bd191506020610bc68261040f565b818301019101610b17565b5f610baf565b67ffffffffffffffff8111610bf557610bf160209161021c565b0190565b610226565b90610c0c610c0783610bd7565b610358565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b610c426020610bfa565b90610c4f60208301610c11565b565b610c59610c38565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b610cbf602a604092610c5c565b610cc881610c65565b0190565b610ce19060208101905f818303910152610cb2565b90565b15610ceb57565b610cf3610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610d2360048201610ccc565b0390fd5b610d7091610d37610d4692610204565b90610d40610c51565b91610db3565b610d4f8161040f565b610d61610d5b5f61076f565b91610157565b14908115610d72575b50610ce4565b565b610d8d91506020610d828261040f565b818301019101610b17565b5f610d6a565b610d9b610aab565b503b610daf610da95f61076f565b91610157565b1190565b90610dd29291610dc1610ac6565b5090610dcc5f61076f565b91610ea3565b90565b610dde906101f8565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b610e3b6026604092610c5c565b610e4481610de1565b0190565b610e5d9060208101905f818303910152610e2e565b90565b15610e6757565b610e6f610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610e9f60048201610e48565b0390fd5b915f8091610ef99593610eb4610ac6565b50610edb610ec130610dd5565b31610ed4610ece85610157565b91610157565b1015610e60565b8591602082019151925af191610eef610acb565b9092909192610f98565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b610f30601d602092610c5c565b610f3981610efc565b0190565b610f529060208101905f818303910152610f23565b90565b15610f5c57565b610f64610042565b7f08c379a000000000000000000000000000000000000000000000000000000000815280610f9460048201610f3d565b0390fd5b919290610fa3610ac6565b505f14610fe75750610fb48261040f565b610fc6610fc05f61076f565b91610157565b14610fd0575b5090565b610fdc610fe191610d93565b610f55565b5f610fcc565b8261103a565b5190565b61101061101960209361101e9361100781610fed565b93848093610c5c565b9586910161041c565b61021c565b0190565b6110379160208201915f818403910152610ff1565b90565b906110448261040f565b6110566110505f61076f565b91610157565b115f146110665750805190602001fd5b6110a190611072610042565b9182917f08c379a000000000000000000000000000000000000000000000000000000000835260048301611022565b0390fd"

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
