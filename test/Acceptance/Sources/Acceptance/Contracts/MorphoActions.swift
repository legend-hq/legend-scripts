@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum MorphoActions {
    public struct MarketParams: Equatable {
        public static let schema: ABI.Schema = .tuple([.address, .address, .address, .address, .uint256])

        public let loanToken: EthAddress
        public let collateralToken: EthAddress
        public let oracle: EthAddress
        public let irm: EthAddress
        public let lltv: BigUInt

        public init(loanToken: EthAddress, collateralToken: EthAddress, oracle: EthAddress, irm: EthAddress, lltv: BigUInt) {
            self.loanToken = loanToken
            self.collateralToken = collateralToken
            self.oracle = oracle
            self.irm = irm
            self.lltv = lltv
        }

        public var encoded: Hex {
            asValue.encoded
        }

        public var asValue: ABI.Value {
            .tuple5(.address(loanToken),
                    .address(collateralToken),
                    .address(oracle),
                    .address(irm),
                    .uint256(lltv))
        }

        public static func decode(hex: Hex) throws -> MarketParams {
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

        public static func decodeValue(_ value: ABI.Value) throws -> MarketParams {
            switch value {
            case let .tuple5(.address(loanToken),
                             .address(collateralToken),
                             .address(oracle),
                             .address(irm),
                             .uint256(lltv)):
                return MarketParams(loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv)
            default:
                throw ABI.DecodeError.mismatchedType(value.schema, schema)
            }
        }
    }

    public static let creationCode: Hex = "0x608060405234601c57600e6020565b61147161002b823961147190f35b6026565b60405190565b5f80fdfe60806040526004361015610013575b6102ee565b61001d5f3561004c565b8063a927d43314610047578063ae8adba7146100425763df3fb6570361000e576102b9565b61023f565b610208565b60e01c90565b60405190565b5f80fd5b5f80fd5b73ffffffffffffffffffffffffffffffffffffffff1690565b61008290610060565b90565b61008e81610079565b0361009557565b5f80fd5b905035906100a682610085565b565b5f80fd5b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b906100ed906100ac565b810190811067ffffffffffffffff82111761010757604052565b6100b6565b9061011f610118610052565b92836100e3565b565b90565b61012d81610121565b0361013457565b5f80fd5b9050359061014582610124565b565b919060a0838203126101b7576101b09061016160a061010c565b9361016e825f8301610099565b5f86015261017f8260208301610099565b60208601526101918260408301610099565b60408601526101a38260608301610099565b6060860152608001610138565b6080830152565b6100a8565b610100818303126101fe576101d3825f8301610099565b926101fb6101e48460208501610147565b936101f28160c08601610138565b9360e001610138565b90565b61005c565b5f0190565b3461023a5761022461021b3660046101bc565b929190916105d3565b61022c610052565b8061023681610203565b0390f35b610058565b346102715761025b6102523660046101bc565b92919091610960565b610263610052565b8061026d81610203565b0390f35b610058565b9060a08282031261028f5761028c915f01610147565b90565b61005c565b90565b6102a090610294565b9052565b91906102b7905f60208501940190610297565b565b346102e9576102e56102d46102cf366004610276565b610cf4565b6102dc610052565b918291826102a4565b0390f35b610058565b5f80fd5b90565b90565b61030c610307610311926102f2565b6102f5565b610121565b90565b61031e9051610079565b90565b61033561033061033a92610060565b6102f5565b610060565b90565b61034690610321565b90565b6103529061033d565b90565b61035e90610321565b90565b61036a90610355565b90565b61037690610321565b90565b6103829061036d565b90565b61038e9061036d565b90565b67ffffffffffffffff81116103af576103ab6020916100ac565b0190565b6100b6565b906103c66103c183610391565b61010c565b918252565b369037565b906103f56103dd836103b4565b926020806103eb8693610391565b92019103906103cb565b565b5f80fd5b60e01b90565b5f91031261040b57565b61005c565b61041990610079565b9052565b61042690610121565b9052565b90608080610482936104425f8201515f860190610410565b61045460208201516020860190610410565b61046660408201516040860190610410565b61047860608201516060860190610410565b015191019061041d565b565b61048d90610121565b9052565b61049a90610079565b9052565b5190565b60209181520190565b90825f9392825e0152565b6104d56104de6020936104e3936104cc8161049e565b938480936104a2565b958691016104ab565b6100ac565b0190565b909261051b9061051161052896946105076101008601975f87019061042a565b60a0850190610484565b60c0830190610491565b60e08184039101526104b6565b90565b610533610052565b3d5f823e3d90fd5b9050519061054882610124565b565b9190604083820312610572578061056661056f925f860161053b565b9360200161053b565b90565b61005c565b610580906102f8565b9052565b909594926105d1946105c06105ca926105b6610100966105ac61012088019c5f89019061042a565b60a0870190610484565b60c0850190610577565b60e0830190610491565b0190610491565b565b91929092806105ea6105e45f6102f8565b91610121565b116106ac575b50806106046105fe5f6102f8565b91610121565b1161060f575b505050565b61062261061d604093610361565b610379565b6106595f6350d8cd4b9593956106648261063b30610385565b61064430610385565b9161064d610052565b9a8b998a9889976103fb565b875260048701610584565b03925af180156106a75761067a575b808061060a565b61069a9060403d81116106a0575b61069281836100e3565b81019061054a565b50610673565b503d610688565b61052b565b6106cb6106c36106be60208701610314565b610349565b848391610dd4565b6106dc6106d784610361565b610379565b9063238d6579908590926106ef30610385565b6107006106fb5f6102f8565b6103d0565b823b15610776575f9461073186926107269461071a610052565b998a98899788966103fb565b8652600486016104e7565b03925af1801561077157610745575b6105f0565b610764905f3d811161076a575b61075c81836100e3565b810190610401565b5f610740565b503d610752565b61052b565b6103f7565b91936107b36107cb96946107a96107bd949761079f6101208801995f89019061042a565b60a0870190610484565b60c0850190610577565b60e0830190610491565b6101008184039101526104b6565b90565b6fffffffffffffffffffffffffffffffff1690565b6107ec816107ce565b036107f357565b5f80fd5b90505190610804826107e3565b565b91906060838203126108525761084b90610820606061010c565b9361082d825f830161053b565b5f86015261083e82602083016107f7565b60208601526040016107f7565b6040830152565b6100a8565b906060828203126108705761086d915f01610806565b90565b61005c565b91602061089692949361088f60408201965f830190610297565b0190610491565b565b6108a290516107ce565b90565b6108b96108b46108be926107ce565b6102f5565b610121565b90565b6108ca906108a5565b9052565b919361090661091e96946108fc61091094976108f26101208801995f89019061042a565b60a0870190610577565b60c08501906108c1565b60e0830190610491565b6101008184039101526104b6565b90565b61095761095e9461094d60e09498979561094361010086019a5f87019061042a565b60a0850190610484565b60c0830190610491565b0190610491565b565b90918061097561096f5f6102f8565b91610121565b11610a43575b508261098f6109895f6102f8565b91610121565b1161099a575b505050565b6109a66109ab91610361565b610379565b91638720316d9190926109bd30610385565b6109c630610385565b823b15610a3e575f946109f786926109ec946109e0610052565b998a98899788966103fb565b865260048601610921565b03925af18015610a3957610a0d575b8080610995565b610a2c905f3d8111610a32575b610a2481836100e3565b810190610401565b5f610a06565b503d610a1a565b61052b565b6103f7565b80610a76610a707fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff610121565b91610121565b145f14610c2c5750610abc610a94610a8f5f8501610314565b610349565b827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff91610dd4565b610acd610ac882610361565b610379565b6320b76e81835f92610ae6610ae186610361565b610379565b60606393c5206291610af789610cf4565b90610b1c610b0430610385565b94610b27610b10610052565b968795869485946103fb565b845260048401610875565b03915afa8015610c2757604094610b8a610b5060205f94610b7f968691610bf9575b5001610898565b610b5930610385565b610b6a610b65866102f8565b6103d0565b91610b73610052565b9a8b998a9889976103fb565b8752600487016108ce565b03925af18015610bf457610bc7575b50610bc0610bb0610bab5f8501610314565b610349565b82610bba5f6102f8565b91610dd4565b5b5f61097b565b610be79060403d8111610bed575b610bdf81836100e3565b81019061054a565b50610b99565b503d610bd5565b61052b565b610c1a915060603d8111610c20575b610c1281836100e3565b810190610857565b5f610b49565b503d610c08565b61052b565b610c4a610c42610c3d5f8601610314565b610349565b838391610dd4565b6040610c5d610c5884610361565b610379565b916320b76e8192610c9e5f879395610ca982610c7830610385565b610c89610c84866102f8565b6103d0565b91610c92610052565b9a8b998a9889976103fb565b87526004870161077b565b03925af18015610ceb57610cbe575b50610bc1565b610cde9060403d8111610ce4575b610cd681836100e3565b81019061054a565b50610cb8565b503d610ccc565b61052b565b5f90565b60a090610cff610cf0565b502090565b610d0d9061036d565b90565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b610d52610d4d610d5792610d10565b6103fb565b610d19565b90565b916020610d7b929493610d7460408201965f830190610491565b0190610484565b565b151590565b60ff1690565b610d9c610d97610da1926102f2565b6102f5565b610d82565b90565b610dad90610d88565b9052565b916020610dd2929493610dcb60408201965f830190610491565b0190610da4565b565b9091610e15600491610e06610dec63095ea7b3610d3e565b9186610df6610052565b9586946020860190815201610d5a565b602082018103825203826100e3565b90610e2a610e24828490610f01565b15610d7d565b610e34575b505050565b610e816004610e8694610e7c8491610e6d610e5263095ea7b3610d3e565b915f90610e5d610052565b9687946020860190815201610db1565b602082018103825203836100e3565b6110f3565b6110f3565b5f8080610e2f565b5f90565b606090565b3d5f14610eb257610ea73d6103b4565b903d5f602084013e5b565b610eba610e92565b90610eb0565b610ec981610d7d565b03610ed057565b5f80fd5b90505190610ee182610ec0565b565b90602082820312610efc57610ef9915f01610ed4565b90565b61005c565b905f8091610f0d610e8e565b50610f1784610d04565b9082602082019151925af1610f2a610e97565b81610f55575b509081610f3c575b5090565b610f4f9150610f4a90610d04565b61115f565b5f610f38565b9050610f608161049e565b610f72610f6c5f6102f8565b91610121565b14908115610f82575b505f610f30565b610f9d91506020610f928261049e565b818301019101610ee3565b5f610f7b565b67ffffffffffffffff8111610fc157610fbd6020916100ac565b0190565b6100b6565b90610fd8610fd383610fa3565b61010c565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b61100e6020610fc6565b9061101b60208301610fdd565b565b611025611004565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b61108b602a604092611028565b61109481611031565b0190565b6110ad9060208101905f81830391015261107e565b90565b156110b757565b6110bf610052565b7f08c379a0000000000000000000000000000000000000000000000000000000008152806110ef60048201611098565b0390fd5b61113c9161110361111292610d04565b9061110c61101d565b9161117f565b61111b8161049e565b61112d6111275f6102f8565b91610121565b1490811561113e575b506110b0565b565b6111599150602061114e8261049e565b818301019101610ee3565b5f611136565b611167610e8e565b503b61117b6111755f6102f8565b91610121565b1190565b9061119e929161118d610e92565b50906111985f6102f8565b9161126f565b90565b6111aa9061036d565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b6112076026604092611028565b611210816111ad565b0190565b6112299060208101905f8183039101526111fa565b90565b1561123357565b61123b610052565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061126b60048201611214565b0390fd5b915f80916112c59593611280610e92565b506112a761128d306111a1565b316112a061129a85610121565b91610121565b101561122c565b8591602082019151925af1916112bb610e97565b9092909192611364565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b6112fc601d602092611028565b611305816112c8565b0190565b61131e9060208101905f8183039101526112ef565b90565b1561132857565b611330610052565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061136060048201611309565b0390fd5b91929061136f610e92565b505f146113b357506113808261049e565b61139261138c5f6102f8565b91610121565b1461139c575b5090565b6113a86113ad9161115f565b611321565b5f611398565b82611406565b5190565b6113dc6113e56020936113ea936113d3816113b9565b93848093611028565b958691016104ab565b6100ac565b0190565b6114039160208201915f8184039101526113bd565b90565b906114108261049e565b61142261141c5f6102f8565b91610121565b115f146114325750805190602001fd5b61146d9061143e610052565b9182917f08c379a0000000000000000000000000000000000000000000000000000000008352600483016113ee565b0390fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610013575b6102ee565b61001d5f3561004c565b8063a927d43314610047578063ae8adba7146100425763df3fb6570361000e576102b9565b61023f565b610208565b60e01c90565b60405190565b5f80fd5b5f80fd5b73ffffffffffffffffffffffffffffffffffffffff1690565b61008290610060565b90565b61008e81610079565b0361009557565b5f80fd5b905035906100a682610085565b565b5f80fd5b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b906100ed906100ac565b810190811067ffffffffffffffff82111761010757604052565b6100b6565b9061011f610118610052565b92836100e3565b565b90565b61012d81610121565b0361013457565b5f80fd5b9050359061014582610124565b565b919060a0838203126101b7576101b09061016160a061010c565b9361016e825f8301610099565b5f86015261017f8260208301610099565b60208601526101918260408301610099565b60408601526101a38260608301610099565b6060860152608001610138565b6080830152565b6100a8565b610100818303126101fe576101d3825f8301610099565b926101fb6101e48460208501610147565b936101f28160c08601610138565b9360e001610138565b90565b61005c565b5f0190565b3461023a5761022461021b3660046101bc565b929190916105d3565b61022c610052565b8061023681610203565b0390f35b610058565b346102715761025b6102523660046101bc565b92919091610960565b610263610052565b8061026d81610203565b0390f35b610058565b9060a08282031261028f5761028c915f01610147565b90565b61005c565b90565b6102a090610294565b9052565b91906102b7905f60208501940190610297565b565b346102e9576102e56102d46102cf366004610276565b610cf4565b6102dc610052565b918291826102a4565b0390f35b610058565b5f80fd5b90565b90565b61030c610307610311926102f2565b6102f5565b610121565b90565b61031e9051610079565b90565b61033561033061033a92610060565b6102f5565b610060565b90565b61034690610321565b90565b6103529061033d565b90565b61035e90610321565b90565b61036a90610355565b90565b61037690610321565b90565b6103829061036d565b90565b61038e9061036d565b90565b67ffffffffffffffff81116103af576103ab6020916100ac565b0190565b6100b6565b906103c66103c183610391565b61010c565b918252565b369037565b906103f56103dd836103b4565b926020806103eb8693610391565b92019103906103cb565b565b5f80fd5b60e01b90565b5f91031261040b57565b61005c565b61041990610079565b9052565b61042690610121565b9052565b90608080610482936104425f8201515f860190610410565b61045460208201516020860190610410565b61046660408201516040860190610410565b61047860608201516060860190610410565b015191019061041d565b565b61048d90610121565b9052565b61049a90610079565b9052565b5190565b60209181520190565b90825f9392825e0152565b6104d56104de6020936104e3936104cc8161049e565b938480936104a2565b958691016104ab565b6100ac565b0190565b909261051b9061051161052896946105076101008601975f87019061042a565b60a0850190610484565b60c0830190610491565b60e08184039101526104b6565b90565b610533610052565b3d5f823e3d90fd5b9050519061054882610124565b565b9190604083820312610572578061056661056f925f860161053b565b9360200161053b565b90565b61005c565b610580906102f8565b9052565b909594926105d1946105c06105ca926105b6610100966105ac61012088019c5f89019061042a565b60a0870190610484565b60c0850190610577565b60e0830190610491565b0190610491565b565b91929092806105ea6105e45f6102f8565b91610121565b116106ac575b50806106046105fe5f6102f8565b91610121565b1161060f575b505050565b61062261061d604093610361565b610379565b6106595f6350d8cd4b9593956106648261063b30610385565b61064430610385565b9161064d610052565b9a8b998a9889976103fb565b875260048701610584565b03925af180156106a75761067a575b808061060a565b61069a9060403d81116106a0575b61069281836100e3565b81019061054a565b50610673565b503d610688565b61052b565b6106cb6106c36106be60208701610314565b610349565b848391610dd4565b6106dc6106d784610361565b610379565b9063238d6579908590926106ef30610385565b6107006106fb5f6102f8565b6103d0565b823b15610776575f9461073186926107269461071a610052565b998a98899788966103fb565b8652600486016104e7565b03925af1801561077157610745575b6105f0565b610764905f3d811161076a575b61075c81836100e3565b810190610401565b5f610740565b503d610752565b61052b565b6103f7565b91936107b36107cb96946107a96107bd949761079f6101208801995f89019061042a565b60a0870190610484565b60c0850190610577565b60e0830190610491565b6101008184039101526104b6565b90565b6fffffffffffffffffffffffffffffffff1690565b6107ec816107ce565b036107f357565b5f80fd5b90505190610804826107e3565b565b91906060838203126108525761084b90610820606061010c565b9361082d825f830161053b565b5f86015261083e82602083016107f7565b60208601526040016107f7565b6040830152565b6100a8565b906060828203126108705761086d915f01610806565b90565b61005c565b91602061089692949361088f60408201965f830190610297565b0190610491565b565b6108a290516107ce565b90565b6108b96108b46108be926107ce565b6102f5565b610121565b90565b6108ca906108a5565b9052565b919361090661091e96946108fc61091094976108f26101208801995f89019061042a565b60a0870190610577565b60c08501906108c1565b60e0830190610491565b6101008184039101526104b6565b90565b61095761095e9461094d60e09498979561094361010086019a5f87019061042a565b60a0850190610484565b60c0830190610491565b0190610491565b565b90918061097561096f5f6102f8565b91610121565b11610a43575b508261098f6109895f6102f8565b91610121565b1161099a575b505050565b6109a66109ab91610361565b610379565b91638720316d9190926109bd30610385565b6109c630610385565b823b15610a3e575f946109f786926109ec946109e0610052565b998a98899788966103fb565b865260048601610921565b03925af18015610a3957610a0d575b8080610995565b610a2c905f3d8111610a32575b610a2481836100e3565b810190610401565b5f610a06565b503d610a1a565b61052b565b6103f7565b80610a76610a707fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff610121565b91610121565b145f14610c2c5750610abc610a94610a8f5f8501610314565b610349565b827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff91610dd4565b610acd610ac882610361565b610379565b6320b76e81835f92610ae6610ae186610361565b610379565b60606393c5206291610af789610cf4565b90610b1c610b0430610385565b94610b27610b10610052565b968795869485946103fb565b845260048401610875565b03915afa8015610c2757604094610b8a610b5060205f94610b7f968691610bf9575b5001610898565b610b5930610385565b610b6a610b65866102f8565b6103d0565b91610b73610052565b9a8b998a9889976103fb565b8752600487016108ce565b03925af18015610bf457610bc7575b50610bc0610bb0610bab5f8501610314565b610349565b82610bba5f6102f8565b91610dd4565b5b5f61097b565b610be79060403d8111610bed575b610bdf81836100e3565b81019061054a565b50610b99565b503d610bd5565b61052b565b610c1a915060603d8111610c20575b610c1281836100e3565b810190610857565b5f610b49565b503d610c08565b61052b565b610c4a610c42610c3d5f8601610314565b610349565b838391610dd4565b6040610c5d610c5884610361565b610379565b916320b76e8192610c9e5f879395610ca982610c7830610385565b610c89610c84866102f8565b6103d0565b91610c92610052565b9a8b998a9889976103fb565b87526004870161077b565b03925af18015610ceb57610cbe575b50610bc1565b610cde9060403d8111610ce4575b610cd681836100e3565b81019061054a565b50610cb8565b503d610ccc565b61052b565b5f90565b60a090610cff610cf0565b502090565b610d0d9061036d565b90565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b610d52610d4d610d5792610d10565b6103fb565b610d19565b90565b916020610d7b929493610d7460408201965f830190610491565b0190610484565b565b151590565b60ff1690565b610d9c610d97610da1926102f2565b6102f5565b610d82565b90565b610dad90610d88565b9052565b916020610dd2929493610dcb60408201965f830190610491565b0190610da4565b565b9091610e15600491610e06610dec63095ea7b3610d3e565b9186610df6610052565b9586946020860190815201610d5a565b602082018103825203826100e3565b90610e2a610e24828490610f01565b15610d7d565b610e34575b505050565b610e816004610e8694610e7c8491610e6d610e5263095ea7b3610d3e565b915f90610e5d610052565b9687946020860190815201610db1565b602082018103825203836100e3565b6110f3565b6110f3565b5f8080610e2f565b5f90565b606090565b3d5f14610eb257610ea73d6103b4565b903d5f602084013e5b565b610eba610e92565b90610eb0565b610ec981610d7d565b03610ed057565b5f80fd5b90505190610ee182610ec0565b565b90602082820312610efc57610ef9915f01610ed4565b90565b61005c565b905f8091610f0d610e8e565b50610f1784610d04565b9082602082019151925af1610f2a610e97565b81610f55575b509081610f3c575b5090565b610f4f9150610f4a90610d04565b61115f565b5f610f38565b9050610f608161049e565b610f72610f6c5f6102f8565b91610121565b14908115610f82575b505f610f30565b610f9d91506020610f928261049e565b818301019101610ee3565b5f610f7b565b67ffffffffffffffff8111610fc157610fbd6020916100ac565b0190565b6100b6565b90610fd8610fd383610fa3565b61010c565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b61100e6020610fc6565b9061101b60208301610fdd565b565b611025611004565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b61108b602a604092611028565b61109481611031565b0190565b6110ad9060208101905f81830391015261107e565b90565b156110b757565b6110bf610052565b7f08c379a0000000000000000000000000000000000000000000000000000000008152806110ef60048201611098565b0390fd5b61113c9161110361111292610d04565b9061110c61101d565b9161117f565b61111b8161049e565b61112d6111275f6102f8565b91610121565b1490811561113e575b506110b0565b565b6111599150602061114e8261049e565b818301019101610ee3565b5f611136565b611167610e8e565b503b61117b6111755f6102f8565b91610121565b1190565b9061119e929161118d610e92565b50906111985f6102f8565b9161126f565b90565b6111aa9061036d565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b6112076026604092611028565b611210816111ad565b0190565b6112299060208101905f8183039101526111fa565b90565b1561123357565b61123b610052565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061126b60048201611214565b0390fd5b915f80916112c59593611280610e92565b506112a761128d306111a1565b316112a061129a85610121565b91610121565b101561122c565b8591602082019151925af1916112bb610e97565b9092909192611364565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b6112fc601d602092611028565b611305816112c8565b0190565b61131e9060208101905f8183039101526112ef565b90565b1561132857565b611330610052565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061136060048201611309565b0390fd5b91929061136f610e92565b505f146113b357506113808261049e565b61139261138c5f6102f8565b91610121565b1461139c575b5090565b6113a86113ad9161115f565b611321565b5f611398565b82611406565b5190565b6113dc6113e56020936113ea936113d3816113b9565b93848093611028565b958691016104ab565b6100ac565b0190565b6114039160208201915f8184039101526113bd565b90565b906114108261049e565b61142261141c5f6102f8565b91610121565b115f146114325750805190602001fd5b61146d9061143e610052565b9182917f08c379a0000000000000000000000000000000000000000000000000000000008352600483016113ee565b0390fd"

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
    public static let functions: [ABI.Function] = [marketIdFn, repayAndWithdrawCollateralFn, supplyCollateralAndBorrowFn]
    public static let marketIdFn = ABI.Function(
        name: "marketId",
        inputs: [.tuple([.address, .address, .address, .address, .uint256])],
        outputs: [.bytes32]
    )

    public static func marketId(params: MarketParams, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Hex, RevertReason> {
        do {
            let query = try marketIdFn.encoded(with: [params.asValue])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try marketIdFn.decode(output: result)

            switch decoded {
            case let .tuple1(.bytes32(marketParamsId)):
                return .success(marketParamsId)
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, marketIdFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func marketIdDecode(input: Hex) throws -> (MarketParams) {
        let decodedInput = try marketIdFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple1(.tuple5(.address(loanToken),
                                 .address(collateralToken),
                                 .address(oracle),
                                 .address(irm),
                                 .uint256(lltv))):
            return try (MarketParams(loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv))
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, marketIdFn.inputTuple)
        }
    }

    public static let repayAndWithdrawCollateralFn = ABI.Function(
        name: "repayAndWithdrawCollateral",
        inputs: [.address, .tuple([.address, .address, .address, .address, .uint256]), .uint256, .uint256],
        outputs: []
    )

    public static func repayAndWithdrawCollateral(morpho: EthAddress, marketParams: MarketParams, repayAmount: BigUInt, withdrawAmount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try repayAndWithdrawCollateralFn.encoded(with: [.address(morpho), marketParams.asValue, .uint256(repayAmount), .uint256(withdrawAmount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try repayAndWithdrawCollateralFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, repayAndWithdrawCollateralFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func repayAndWithdrawCollateralDecode(input: Hex) throws -> (EthAddress, MarketParams, BigUInt, BigUInt) {
        let decodedInput = try repayAndWithdrawCollateralFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple4(.address(morpho), .tuple5(.address(loanToken),
                                                   .address(collateralToken),
                                                   .address(oracle),
                                                   .address(irm),
                                                   .uint256(lltv)), .uint256(repayAmount), .uint256(withdrawAmount)):
            return try (morpho, MarketParams(loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv), repayAmount, withdrawAmount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, repayAndWithdrawCollateralFn.inputTuple)
        }
    }

    public static let supplyCollateralAndBorrowFn = ABI.Function(
        name: "supplyCollateralAndBorrow",
        inputs: [.address, .tuple([.address, .address, .address, .address, .uint256]), .uint256, .uint256],
        outputs: []
    )

    public static func supplyCollateralAndBorrow(morpho: EthAddress, marketParams: MarketParams, supplyAssetAmount: BigUInt, borrowAssetAmount: BigUInt, withFunctions ffis: EVM.FFIMap = [:]) async throws -> Result<Void, RevertReason> {
        do {
            let query = try supplyCollateralAndBorrowFn.encoded(with: [.address(morpho), marketParams.asValue, .uint256(supplyAssetAmount), .uint256(borrowAssetAmount)])
            let result = try await EVM.runQuery(bytecode: runtimeCode, query: query, withErrors: errors, withFunctions: ffis)
            let decoded = try supplyCollateralAndBorrowFn.decode(output: result)

            switch decoded {
            case .tuple0:
                return .success(())
            default:
                throw ABI.DecodeError.mismatchedType(decoded.schema, supplyCollateralAndBorrowFn.outputTuple)
            }
        } catch let EVM.QueryError.error(e, v) {
            return .failure(rewrapError(e, value: v))
        }
    }

    public static func supplyCollateralAndBorrowDecode(input: Hex) throws -> (EthAddress, MarketParams, BigUInt, BigUInt) {
        let decodedInput = try supplyCollateralAndBorrowFn.decodeInput(input: input)
        switch decodedInput {
        case let .tuple4(.address(morpho), .tuple5(.address(loanToken),
                                                   .address(collateralToken),
                                                   .address(oracle),
                                                   .address(irm),
                                                   .uint256(lltv)), .uint256(supplyAssetAmount), .uint256(borrowAssetAmount)):
            return try (morpho, MarketParams(loanToken: loanToken, collateralToken: collateralToken, oracle: oracle, irm: irm, lltv: lltv), supplyAssetAmount, borrowAssetAmount)
        default:
            throw ABI.DecodeError.mismatchedType(decodedInput.schema, supplyCollateralAndBorrowFn.inputTuple)
        }
    }
}
