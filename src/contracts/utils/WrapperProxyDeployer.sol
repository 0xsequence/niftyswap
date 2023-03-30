// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC721FloorFactory} from "../interfaces/IERC721FloorFactory.sol";
import {ERC721FloorWrapper} from "../wrappers/ERC721FloorWrapper.sol";
import {WrapperErrors} from "../utils/WrapperErrors.sol";
import {Ownable} from "../utils/Ownable.sol";
import {Proxy} from "../utils/Proxy.sol";
import {IDelegatedERC1155Metadata, IERC1155Metadata} from "../interfaces/IDelegatedERC1155Metadata.sol";

abstract contract WrapperProxyDeployer is WrapperErrors {
    /**
     * Creates a proxy contract for a given implementation
     * @param implAddr The address of the proxy implementation
     * @param tokenAddr The address of the token contract
     * @return proxyAddr The address of the deployed proxy
     */
    function deployProxy(address implAddr, address tokenAddr) internal returns (address proxyAddr) {
        bytes memory code = getProxyCode(implAddr);
        implAddr = predictWrapperAddress(code, tokenAddr);
        if (isContract(implAddr)) {
            revert WrapperAlreadyCreated(tokenAddr, implAddr);
        }

        // Compute the address of the proxy contract using create2
        bytes32 salt = getProxySalt(tokenAddr);

        // Deploy it
        assembly {
            implAddr := create2(0, add(code, 32), mload(code), salt)
        }
        if (implAddr == address(0)) {
            revert WrapperCreationFailed(tokenAddr);
        }
        return implAddr;
    }

    function predictWrapperAddress(address implAddr, address tokenAddr) internal view returns (address) {
        bytes memory code = getProxyCode(implAddr);
        return predictWrapperAddress(code, tokenAddr);
    }

    function predictWrapperAddress(bytes memory code, address tokenAddr) private view returns (address) {
        bytes32 salt = getProxySalt(tokenAddr);
        address deployer = address(this);
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(code)));
        return address(uint160(uint256(_data)));
    }

    function getProxyCode(address implAddr) private pure returns (bytes memory) {
        return abi.encodePacked(type(Proxy).creationCode, uint256(uint160(address(implAddr))));
    }

    function getProxySalt(address tokenAddr) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenAddr));
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 csize;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            csize := extcodesize(addr)
        }
        return csize != 0;
    }
}
