// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

interface IERC1155FloorWrapper is IERC1155, IERC1155TokenReceiver {
    event TokensDeposited(uint256[] tokenIds, uint256[] tokenAmounts);

    event TokensWithdrawn(uint256[] tokenIds, uint256[] tokenAmounts);

    struct DepositRequestObj {
        address recipient;
        bytes data;
    }

    struct WithdrawRequestObj {
        uint256[] tokenIds;
        uint256[] tokenAmounts;
        address recipient;
        bytes data;
    }

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @notice Unwrapped ERC-1155 tokens are treated as deposits. Wrapped ERC-1155 tokens are treated as withdrawals.
     * @param _operator The address which called `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _id The ID of the token being transferred.
     * @param _amount The amount of tokens being transferred.
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)`
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data)
        external
        returns (bytes4);

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @notice Unwrapped ERC-1155 tokens are treated as deposits. Wrapped ERC-1155 tokens are treated as withdrawals.
     * @param _operator The address which called `safeTransferFrom` function.
     * @param _from The address which previously owned the token.
     * @param _ids The IDs of the tokens being transferred.
     * @param _amounts The amounts of tokens being transferred.
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external returns (bytes4);
}
