// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdUtils.sol";
import "forge-std/StdMath.sol";

import "src/TStoracle.sol";

/**
 * Tests for the transient oracle.
 */
contract TStoracleTest is Test {
    TStoracle public tStoracle;

    struct MyValue {
        address a;
        uint128 x;
        uint128 y;
        uint256 z;
    }

    function setUp() public {
        tStoracle = new TStoracle();
    }

    function testTStoracleCannotOverwrite() public {
        tStoracle.put(bytes("x"), abi.encode(uint256(1)));
        assertEq(abi.decode(tStoracle.get(bytes("x")), (uint256)), 1);

        vm.expectRevert(abi.encodeWithSelector(TStoracle.KeyAlreadySet.selector, bytes("x")));
        tStoracle.put(bytes("x"), abi.encode(uint256(2)));
    }

    function testTStoraclePutAndGetStrings() public {
        tStoracle.put(bytes("string0"), bytes("cool"));
        assertEq(tStoracle.get(bytes("string0")), bytes("cool"));

        tStoracle.put(bytes("string1"), bytes("a really long string that just goes on and on and on and on and on and on and on"));
        assertEq(tStoracle.get(bytes("string1")), bytes("a really long string that just goes on and on and on and on and on and on and on"));

        tStoracle.put(bytes("a really long string that just goes on and on and on and on and on and on and on"), bytes("a"));
        assertEq(tStoracle.get(bytes("a really long string that just goes on and on and on and on and on and on and on")), bytes("a"));
    }

    function testTStoraclePutAndGetHex() public {
        tStoracle.put(bytes("hex0"), hex"0011223344556677889900112233445566778899001122334455667788990011");
        assertEq(tStoracle.get(bytes("hex0")), hex"0011223344556677889900112233445566778899001122334455667788990011");

        tStoracle.put(bytes("hex1"), hex"001122334455667788990011223344556677889900112233445566778899001122");
        assertEq(tStoracle.get(bytes("hex1")), hex"001122334455667788990011223344556677889900112233445566778899001122");
    }

    function testTStoraclePutAndGetUint256() public {
        tStoracle.put(bytes("x"), abi.encode(uint256(55)));
        assertEq(abi.decode(tStoracle.get(bytes("x")), (uint256)), 55);
    }

    function testTStoraclePutAndGetAStruct() public {
        MyValue memory v = MyValue({
            a: address(0x1234567890123456789012345678901234567890),
            x: type(uint128).max,
            y: 0xee0000000000000000000000000000ee,
            z: 0xff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00
        });
        tStoracle.put(bytes("structvalue"), abi.encode(v));
        MyValue memory result = abi.decode(tStoracle.get(bytes("structvalue")), (MyValue));
        assertEq(result.a, v.a);
        assertEq(result.x, v.x);
        assertEq(result.y, v.y);
        assertEq(result.z, v.z);
    }

    function testTStoraclePutAndGetBool() public {
        tStoracle.put(bytes("bool0"), abi.encode(false));
        assertEq(abi.decode(tStoracle.get(bytes("bool0")), (bool)), false);

        tStoracle.put(bytes("bool1"), abi.encode(true));
        assertEq(abi.decode(tStoracle.get(bytes("bool1")), (bool)), true);
    }
}
