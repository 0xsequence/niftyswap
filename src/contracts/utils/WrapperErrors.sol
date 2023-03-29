// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

/**
 * Errors for the ERC-1155 and ERC-721 Wrapper and Factory contracts.
 */
abstract contract WrapperErrors {
    // Factories
    error WrapperAlreadyCreated(address tokenAddr, address wrapperAddr);

    // General
    error UnsupportedMethod();
}
