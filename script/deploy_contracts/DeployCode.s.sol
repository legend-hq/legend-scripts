// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

contract DeployCode is Script {
    address constant CODEJAR_ADDRESS = address(0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8); // Replace with actual CodeJar address

    function run() public {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PK"));
        // Read the bytecode address from the environment variable
        bytes memory bytecode = abi.encodePacked(vm.envBytes("BYTECODE"));

        vm.startBroadcast(deployer);

        // Call saveCode on the CodeJar contract
        CodeJar codeJar = CodeJar(CODEJAR_ADDRESS);
        address codeAddress = codeJar.saveCode(bytecode);

        // Output the address
        console.log("Code Address:", codeAddress);

        vm.stopBroadcast();
    }
}
