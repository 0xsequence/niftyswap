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

    /**
     * Creates an ERC-721 Floor Factory.
     * @dev This contract is expected to be deployed by the ERC-721 Floor Factory.
     */
    constructor() {
        factory = msg.sender;
    }

    /**
     * Initializes the contract with the token address.
     * @param _tokenAddr The address of the ERC-721 token to wrap.
     * @dev This is expected to be called immediately after contract creation.
     */
    function initialize(address _tokenAddr) external {
        if (msg.sender != factory || address(token) != address(0)) {
            revert InvalidInitialization();
        }
        token = IERC721(_tokenAddr);
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
     * @param _tokenIds The ERC-721 token ids to deposit.
     * @param _recipient The recipient of the wrapped tokens.
     * @param _data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     */
    function deposit(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external {
        if (_recipient == address(0)) {
            revert InvalidDepositRequest();
        }

        uint256 length = _tokenIds.length;
        for (uint256 i; i < length;) {
            // Intentionally unsafe transfer
            token.transferFrom(msg.sender, address(this), _tokenIds[i]);
            unchecked {
                // Can never overflow
                i++;
            }
        }
        emit TokensDeposited(_tokenIds);
        _mint(_recipient, TOKEN_ID, length, _data);
    }

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param _tokenIds The ERC-721 token ids to withdraw.
     * @param _recipient The recipient of the unwrapped tokens.
     * @param _data Data to pass to ERC-721 receiver.
     */
    function withdraw(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external {
        if (_recipient == address(0)) {
            revert InvalidWithdrawRequest();
        }

        uint256 length = _tokenIds.length;
        _burn(msg.sender, TOKEN_ID, length);
        emit TokensWithdrawn(_tokenIds);
        for (uint256 i; i < length;) {
            token.safeTransferFrom(address(this), _recipient, _tokenIds[i], _data);
            unchecked {
                // Can never overflow
                i++;
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
     * @param _interfaceId The interfaceId to test.
     * @return supported Whether the interfaceId is supported.
     */
    function supportsInterface(bytes4 _interfaceId) public pure override(IERC165, ERC1155) returns (bool supported) {
        return _interfaceId == type(IERC165).interfaceId || _interfaceId == type(IERC1155).interfaceId
            || _interfaceId == type(IERC1155Metadata).interfaceId || super.supportsInterface(_interfaceId);
    }
}
