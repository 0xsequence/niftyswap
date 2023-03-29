// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC721FloorFactory} from "../interfaces/IERC721FloorFactory.sol";
import {ERC721FloorWrapper} from "../wrappers/ERC721FloorWrapper.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";
import {Ownable} from "../utils/Ownable.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

contract ERC721FloorFactory is IERC721FloorFactory, Ownable, IDelegatedERC1155Metadata, WrapperErrors {
    mapping(address => address) public override tokenToWrapper;

    IERC1155Metadata internal metadataContract; // address of the ERC-1155 Metadata contract

    constructor(address _admin) Ownable(_admin) {} // solhint-disable-line no-empty-blocks

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract
     * @param tokenAddr The address of the ERC-721 token contract
     * @return The address of the ERC-721 Floor Wrapper
     */
    function createWrapper(address tokenAddr) external returns (address) {
        if (tokenToWrapper[tokenAddr] != address(0)) {
            revert WrapperAlreadyCreated(tokenAddr, tokenToWrapper[tokenAddr]);
        }

        // Create new wrapper
        ERC721FloorWrapper wrapper = new ERC721FloorWrapper(tokenAddr);
        address wrapperAddr = address(wrapper);

        tokenToWrapper[tokenAddr] = wrapperAddr;

        emit NewERC721FloorWrapper(tokenAddr);
        return wrapperAddr;
    }

    //
    // Metadata
    //

    /**
     * Changes the implementation of the ERC-1155 Metadata contract
     * @dev This function changes the implementation for all child wrapper of this factory
     * @param _contract The address of the ERC-1155 Metadata contract
     */
    function setMetadataContract(IERC1155Metadata _contract) external onlyOwner {
        emit MetadataContractChanged(address(_contract));
        metadataContract = _contract;
    }

    /**
     * @notice Returns the address of the ERC-1155 Metadata contract
     */
    function metadataProvider() external view override returns (IERC1155Metadata) {
        return metadataContract;
    }
}
