// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.23;

library Arrays {
    /* addressArray */
    function addressArray(address address0) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](1);
        addresses[0] = address0;
        return addresses;
    }

    function addressArray(address address0, address address1) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](2);
        addresses[0] = address0;
        addresses[1] = address1;
        return addresses;
    }

    /* bytesArray */
    function bytesArray(bytes memory bytes0) internal pure returns (bytes[] memory) {
        bytes[] memory arr = new bytes[](1);
        arr[0] = bytes0;
        return arr;
    }

    function bytesArray(bytes memory bytes0, bytes memory bytes01) internal pure returns (bytes[] memory) {
        bytes[] memory arr = new bytes[](2);
        arr[0] = bytes0;
        arr[1] = bytes01;
        return arr;
    }

    function bytesArray(bytes memory bytes0, bytes memory bytes01, bytes memory bytes02)
        internal
        pure
        returns (bytes[] memory)
    {
        bytes[] memory arr = new bytes[](3);
        arr[0] = bytes0;
        arr[1] = bytes01;
        arr[2] = bytes02;
        return arr;
    }

    /* stringArray */
    function stringArray(string memory string0) internal pure returns (string[] memory) {
        string[] memory strings = new string[](1);
        strings[0] = string0;
        return strings;
    }

    function stringArray(string memory string0, string memory string1) internal pure returns (string[] memory) {
        string[] memory strings = new string[](2);
        strings[0] = string0;
        strings[1] = string1;
        return strings;
    }

    function stringArray(string memory string0, string memory string1, string memory string2)
        internal
        pure
        returns (string[] memory)
    {
        string[] memory strings = new string[](3);
        strings[0] = string0;
        strings[1] = string1;
        strings[2] = string2;
        return strings;
    }

    function stringArray(string memory string0, string memory string1, string memory string2, string memory string3)
        internal
        pure
        returns (string[] memory)
    {
        string[] memory strings = new string[](4);
        strings[0] = string0;
        strings[1] = string1;
        strings[2] = string2;
        strings[3] = string3;
        return strings;
    }

    /* uintArray */
    function uintArray(uint256 uint0) internal pure returns (uint256[] memory) {
        uint256[] memory uints = new uint256[](1);
        uints[0] = uint0;
        return uints;
    }

    function uintArray(uint256 uint0, uint256 uint1) internal pure returns (uint256[] memory) {
        uint256[] memory uints = new uint256[](2);
        uints[0] = uint0;
        uints[1] = uint1;
        return uints;
    }

    function uintArray(uint256 uint0, uint256 uint1, uint256 uint2) internal pure returns (uint256[] memory) {
        uint256[] memory uints = new uint256[](3);
        uints[0] = uint0;
        uints[1] = uint1;
        uints[2] = uint2;
        return uints;
    }

    function uintArray(uint256 uint0, uint256 uint1, uint256 uint2, uint256 uint3)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256[] memory uints = new uint256[](4);
        uints[0] = uint0;
        uints[1] = uint1;
        uints[2] = uint2;
        uints[3] = uint3;
        return uints;
    }
}
