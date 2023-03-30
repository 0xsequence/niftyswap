// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

interface IERC1155FloorWrapper is IERC1155 {
    event TokensDeposited(uint256[] tokenIds, uint256[] tokenAmounts);

    event TokensWithdrawn(uint256[] tokenIds, uint256[] tokenAmounts);

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
    ) external;

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
    ) external;
}
