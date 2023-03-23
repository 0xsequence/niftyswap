// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {AddressConverter} from "src/contracts/utils/AddressConverter.sol";

import {Test, console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

contract AddressConverterTest is Test {
    AddressConverter private converter;

    function setUp() external {
        converter = new AddressConverter();
    }

    function test_convertParity() external {
        assertEq(address(0), addrUint256Addr(address(0)));
        assertEq(address(1), addrUint256Addr(address(1)));
        assertEq(address(2), addrUint256Addr(address(2)));
    }

    //
    // Helpers
    //
    function addrUint256Addr(address input) public view returns (address output) {
        return converter.convertUint256ToAddress(converter.convertAddressToUint256(input));
    }

    /**
     * Skip a test.
     */
    modifier skipTest() {
        // solhint-disable-next-line no-console
        console.log("Test skipped");
        if (false) {
            // Required for compiler
            _;
        }
    }
}
