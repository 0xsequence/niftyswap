// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "../interfaces/IERC1155Metadata.sol";
import {IDelegatedERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";

import {IERC721} from "../interfaces/IERC721.sol";
import {IERC721FloorWrapper} from "../interfaces/IERC721FloorWrapper.sol";

/**
 * @notice Allows users to wrap any amount of a ERC-721 token with a 1:1 ratio.
 * Therefore each ERC-721 within a collection can be treated as if fungible.
 */
contract ERC721FloorWrapper is IERC721FloorWrapper, ERC1155MintBurn, IERC1155Metadata, WrapperErrors {
    IERC721 public token;
    address internal immutable factory;
    // This contract only supports a single token id
    uint256 public constant TOKEN_ID = 0;

    constructor() {
        factory = msg.sender;
    }

    function initialize(address tokenAddr) external {
        if (msg.sender != factory || address(token) != address(0)) {
            revert InvalidInitialization();
        }
        token = IERC721(tokenAddr);
    }

    /**
     * Prevent invalid method calls.
     */
    fallback() external {
        revert UnsupportedMethod();
    }

    //
    // Tokens
    //

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to deposit.
     * @param recipient The recipient of the wrapped tokens.
     * @param data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     */
    function deposit(uint256[] calldata tokenIds, address recipient, bytes calldata data) external {
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            // Intentionally unsafe transfer
            token.transferFrom(msg.sender, address(this), tokenIds[i]);
            unchecked {
                // Can never overflow
                ++i;
            }
        }
        emit TokensDeposited(tokenIds);
        _mint(recipient, TOKEN_ID, tokenIds.length, data);
    }

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to withdraw.
     * @param recipient The recipient of the unwrapped tokens.
     * @param data Data to pass to ERC-1155 receiver.
     */
    function withdraw(uint256[] calldata tokenIds, address recipient, bytes calldata data) external {
        _burn(msg.sender, TOKEN_ID, tokenIds.length);
        emit TokensWithdrawn(tokenIds);
        uint256 length = tokenIds.length;
        for (uint256 i; i < length;) {
            token.safeTransferFrom(address(this), recipient, tokenIds[i], data);
            unchecked {
                // Can never overflow
                ++i;
            }
        }
    }

    //
    // Metadata
    //

    /**
     * A distinct Uniform Resource Identifier (URI) for a given token.
     * @param _id The token id.
     * @dev URIs are defined in RFC 3986.
     * The URI MUST point to a JSON file that conforms to the "ERC-1155 Metadata URI JSON Schema".
     * @return URI string
     */
    function uri(uint256 _id) external view override returns (string memory) {
        return IDelegatedERC1155Metadata(factory).metadataProvider().uri(_id);
    }

    /**
     * Query if a contract supports an interface.
     * @param  interfaceId The interfaceId to test.
     * @return supported Whether the interfaceId is supported.
     */
    function supportsInterface(bytes4 interfaceId) public pure override(IERC165, ERC1155) returns (bool supported) {
        return interfaceId == type(IERC165).interfaceId || interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155Metadata).interfaceId || super.supportsInterface(interfaceId);
    }
}
