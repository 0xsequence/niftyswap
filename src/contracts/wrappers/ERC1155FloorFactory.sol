// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC1155FloorFactory} from "../interfaces/IERC1155FloorFactory.sol";
import {ERC1155FloorWrapper} from "../wrappers/ERC1155FloorWrapper.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";
import {Ownable} from "../utils/Ownable.sol";
import {Proxy} from "../utils/Proxy.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

contract ERC1155FloorFactory is IERC1155FloorFactory, Ownable, IDelegatedERC1155Metadata, WrapperErrors {
    mapping(address => address) public override tokenToWrapper;
    ERC1155FloorWrapper private wrapperImpl;

    IERC1155Metadata internal metadataContract; // address of the ERC-1155 Metadata contract

    constructor(address _admin) Ownable(_admin) {
        wrapperImpl = new ERC1155FloorWrapper();
        wrapperImpl.initialize(address(0));
    }

    /**
     * Creates an ERC-1155 Floor Wrapper for given token contract
     * @param tokenAddr The address of the ERC-1155 token contract
     * @return wrapperAddr The address of the ERC-1155 Floor Wrapper
     */
    function createWrapper(address tokenAddr) external returns (address wrapperAddr) {
        if (tokenToWrapper[tokenAddr] != address(0)) {
            revert WrapperAlreadyCreated(tokenAddr, tokenToWrapper[tokenAddr]);
        }

        // Compute the address of the proxy contract using create2
        bytes memory code = abi.encodePacked(type(Proxy).creationCode, uint256(uint160(address(wrapperImpl))));
        bytes32 salt = keccak256(abi.encodePacked(tokenAddr));

        // Deploy it
        assembly {
            wrapperAddr := create2(0, add(code, 32), mload(code), salt)
        }
        if (wrapperAddr == address(0)) {
            revert WrapperCreationFailed(tokenAddr);
        }
        ERC1155FloorWrapper(wrapperAddr).initialize(tokenAddr);

        tokenToWrapper[tokenAddr] = wrapperAddr;

        emit NewERC1155FloorWrapper(tokenAddr);
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
