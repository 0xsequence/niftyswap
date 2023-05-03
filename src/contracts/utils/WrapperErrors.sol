// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

/**
 * Errors for the ERC-1155 and ERC-721 Wrapper and Factory contracts.
 */
abstract contract WrapperErrors {
    // Factories
    error WrapperCreationFailed(address tokenAddr);

    // ERC1155
    error InvalidERC1155Received();
    error InvalidDepositRequest();
    error InvalidWithdrawRequest();

    // General
    error UnsupportedMethod();
    error InvalidInitialization();
}
