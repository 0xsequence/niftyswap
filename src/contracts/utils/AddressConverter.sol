// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

contract AddressConverter {
    /**
     * Convert an address into a uint256.
     * @param input The address to convert.
     * @return output The resulting uint256.
     */
    function convertAddressToUint256(address input) public pure returns (uint256 output) {
        return uint256(uint160(input));
    }

    /**
     * Convert a uint256 into an address.
     * @param input The uint256 to convert.
     * @return output The resulting address.
     * @dev As uint256 is larger than address, this may result in collisions.
     */
    function convertUint256ToAddress(uint256 input) public pure returns (address output) {
        return address(uint160(input));
    }
}
