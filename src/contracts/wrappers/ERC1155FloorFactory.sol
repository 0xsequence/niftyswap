// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155FloorFactory} from "../interfaces/IERC1155FloorFactory.sol";
import {ERC1155FloorWrapper} from "../wrappers/ERC1155FloorWrapper.sol";
import {Ownable} from "../utils/Ownable.sol";
import {Proxy} from "../utils/Proxy.sol";
import {WrapperProxyDeployer} from "../utils/WrapperProxyDeployer.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

contract ERC1155FloorFactory is IERC1155FloorFactory, Ownable, IDelegatedERC1155Metadata, WrapperProxyDeployer {
    address private immutable implAddr; // Address of the wrapper implementation
    IERC1155Metadata internal metadataContract; // address of the ERC-1155 Metadata contract

    constructor(address _admin) Ownable(_admin) {
        ERC1155FloorWrapper wrapperImpl = new ERC1155FloorWrapper();
        implAddr = address(wrapperImpl);
    }

    /**
     * Creates an ERC-1155 Floor Wrapper for given token contract
     * @param tokenAddr The address of the ERC-1155 token contract
     * @return wrapperAddr The address of the ERC-1155 Floor Wrapper
     */
    function createWrapper(address tokenAddr) external returns (address wrapperAddr) {
        wrapperAddr = deployProxy(implAddr, tokenAddr);
        ERC1155FloorWrapper(wrapperAddr).initialize(tokenAddr);
        emit NewERC1155FloorWrapper(tokenAddr);
        return wrapperAddr;
    }

    /**
     * Return address of the ERC-1155 Floor Wrapper for a given token contract
     * @param tokenAddr The address of the ERC-1155 token contract
     * @return wrapperAddr The address of the ERC-1155 Floor Wrapper
     */
    function tokenToWrapper(address tokenAddr) public view returns (address wrapperAddr) {
        wrapperAddr = predictWrapperAddress(implAddr, tokenAddr);
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
