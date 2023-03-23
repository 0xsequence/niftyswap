// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {IERC1155FloorWrapper} from "../interfaces/IERC1155FloorWrapper.sol";
import {AddressConverter} from "./AddressConverter.sol";

// Errors
error UnsupportedMethod();
error InvalidERC1155Received();

/**
 * Allows an all token ids within an ERC-1155 contract to be wrapped and
 * treated as a single ERC-1155 token id.
 */
contract ERC1155FloorWrapper is
    IERC1155FloorWrapper,
    ERC1155,
    ERC1155MintBurn,
    IERC1155TokenReceiver,
    AddressConverter
{
    bool private isDepositing;

    modifier onlyDepositing() {
        if (!isDepositing) {
            revert InvalidERC1155Received();
        }
        delete isDepositing;
        _;
    }

    /**
     * Prevent invalid method calls.
     */
    fallback() external {
        revert UnsupportedMethod();
    }

    /**
     * Deposit and wrap ERC-1155 tokens.
     * @param tokenAddr The address of the ERC-1155 tokens.
     * @param tokenIds The ERC-1155 token ids to deposit.
     * @param tokenAmounts The amount of each token to deposit.
     * @param recipient The recipient of the wrapped tokens.
     * @notice Users must first approve this contract address on the ERC-1155 contract.
     */
    function deposit(address tokenAddr, uint256[] memory tokenIds, uint256[] memory tokenAmounts, address recipient)
        external
    {
        isDepositing = true;
        IERC1155(tokenAddr).safeBatchTransferFrom(msg.sender, address(this), tokenIds, tokenAmounts, "");
        delete isDepositing;

        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += tokenAmounts[i];
        }
        _mint(recipient, convertAddressToUint256(tokenAddr), total, "");

        emit TokensDeposited(tokenAddr, tokenIds, tokenAmounts);
    }

    /**
     * Unwrap and withdraw ERC-1155 tokens.
     * @param tokenAddr The address of the ERC-1155 tokens.
     * @param tokenIds The ERC-1155 token ids to withdraw.
     * @param tokenAmounts The amount of each token to deposit.
     * @param recipient The recipient of the unwrapped tokens.
     */
    function withdraw(address tokenAddr, uint256[] memory tokenIds, uint256[] memory tokenAmounts, address recipient)
        external
    {
        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += tokenAmounts[i];
        }
        _burn(msg.sender, convertAddressToUint256(tokenAddr), total);

        IERC1155(tokenAddr).safeBatchTransferFrom(address(this), recipient, tokenIds, tokenAmounts, "");

        emit TokensWithdrawn(tokenAddr, tokenIds, tokenAmounts);
    }

    /**
     * Handle the receipt of a single ERC-1155 token type.
     * @dev This function can only be called when deposits are in progress.
     */
    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        onlyDepositing
        returns (bytes4)
    {
        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    /**
     * Handle the receipt of multiple ERC-1155 token types.
     * @dev This function can only be called when deposits are in progress.
     */
    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        onlyDepositing
        returns (bytes4)
    {
        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }

    /**
     * Query if a contract supports an interface.
     * @param  interfaceId The interfaceId to test.
     * @return supported Whether the interfaceId is supported.
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC1155) returns (bool supported) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
