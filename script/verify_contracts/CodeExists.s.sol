// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CodeJar} from "codejar/src/CodeJar.sol";

contract CodeExists is Script {
    address constant CODEJAR_ADDRESS = address(0x2b68764bCfE9fCD8d5a30a281F141f69b69Ae3C8);

    function run() public view {
        // Read the bytecode address from the environment variable
        bytes memory bytecode = abi.encodePacked(vm.envBytes("BYTECODE"));

        // Call codeExists on the CodeJar contract
        CodeJar codeJar = CodeJar(CODEJAR_ADDRESS);
        bool codeExists = codeJar.codeExists(bytecode);

        // Output the boolean
        console.log("Code Exists:", codeExists);
    }
}
