// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

interface IERC721FloorWrapper is IERC1155 {
    event TokensDeposited(address indexed tokenAddr, uint256[] tokenIds);

    event TokensWithdrawn(address indexed tokenAddr, uint256[] tokenIds);

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param tokenAddr The address of the ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to deposit.
     * @param recipient The recipient of the wrapped tokens.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     * @dev This contract intentionally does not support IERC721Receiver for gas optimisations.
     */
    function deposit(address tokenAddr, uint256[] memory tokenIds, address recipient) external;

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param tokenAddr The address of the ERC-721 tokens.
     * @param tokenIds The ERC-721 token ids to withdraw.
     * @param recipient The recipient of the unwrapped tokens.
     */
    function withdraw(address tokenAddr, uint256[] memory tokenIds, address recipient) external;
}
