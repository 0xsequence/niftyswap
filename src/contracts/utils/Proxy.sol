// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

contract Proxy {
    address public implementation;

    constructor(address _implementation) {
        implementation = _implementation;
    }

    receive() external payable {
        proxy();
    }

    fallback() external payable {
        proxy();
    }

    function proxy() private {
        address target;
        assembly {
            target := sload(implementation.slot)
        }
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), target, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }
}
