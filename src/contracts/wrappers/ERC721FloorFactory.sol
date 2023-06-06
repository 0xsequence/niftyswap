// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC721FloorFactory} from "../interfaces/IERC721FloorFactory.sol";
import {ERC721FloorWrapper} from "../wrappers/ERC721FloorWrapper.sol";
import {Ownable} from "../utils/Ownable.sol";
import {Proxy} from "../utils/Proxy.sol";
import {WrapperProxyDeployer} from "../utils/WrapperProxyDeployer.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

contract ERC721FloorFactory is IERC721FloorFactory, Ownable, IDelegatedERC1155Metadata, WrapperProxyDeployer {
    address private immutable implAddr; // Address of the wrapper implementation
    IERC1155Metadata internal metadataContract; // Address of the ERC-1155 Metadata contract

    /**
     * Creates an ERC-721 Floor Factory.
     * @param _admin The address of the admin of the factory
     */
    constructor(address _admin) Ownable(_admin) {
        ERC721FloorWrapper wrapperImpl = new ERC721FloorWrapper();
        implAddr = address(wrapperImpl);
    }

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract
     * @param _tokenAddr The address of the ERC-721 token contract
     * @return wrapperAddr The address of the ERC-721 Floor Wrapper
     */
    function createWrapper(address _tokenAddr) external returns (address wrapperAddr) {
        wrapperAddr = deployProxy(implAddr, _tokenAddr);
        ERC721FloorWrapper(wrapperAddr).initialize(_tokenAddr);
        emit NewERC721FloorWrapper(_tokenAddr);
        return wrapperAddr;
    }

    /**
     * Return address of the ERC-721 Floor Wrapper for a given token contract
     * @param _tokenAddr The address of the ERC-721 token contract
     * @return wrapperAddr The address of the ERC-721 Floor Wrapper
     */
    function tokenToWrapper(address _tokenAddr) public view returns (address wrapperAddr) {
        wrapperAddr = predictWrapperAddress(implAddr, _tokenAddr);
        if (!isContract(wrapperAddr)) {
            return address(0);
        }

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
