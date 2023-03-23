// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721FloorWrapper} from "../interfaces/IERC721FloorWrapper.sol";
import {AddressConverter} from "./AddressConverter.sol";
import {ERC1155MetadataPrefix} from "./ERC1155MetadataPrefix.sol";

// Errors
error UnsupportedMethod();

/**
 * @notice Allows users to wrap any amount of any ERC-721 token with a 1:1 ratio
 *   of corresponding ERC-1155 tokens with native metaTransaction methods.
 *   Each ERC-721 within a collection is treated as if fungible.
 */
contract ERC721FloorWrapper is IERC721FloorWrapper, ERC1155MetadataPrefix, ERC1155MintBurn, AddressConverter {
    // solhint-disable-next-line no-empty-blocks
    constructor(string memory _prefix, address _admin) ERC1155MetadataPrefix(_prefix, false, _admin) {}

    /**
     * Prevent invalid method calls.
     */
    fallback() external {
        revert UnsupportedMethod();
    }

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param tokenAddr The address of the ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to deposit.
     * @param recipient The recipient of the wrapped tokens.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     */
    function deposit(address tokenAddr, uint256[] memory tokenIds, address recipient) external {
        for (uint256 i; i < tokenIds.length; i++) {
            //FIXME Gas optimisation
            // Intentionally unsafe transfer
            IERC721(tokenAddr).transferFrom(msg.sender, address(this), tokenIds[i]);
        }
        _mint(recipient, convertAddressToUint256(tokenAddr), tokenIds.length, "");
        emit TokensDeposited(tokenAddr, tokenIds);
    }

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param tokenAddr The address of the ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to withdraw.
     * @param recipient The recipient of the unwrapped tokens.
     */
    function withdraw(address tokenAddr, uint256[] memory tokenIds, address recipient) external {
        _burn(msg.sender, convertAddressToUint256(tokenAddr), tokenIds.length);
        for (uint256 i; i < tokenIds.length; i++) {
            //FIXME Gas optimisation
            IERC721(tokenAddr).safeTransferFrom(address(this), recipient, tokenIds[i]);
        }
        emit TokensWithdrawn(tokenAddr, tokenIds);
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
