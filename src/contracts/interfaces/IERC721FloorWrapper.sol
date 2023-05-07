// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";
import {IERC721Receiver} from "./IERC721Receiver.sol";

interface IERC721FloorWrapper is IERC1155, IERC1155TokenReceiver, IERC721Receiver {
    event TokensDeposited(uint256[] tokenIds);

    event TokensWithdrawn(uint256[] tokenIds);

    struct DepositRequestObj {
        address recipient;
        bytes data;
    }

    struct WithdrawRequestObj {
        uint256[] tokenIds;
        address recipient;
        bytes data;
    }

    /**
     * Accepts ERC-721 tokens to wrap.
     * @param _operator The address which called `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _tokenId The ID of the token being transferred.
     * @param _data Additional data formatted as DepositRequestObj.
     * @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`
     * @notice This is the preferred method for wrapping a single token.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param _tokenIds The ERC-721 token ids to deposit.
     * @param _recipient The recipient of the wrapped tokens.
     * @param _data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     * @notice This function can wrap multiple ERC-721 tokens at once.
     */
    function deposit(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external;

    /**
     * Accepts wrapped ERC-1155 tokens to unwrap.
     * @param _operator The address which called `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _tokenId The ID of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     * @param _data Additional data formatted as WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)`
     */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bytes4);

    /**
     * Accepts wrapped ERC-1155 tokens to unwrap.
     * @param _operator The address which called `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _tokenIds The IDs of the tokens being transferred.
     * @param _amounts The amounts of tokens being transferred.
     * @param _data Additional data formatted as WithdrawRequestObj.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external returns (bytes4);
}
