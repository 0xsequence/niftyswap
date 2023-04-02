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
     * @param operator The address which called `safeTransferFrom` function.
     * @param from The address which previously owned the token.
     * @param id The ID of the token being transferred.
     * @param amount The amount of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155Received(address operator, address from, uint256 id, uint256 amount, bytes calldata data)
        external
        returns (bytes4);

    /**
     * Accepts ERC-1155 tokens to wrap and wrapped ERC-1155 tokens to unwrap.
     * @notice Unwrapped ERC-1155 tokens are treated as deposits. Wrapped ERC-1155 tokens are treated as withdrawals.
     * @param operator The address which called `safeTransferFrom` function.
     * @param from The address which previously owned the token.
     * @param ids The IDs of the tokens being transferred.
     * @param amounts The amounts of tokens being transferred.
     * @param data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external returns (bytes4);
}
