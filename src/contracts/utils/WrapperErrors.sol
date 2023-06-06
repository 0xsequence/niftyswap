// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

/**
 * Errors for the ERC-1155 and ERC-721 Wrapper and Factory contracts.
 */
abstract contract WrapperErrors {
    // Factories
    error WrapperCreationFailed(address tokenAddr);

    // Wrappers
    error InvalidERC721Received();
    error InvalidERC1155Received();
    error InvalidDepositRequest();
    error InvalidWithdrawRequest();
    error InvalidTransferRequest();

    // General
    error UnsupportedMethod();
    error InvalidInitialization();
}
