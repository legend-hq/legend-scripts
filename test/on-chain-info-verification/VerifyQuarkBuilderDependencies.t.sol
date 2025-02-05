// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

import {CodeJarHelper} from "src/builder/CodeJarHelper.sol";

import {AcrossActions} from "src/AcrossScripts.sol";
import {CCTPBridgeActions} from "src/BridgeScripts.sol";
import {Cancel} from "src/Cancel.sol";
import {ConditionalMulticall} from "src/ConditionalMulticall.sol";
import {
    ApproveAndSwap,
    CometRepayAndWithdrawMultipleAssets,
    CometSupplyActions,
    CometSupplyMultipleAssetsAndBorrow,
    CometWithdrawActions,
    TransferActions
} from "src/DeFiScripts.sol";
import {Ethcall} from "src/Ethcall.sol";
import {MorphoActions, MorphoRewardsActions, MorphoVaultActions} from "src/MorphoScripts.sol";
import {Multicall} from "src/Multicall.sol";
import {Paycall} from "src/Paycall.sol";
import {QuotePay} from "src/QuotePay.sol";
import {RecurringSwap} from "src/RecurringSwap.sol";
import {UniswapFlashLoan} from "src/UniswapFlashLoan.sol";
import {UniswapFlashSwapExactOut} from "src/UniswapFlashSwapExactOut.sol";
import {WrapperActions} from "src/WrapperScripts.sol";

contract VerifyQuarkBuilderDependencies is Test {
    function codeJarAddress(bytes memory creationCode) internal pure returns (address) {
        return CodeJarHelper.getCodeAddress(abi.encodePacked(creationCode));
    }

    struct Dependency {
        string name;
        address contractAddress;
    }

    function verifyQuarkBuilderDependencies() public {
        Dependency[] memory dependencies = new Dependency[](22);

        dependencies[0] = Dependency({name: "CodeJar", contractAddress: CodeJarHelper.CODE_JAR_ADDRESS});

        dependencies[1] = Dependency({name: "AcrossActions", contractAddress: codeJarAddress(type(AcrossActions).creationCode)});
        dependencies[2] = Dependency({name: "CCTPBridgeActions", contractAddress: codeJarAddress(type(CCTPBridgeActions).creationCode)});
        dependencies[3] = Dependency({name: "Cancel", contractAddress: codeJarAddress(type(Cancel).creationCode)});
        dependencies[4] = Dependency({name: "ConditionalMulticall", contractAddress: codeJarAddress(type(ConditionalMulticall).creationCode)});
        // <DeFiScripts>
        dependencies[5] = Dependency({name: "ApproveAndSwap", contractAddress: codeJarAddress(type(ApproveAndSwap).creationCode)});
        dependencies[6] = Dependency({name: "CometRepayAndWithdrawMultipleAssets", contractAddress: codeJarAddress(type(CometRepayAndWithdrawMultipleAssets).creationCode)});
        dependencies[7] = Dependency({name: "CometSupplyActions", contractAddress: codeJarAddress(type(CometSupplyActions).creationCode)});
        dependencies[8] = Dependency({name: "CometSupplyMultipleAssetsAndBorrow", contractAddress: codeJarAddress(type(CometSupplyMultipleAssetsAndBorrow).creationCode)});
        dependencies[9] = Dependency({name: "CometWithdrawActions", contractAddress: codeJarAddress(type(CometWithdrawActions).creationCode)});
        dependencies[10] = Dependency({name: "TransferActions", contractAddress: codeJarAddress(type(TransferActions).creationCode)});
        // </DeFiScripts>
        dependencies[11] = Dependency({name: "Ethcall", contractAddress: codeJarAddress(type(Ethcall).creationCode)});
        // <MorphoScripts>
        dependencies[12] = Dependency({name: "MorphoActions", contractAddress: codeJarAddress(type(MorphoActions).creationCode)});
        dependencies[13] = Dependency({name: "MorphoRewardsActions", contractAddress: codeJarAddress(type(MorphoRewardsActions).creationCode)});
        dependencies[14] = Dependency({name: "MorphoVaultActions", contractAddress: codeJarAddress(type(MorphoVaultActions).creationCode)});
        // </MorphoScripts>
        dependencies[15] = Dependency({name: "Multicall", contractAddress: codeJarAddress(type(Multicall).creationCode)});
        dependencies[16] = Dependency({name: "Paycall", contractAddress: codeJarAddress(type(Paycall).creationCode)});
        dependencies[17] = Dependency({name: "QuotePay", contractAddress: codeJarAddress(type(QuotePay).creationCode)});
        dependencies[18] = Dependency({name: "RecurringSwap", contractAddress: codeJarAddress(type(RecurringSwap).creationCode)});
        dependencies[19] = Dependency({name: "UniswapFlashLoan", contractAddress: codeJarAddress(type(UniswapFlashLoan).creationCode)});
        dependencies[20] = Dependency({name: "UniswapFlashSwapExactOut", contractAddress: codeJarAddress(type(UniswapFlashSwapExactOut).creationCode)});
        dependencies[21] = Dependency({name: "WrapperActions", contractAddress: codeJarAddress(type(WrapperActions).creationCode)});

        for (uint256 i = 0; i < dependencies.length; i++) {
            console.log(dependencies[i].name, dependencies[i].contractAddress);
        }

        console.log("\n");

        for (uint256 i = 0; i < dependencies.length; i++) {
            assertGt(
                address(dependencies[i].contractAddress).code.length,
                0,
                string(abi.encodePacked(dependencies[i].name, " is deployed"))
            );
        }
    }

    function testVerifyQuarkBuilderDependenciesMainnet() public {
        vm.createSelectFork(
            vm.envString("MAINNET_RPC_URL"),
            21776559 // 2025-02-04
        );
        verifyQuarkBuilderDependencies();
    }

    function testVerifyQuarkBuilderDependenciesBase() public {
        vm.createSelectFork(
            vm.envString("BASE_MAINNET_RPC_URL"),
            25962072 // 2025-02-04
        );
        verifyQuarkBuilderDependencies();
    }

    function testVerifyQuarkBuilderDependenciesArbitrum() public {
        vm.createSelectFork(
            vm.envString("ARBITRUM_MAINNET_RPC_URL"),
            302724182 // 2025-02-04
        );
        verifyQuarkBuilderDependencies();
    }

    function testVerifyQuarkBuilderDependenciesOptimism() public {
        vm.createSelectFork(
            vm.envString("OPTIMISM_MAINNET_RPC_URL"),
            131559036 // 2025-02-04
        );
        verifyQuarkBuilderDependencies();
    }
}
