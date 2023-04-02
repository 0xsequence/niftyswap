// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";
import {ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {IERC1155FloorWrapper} from "../interfaces/IERC1155FloorWrapper.sol";
import {IERC1155Metadata} from "../interfaces/IERC1155Metadata.sol";
import {IDelegatedERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";

/**
 * @notice Allows users to wrap any amount of a ERC-1155 token with a 1:1 ratio.
 * Therefore each ERC-1155 within a collection can be treated as if fungible.
 */
contract ERC1155FloorWrapper is
    IERC1155FloorWrapper,
    ERC1155MintBurn,
    IERC1155Metadata,
    IERC1155TokenReceiver,
    WrapperErrors
{
    address internal immutable factory;
    IERC1155 public token;
    // This contract only supports a single token id
    uint256 public constant TOKEN_ID = 0;

    bool private isDepositing;

    constructor() {
        factory = msg.sender;
    }

    function initialize(address tokenAddr) external {
        if (msg.sender != factory || address(token) != address(0)) {
            revert InvalidInitialization();
        }
        token = IERC1155(tokenAddr);
    }

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
     * @param tokenIds The ERC-1155 token ids to deposit.
     * @param tokenAmounts The amount of each token to deposit.
     * @param recipient The recipient of the wrapped tokens.
     * @param data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-1155 contract.
     */
    function deposit(
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        address recipient,
        bytes calldata data
    ) external {
        isDepositing = true;
        token.safeBatchTransferFrom(msg.sender, address(this), tokenIds, tokenAmounts, "");
        delete isDepositing;

        emit TokensDeposited(tokenIds, tokenAmounts);

        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += tokenAmounts[i];
        }
        _mint(recipient, TOKEN_ID, total, data);
    }

    /**
     * Unwrap and withdraw ERC-1155 tokens.
     * @param tokenIds The ERC-1155 token ids to withdraw.
     * @param tokenAmounts The amount of each token to deposit.
     * @param recipient The recipient of the unwrapped tokens.
     * @param data Data to pass to ERC-1155 receiver.
     */
    function withdraw(
        uint256[] calldata tokenIds,
        uint256[] calldata tokenAmounts,
        address recipient,
        bytes calldata data
    ) external {
        uint256 total;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            total += tokenAmounts[i];
        }
        _burn(msg.sender, TOKEN_ID, total);

        emit TokensWithdrawn(tokenIds, tokenAmounts);

        token.safeBatchTransferFrom(address(this), recipient, tokenIds, tokenAmounts, data);
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
