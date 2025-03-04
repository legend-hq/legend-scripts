@preconcurrency import BigInt
@preconcurrency import Eth
import Foundation

public enum CometSupplyActions {
    public static let creationCode: Hex = "0x608060405234601c57600e6020565b6114a161002b82396114a190f35b6026565b60405190565b5f80fdfe60806040526004361015610013575b61038b565b61001d5f3561005c565b80630c0a769b1461005757806350a4548914610052578063c3da35901461004d5763f1afb11f0361000e57610354565b6102d7565b6101ab565b610121565b60e01c90565b60405190565b5f80fd5b5f80fd5b5f80fd5b73ffffffffffffffffffffffffffffffffffffffff1690565b61009690610074565b90565b6100a28161008d565b036100a957565b5f80fd5b905035906100ba82610099565b565b90565b6100c8816100bc565b036100cf57565b5f80fd5b905035906100e0826100bf565b565b9091606082840312610117576101146100fd845f85016100ad565b9361010b81602086016100ad565b936040016100d3565b90565b61006c565b5f0190565b346101505761013a6101343660046100e2565b91610516565b610142610062565b8061014c8161011c565b0390f35b610068565b919060a0838203126101a65761016d815f85016100ad565b9261017b82602083016100ad565b926101a361018c84604085016100ad565b9361019a81606086016100ad565b936080016100d3565b90565b61006c565b346101dd576101c76101be366004610155565b939290926106d3565b6101cf610062565b806101d98161011c565b0390f35b610068565b5f80fd5b5f80fd5b5f80fd5b909182601f830112156102285781359167ffffffffffffffff831161022357602001926020830284011161021e57565b6101ea565b6101e6565b6101e2565b909182601f830112156102675781359167ffffffffffffffff831161026257602001926020830284011161025d57565b6101ea565b6101e6565b6101e2565b6060818303126102d257610282825f83016100ad565b92602082013567ffffffffffffffff81116102cd57836102a39184016101ee565b929093604082013567ffffffffffffffff81116102c8576102c4920161022d565b9091565b610070565b610070565b61006c565b34610309576102f36102ea36600461026c565b939290926108e4565b6102fb610062565b806103058161011c565b0390f35b610068565b60808183031261034f57610324825f83016100ad565b9261034c61033584602085016100ad565b9361034381604086016100ad565b936060016100d3565b90565b61006c565b346103865761037061036736600461030e565b92919091610b82565b610378610062565b806103828161011c565b0390f35b610068565b5f80fd5b90565b6103a66103a16103ab92610074565b61038f565b610074565b90565b6103b790610392565b90565b6103c3906103ae565b90565b6103cf90610392565b90565b6103db906103c6565b90565b6103e7906103c6565b90565b5f80fd5b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b9061042f906103ee565b810190811067ffffffffffffffff82111761044957604052565b6103f8565b60e01b90565b90505190610461826100bf565b565b9060208282031261047c57610479915f01610454565b90565b61006c565b61048a9061008d565b9052565b91906104a1905f60208501940190610481565b565b6104ab610062565b3d5f823e3d90fd5b6104bc90610392565b90565b6104c8906104b3565b90565b6104d4906103c6565b90565b5f9103126104e157565b61006c565b6104ef906100bc565b9052565b91602061051492949361050d60408201965f830190610481565b01906104e6565b565b826105496105437fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b146105f4575b61056f6105749161056a610562856103ba565b828791610da6565b6104bf565b6104cb565b9163f2b9fdb8919092803b156105ef576105a15f80946105ac610595610062565b9788968795869461044e565b8452600484016104f3565b03925af180156105ea576105be575b50565b6105dd905f3d81116105e3575b6105d58183610425565b8101906104d7565b5f6105bb565b503d6105cb565b6104a3565b6103ea565b915061063e602061060c610607846103ba565b6103d2565b6370a082319061063361061e306103de565b92610627610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610690576105749161056f915f91610662575b509391505061054f565b610683915060203d8111610689575b61067b8183610425565b810190610463565b5f610658565b503d610671565b6104a3565b6106ca6106d1946106c06060949897956106b6608086019a5f870190610481565b6020850190610481565b6040830190610481565b01906104e6565b565b939092938161070a6107047fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b146107a4575b61071c610721916104bf565b6104cb565b90639032317793929490823b1561079f575f9461075c869261075194610745610062565b998a988997889661044e565b865260048601610695565b03925af1801561079a5761076e575b50565b61078d905f3d8111610793575b6107858183610425565b8101906104d7565b5f61076b565b503d61077b565b6104a3565b6103ea565b90506107e660206107bc6107b7876103ba565b6103d2565b6370a08231906107db87926107cf610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610838576107219161071c915f9161080a575b5092915050610710565b61082b915060203d8111610831575b6108238183610425565b810190610463565b5f610800565b503d610819565b6104a3565b5090565b5090565b90565b61085c61085761086192610845565b61038f565b6100bc565b90565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b91908110156108a1576020020190565b610864565b356108b0816100bf565b90565b91908110156108c3576020020190565b610864565b356108d281610099565b90565b60016108e191016100bc565b90565b91949390926108f484879061083d565b61091061090a610905848690610841565b6100bc565b916100bc565b03610b1b5761091e5f610848565b5b8061093c610936610931888b9061083d565b6100bc565b916100bc565b1015610b125761095661095183858491610891565b6108a6565b908161098a6109847fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b14610a69575b6109b76109af6109aa6109a5898c86916108b3565b6108c8565b6103ba565b868491610da6565b6109c86109c3866104bf565b6104cb565b9163f2b9fdb8906109e36109de898c86916108b3565b6108c8565b9093803b15610a6457610a095f8094610a146109fd610062565b9889968795869461044e565b8452600484016104f3565b03925af1918215610a5f57610a2e92610a33575b506108d5565b61091f565b610a52905f3d8111610a58575b610a4a8183610425565b8101906104d7565b5f610a28565b503d610a40565b6104a3565b6103ea565b9050610ac66020610a94610a8f610a8a610a858a8d88916108b3565b6108c8565b6103ba565b6103d2565b6370a0823190610abb610aa6306103de565b92610aaf610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610b0d575f91610adf575b5090610990565b610b00915060203d8111610b06575b610af88183610425565b810190610463565b5f610ad8565b503d610aee565b6104a3565b50505050509050565b5f7fb4fa3fb300000000000000000000000000000000000000000000000000000000815280610b4c6004820161011c565b0390fd5b604090610b79610b809496959396610b6f60608401985f850190610481565b6020830190610481565b01906104e6565b565b91909183610bb8610bb27fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b14610c64575b610bde610be391610bd9610bd1856103ba565b828891610da6565b6104bf565b6104cb565b634232cd6392919392813b15610c5f575f610c1191610c1c8296610c05610062565b9889978896879561044e565b855260048501610b50565b03925af18015610c5a57610c2e575b50565b610c4d905f3d8111610c53575b610c458183610425565b8101906104d7565b5f610c2b565b503d610c3b565b6104a3565b6103ea565b9250610cae6020610c7c610c77846103ba565b6103d2565b6370a0823190610ca3610c8e306103de565b92610c97610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610d0057610be391610bde915f91610cd2575b5094915050610bbe565b610cf3915060203d8111610cf9575b610ceb8183610425565b810190610463565b5f610cc8565b503d610ce1565b6104a3565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b610d47610d42610d4c92610d05565b61044e565b610d0e565b90565b151590565b60ff1690565b610d6e610d69610d7392610845565b61038f565b610d54565b90565b610d7f90610d5a565b9052565b916020610da4929493610d9d60408201965f830190610481565b0190610d76565b565b9091610de7600491610dd8610dbe63095ea7b3610d33565b9186610dc8610062565b95869460208601908152016104f3565b60208201810382520382610425565b90610dfc610df6828490610f26565b15610d4f565b610e06575b505050565b610e536004610e5894610e4e8491610e3f610e2463095ea7b3610d33565b915f90610e2f610062565b9687946020860190815201610d83565b60208201810382520383610425565b611118565b611118565b5f8080610e01565b5f90565b90610e77610e70610062565b9283610425565b565b67ffffffffffffffff8111610e9757610e936020916103ee565b0190565b6103f8565b90610eae610ea983610e79565b610e64565b918252565b606090565b3d5f14610ed357610ec83d610e9c565b903d5f602084013e5b565b610edb610eb3565b90610ed1565b5190565b610eee81610d4f565b03610ef557565b5f80fd5b90505190610f0682610ee5565b565b90602082820312610f2157610f1e915f01610ef9565b90565b61006c565b905f8091610f32610e60565b50610f3c846103d2565b9082602082019151925af1610f4f610eb8565b81610f7a575b509081610f61575b5090565b610f749150610f6f906103d2565b611184565b5f610f5d565b9050610f8581610ee1565b610f97610f915f610848565b916100bc565b14908115610fa7575b505f610f55565b610fc291506020610fb782610ee1565b818301019101610f08565b5f610fa0565b67ffffffffffffffff8111610fe657610fe26020916103ee565b0190565b6103f8565b90610ffd610ff883610fc8565b610e64565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b6110336020610feb565b9061104060208301611002565b565b61104a611029565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b6110b0602a60409261104d565b6110b981611056565b0190565b6110d29060208101905f8183039101526110a3565b90565b156110dc57565b6110e4610062565b7f08c379a000000000000000000000000000000000000000000000000000000000815280611114600482016110bd565b0390fd5b61116191611128611137926103d2565b90611131611042565b916111a4565b61114081610ee1565b61115261114c5f610848565b916100bc565b14908115611163575b506110d5565b565b61117e9150602061117382610ee1565b818301019101610f08565b5f61115b565b61118c610e60565b503b6111a061119a5f610848565b916100bc565b1190565b906111c392916111b2610eb3565b50906111bd5f610848565b91611294565b90565b6111cf906103c6565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b61122c602660409261104d565b611235816111d2565b0190565b61124e9060208101905f81830391015261121f565b90565b1561125857565b611260610062565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061129060048201611239565b0390fd5b915f80916112ea95936112a5610eb3565b506112cc6112b2306111c6565b316112c56112bf856100bc565b916100bc565b1015611251565b8591602082019151925af1916112e0610eb8565b9092909192611389565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b611321601d60209261104d565b61132a816112ed565b0190565b6113439060208101905f818303910152611314565b90565b1561134d57565b611355610062565b7f08c379a0000000000000000000000000000000000000000000000000000000008152806113856004820161132e565b0390fd5b919290611394610eb3565b505f146113d857506113a582610ee1565b6113b76113b15f610848565b916100bc565b146113c1575b5090565b6113cd6113d291611184565b611346565b5f6113bd565b82611436565b5190565b90825f9392825e0152565b61140c61141560209361141a93611403816113de565b9384809361104d565b958691016113e2565b6103ee565b0190565b6114339160208201915f8184039101526113ed565b90565b9061144082610ee1565b61145261144c5f610848565b916100bc565b115f146114625750805190602001fd5b61149d9061146e610062565b9182917f08c379a00000000000000000000000000000000000000000000000000000000083526004830161141e565b0390fd"
    public static let runtimeCode: Hex = "0x60806040526004361015610013575b61038b565b61001d5f3561005c565b80630c0a769b1461005757806350a4548914610052578063c3da35901461004d5763f1afb11f0361000e57610354565b6102d7565b6101ab565b610121565b60e01c90565b60405190565b5f80fd5b5f80fd5b5f80fd5b73ffffffffffffffffffffffffffffffffffffffff1690565b61009690610074565b90565b6100a28161008d565b036100a957565b5f80fd5b905035906100ba82610099565b565b90565b6100c8816100bc565b036100cf57565b5f80fd5b905035906100e0826100bf565b565b9091606082840312610117576101146100fd845f85016100ad565b9361010b81602086016100ad565b936040016100d3565b90565b61006c565b5f0190565b346101505761013a6101343660046100e2565b91610516565b610142610062565b8061014c8161011c565b0390f35b610068565b919060a0838203126101a65761016d815f85016100ad565b9261017b82602083016100ad565b926101a361018c84604085016100ad565b9361019a81606086016100ad565b936080016100d3565b90565b61006c565b346101dd576101c76101be366004610155565b939290926106d3565b6101cf610062565b806101d98161011c565b0390f35b610068565b5f80fd5b5f80fd5b5f80fd5b909182601f830112156102285781359167ffffffffffffffff831161022357602001926020830284011161021e57565b6101ea565b6101e6565b6101e2565b909182601f830112156102675781359167ffffffffffffffff831161026257602001926020830284011161025d57565b6101ea565b6101e6565b6101e2565b6060818303126102d257610282825f83016100ad565b92602082013567ffffffffffffffff81116102cd57836102a39184016101ee565b929093604082013567ffffffffffffffff81116102c8576102c4920161022d565b9091565b610070565b610070565b61006c565b34610309576102f36102ea36600461026c565b939290926108e4565b6102fb610062565b806103058161011c565b0390f35b610068565b60808183031261034f57610324825f83016100ad565b9261034c61033584602085016100ad565b9361034381604086016100ad565b936060016100d3565b90565b61006c565b346103865761037061036736600461030e565b92919091610b82565b610378610062565b806103828161011c565b0390f35b610068565b5f80fd5b90565b6103a66103a16103ab92610074565b61038f565b610074565b90565b6103b790610392565b90565b6103c3906103ae565b90565b6103cf90610392565b90565b6103db906103c6565b90565b6103e7906103c6565b90565b5f80fd5b601f801991011690565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52604160045260245ffd5b9061042f906103ee565b810190811067ffffffffffffffff82111761044957604052565b6103f8565b60e01b90565b90505190610461826100bf565b565b9060208282031261047c57610479915f01610454565b90565b61006c565b61048a9061008d565b9052565b91906104a1905f60208501940190610481565b565b6104ab610062565b3d5f823e3d90fd5b6104bc90610392565b90565b6104c8906104b3565b90565b6104d4906103c6565b90565b5f9103126104e157565b61006c565b6104ef906100bc565b9052565b91602061051492949361050d60408201965f830190610481565b01906104e6565b565b826105496105437fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b146105f4575b61056f6105749161056a610562856103ba565b828791610da6565b6104bf565b6104cb565b9163f2b9fdb8919092803b156105ef576105a15f80946105ac610595610062565b9788968795869461044e565b8452600484016104f3565b03925af180156105ea576105be575b50565b6105dd905f3d81116105e3575b6105d58183610425565b8101906104d7565b5f6105bb565b503d6105cb565b6104a3565b6103ea565b915061063e602061060c610607846103ba565b6103d2565b6370a082319061063361061e306103de565b92610627610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610690576105749161056f915f91610662575b509391505061054f565b610683915060203d8111610689575b61067b8183610425565b810190610463565b5f610658565b503d610671565b6104a3565b6106ca6106d1946106c06060949897956106b6608086019a5f870190610481565b6020850190610481565b6040830190610481565b01906104e6565b565b939092938161070a6107047fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b146107a4575b61071c610721916104bf565b6104cb565b90639032317793929490823b1561079f575f9461075c869261075194610745610062565b998a988997889661044e565b865260048601610695565b03925af1801561079a5761076e575b50565b61078d905f3d8111610793575b6107858183610425565b8101906104d7565b5f61076b565b503d61077b565b6104a3565b6103ea565b90506107e660206107bc6107b7876103ba565b6103d2565b6370a08231906107db87926107cf610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610838576107219161071c915f9161080a575b5092915050610710565b61082b915060203d8111610831575b6108238183610425565b810190610463565b5f610800565b503d610819565b6104a3565b5090565b5090565b90565b61085c61085761086192610845565b61038f565b6100bc565b90565b7f4e487b71000000000000000000000000000000000000000000000000000000005f52603260045260245ffd5b91908110156108a1576020020190565b610864565b356108b0816100bf565b90565b91908110156108c3576020020190565b610864565b356108d281610099565b90565b60016108e191016100bc565b90565b91949390926108f484879061083d565b61091061090a610905848690610841565b6100bc565b916100bc565b03610b1b5761091e5f610848565b5b8061093c610936610931888b9061083d565b6100bc565b916100bc565b1015610b125761095661095183858491610891565b6108a6565b908161098a6109847fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b14610a69575b6109b76109af6109aa6109a5898c86916108b3565b6108c8565b6103ba565b868491610da6565b6109c86109c3866104bf565b6104cb565b9163f2b9fdb8906109e36109de898c86916108b3565b6108c8565b9093803b15610a6457610a095f8094610a146109fd610062565b9889968795869461044e565b8452600484016104f3565b03925af1918215610a5f57610a2e92610a33575b506108d5565b61091f565b610a52905f3d8111610a58575b610a4a8183610425565b8101906104d7565b5f610a28565b503d610a40565b6104a3565b6103ea565b9050610ac66020610a94610a8f610a8a610a858a8d88916108b3565b6108c8565b6103ba565b6103d2565b6370a0823190610abb610aa6306103de565b92610aaf610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610b0d575f91610adf575b5090610990565b610b00915060203d8111610b06575b610af88183610425565b810190610463565b5f610ad8565b503d610aee565b6104a3565b50505050509050565b5f7fb4fa3fb300000000000000000000000000000000000000000000000000000000815280610b4c6004820161011c565b0390fd5b604090610b79610b809496959396610b6f60608401985f850190610481565b6020830190610481565b01906104e6565b565b91909183610bb8610bb27fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6100bc565b916100bc565b14610c64575b610bde610be391610bd9610bd1856103ba565b828891610da6565b6104bf565b6104cb565b634232cd6392919392813b15610c5f575f610c1191610c1c8296610c05610062565b9889978896879561044e565b855260048501610b50565b03925af18015610c5a57610c2e575b50565b610c4d905f3d8111610c53575b610c458183610425565b8101906104d7565b5f610c2b565b503d610c3b565b6104a3565b6103ea565b9250610cae6020610c7c610c77846103ba565b6103d2565b6370a0823190610ca3610c8e306103de565b92610c97610062565b9586948593849361044e565b83526004830161048e565b03915afa908115610d0057610be391610bde915f91610cd2575b5094915050610bbe565b610cf3915060203d8111610cf9575b610ceb8183610425565b810190610463565b5f610cc8565b503d610ce1565b6104a3565b63ffffffff1690565b7fffffffff000000000000000000000000000000000000000000000000000000001690565b610d47610d42610d4c92610d05565b61044e565b610d0e565b90565b151590565b60ff1690565b610d6e610d69610d7392610845565b61038f565b610d54565b90565b610d7f90610d5a565b9052565b916020610da4929493610d9d60408201965f830190610481565b0190610d76565b565b9091610de7600491610dd8610dbe63095ea7b3610d33565b9186610dc8610062565b95869460208601908152016104f3565b60208201810382520382610425565b90610dfc610df6828490610f26565b15610d4f565b610e06575b505050565b610e536004610e5894610e4e8491610e3f610e2463095ea7b3610d33565b915f90610e2f610062565b9687946020860190815201610d83565b60208201810382520383610425565b611118565b611118565b5f8080610e01565b5f90565b90610e77610e70610062565b9283610425565b565b67ffffffffffffffff8111610e9757610e936020916103ee565b0190565b6103f8565b90610eae610ea983610e79565b610e64565b918252565b606090565b3d5f14610ed357610ec83d610e9c565b903d5f602084013e5b565b610edb610eb3565b90610ed1565b5190565b610eee81610d4f565b03610ef557565b5f80fd5b90505190610f0682610ee5565b565b90602082820312610f2157610f1e915f01610ef9565b90565b61006c565b905f8091610f32610e60565b50610f3c846103d2565b9082602082019151925af1610f4f610eb8565b81610f7a575b509081610f61575b5090565b610f749150610f6f906103d2565b611184565b5f610f5d565b9050610f8581610ee1565b610f97610f915f610848565b916100bc565b14908115610fa7575b505f610f55565b610fc291506020610fb782610ee1565b818301019101610f08565b5f610fa0565b67ffffffffffffffff8111610fe657610fe26020916103ee565b0190565b6103f8565b90610ffd610ff883610fc8565b610e64565b918252565b5f7f5361666545524332303a206c6f772d6c6576656c2063616c6c206661696c6564910152565b6110336020610feb565b9061104060208301611002565b565b61104a611029565b90565b60209181520190565b60207f6f74207375636365656400000000000000000000000000000000000000000000917f5361666545524332303a204552433230206f7065726174696f6e20646964206e5f8201520152565b6110b0602a60409261104d565b6110b981611056565b0190565b6110d29060208101905f8183039101526110a3565b90565b156110dc57565b6110e4610062565b7f08c379a000000000000000000000000000000000000000000000000000000000815280611114600482016110bd565b0390fd5b61116191611128611137926103d2565b90611131611042565b916111a4565b61114081610ee1565b61115261114c5f610848565b916100bc565b14908115611163575b506110d5565b565b61117e9150602061117382610ee1565b818301019101610f08565b5f61115b565b61118c610e60565b503b6111a061119a5f610848565b916100bc565b1190565b906111c392916111b2610eb3565b50906111bd5f610848565b91611294565b90565b6111cf906103c6565b90565b60207f722063616c6c0000000000000000000000000000000000000000000000000000917f416464726573733a20696e73756666696369656e742062616c616e636520666f5f8201520152565b61122c602660409261104d565b611235816111d2565b0190565b61124e9060208101905f81830391015261121f565b90565b1561125857565b611260610062565b7f08c379a00000000000000000000000000000000000000000000000000000000081528061129060048201611239565b0390fd5b915f80916112ea95936112a5610eb3565b506112cc6112b2306111c6565b316112c56112bf856100bc565b916100bc565b1015611251565b8591602082019151925af1916112e0610eb8565b9092909192611389565b90565b5f7f416464726573733a2063616c6c20746f206e6f6e2d636f6e7472616374000000910152565b611321601d60209261104d565b61132a816112ed565b0190565b6113439060208101905f818303910152611314565b90565b1561134d57565b611355610062565b7f08c379a0000000000000000000000000000000000000000000000000000000008152806113856004820161132e565b0390fd5b919290611394610eb3565b505f146113d857506113a582610ee1565b6113b76113b15f610848565b916100bc565b146113c1575b5090565b6113cd6113d291611184565b611346565b5f6113bd565b82611436565b5190565b90825f9392825e0152565b61140c61141560209361141a93611403816113de565b9384809361104d565b958691016113e2565b6103ee565b0190565b6114339160208201915f8184039101526113ed565b90565b9061144082610ee1565b61145261144c5f610848565b916100bc565b115f146114625750805190602001fd5b61149d9061146e610062565b9182917f08c379a00000000000000000000000000000000000000000000000000000000083526004830161141e565b0390fd"

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
