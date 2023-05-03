// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {WrapperErrors} from "../utils/WrapperErrors.sol";
import {Proxy} from "../utils/Proxy.sol";

abstract contract WrapperProxyDeployer is WrapperErrors {
    /**
     * Creates a proxy contract for a given implementation
     * @param implAddr The address of the proxy implementation
     * @param tokenAddr The address of the token contract
     * @return proxyAddr The address of the deployed proxy
     */
    function deployProxy(address implAddr, address tokenAddr) internal returns (address proxyAddr) {
        bytes memory code = getProxyCode(implAddr);
        bytes32 salt = getProxySalt(tokenAddr);

        // Deploy it
        assembly {
            proxyAddr := create2(0, add(code, 32), mload(code), salt)
        }
        if (proxyAddr == address(0)) {
            revert WrapperCreationFailed(tokenAddr);
        }
        return proxyAddr;
    }

    /**
     * Predict the deployed wrapper proxy address for a given implementation.
     * @param implAddr The address of the proxy implementation
     * @param tokenAddr The address of the token contract
     * @return proxyAddr The address of the deployed wrapper
     */
    function predictWrapperAddress(address implAddr, address tokenAddr) internal view returns (address proxyAddr) {
        bytes memory code = getProxyCode(implAddr);
        return predictWrapperAddress(code, tokenAddr);
    }

    /**
     * Predict the deployed wrapper proxy address for a given implementation.
     * @param code The code of the wrapper implementation
     * @param tokenAddr The address of the token contract
     * @return proxyAddr The address of the deployed wrapper
     */
    function predictWrapperAddress(bytes memory code, address tokenAddr) private view returns (address proxyAddr) {
        bytes32 salt = getProxySalt(tokenAddr);
        address deployer = address(this);
        bytes32 _data = keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, keccak256(code)));
        return address(uint160(uint256(_data)));
    }

    /**
     * Returns the code of the proxy contract for a given implementation
     * @param implAddr The address of the proxy implementation
     * @return code The code of the proxy contract
     */
    function getProxyCode(address implAddr) private pure returns (bytes memory code) {
        return abi.encodePacked(type(Proxy).creationCode, uint256(uint160(address(implAddr))));
    }

    /**
     * Returns the salt for the proxy contract for a given token contract
     * @param tokenAddr The address of the token contract
     * @return salt The salt for the proxy contract
     */
    function getProxySalt(address tokenAddr) private pure returns (bytes32 salt) {
        return keccak256(abi.encodePacked(tokenAddr));
    }

    /**
     * Checks if an address is a contract.
     * @param addr The address to check
     * @return result True if the address is a contract
     */
    function isContract(address addr) internal view returns (bool result) {
        uint256 csize;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            csize := extcodesize(addr)
        }
        return csize != 0;
    }
}
