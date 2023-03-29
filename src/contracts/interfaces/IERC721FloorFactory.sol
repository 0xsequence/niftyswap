// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface IERC721FloorFactory {
    event NewERC721FloorWrapper(address indexed token);
    event MetadataContractChanged(address indexed metadataContract);

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract
     * @param tokenAddr The address of the ERC-721 token contract
     * @return The address of the ERC-721 Floor Wrapper
     */
    function createWrapper(address tokenAddr) external returns (address);

    /**
     * Return address of the ERC-721 Floor Wrapper for a given token contract
     * @param tokenAddr The address of the ERC-721 token contract
     * @return The address of the ERC-721 Floor Wrapper
     */
    function tokenToWrapper(address tokenAddr) external view returns (address);
}
