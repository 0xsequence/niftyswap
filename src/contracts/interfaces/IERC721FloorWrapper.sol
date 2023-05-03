// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";

interface IERC721FloorWrapper is IERC1155 {
    event TokensDeposited(uint256[] tokenIds);

    event TokensWithdrawn(uint256[] tokenIds);

    /**
     * Deposit and wrap ERC-721 tokens.
     * @param _tokenIds The ERC-721 token ids to deposit.
     * @param _recipient The recipient of the wrapped tokens.
     * @param _data Data to pass to ERC-1155 receiver.
     * @notice Users must first approve this contract address on the ERC-721 contract.
     * @dev This contract intentionally does not support IERC721Receiver for gas optimisations.
     */
    function deposit(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external;

    /**
     * Unwrap and withdraw ERC-721 tokens.
     * @param _tokenIds The ERC-721 token ids to withdraw.
     * @param _recipient The recipient of the unwrapped tokens.
     * @param _data Data to pass to ERC-1155 receiver.
     */
    function withdraw(uint256[] calldata _tokenIds, address _recipient, bytes calldata _data) external;
}
