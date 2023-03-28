// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC1155MintBurnPackedBalanceMock} from
    "@0xsequence/erc-1155/contracts/mocks/ERC1155MintBurnPackedBalanceMock.sol";

contract ERC1155PackedBalanceMock is ERC1155MintBurnPackedBalanceMock {
    constructor() ERC1155MintBurnPackedBalanceMock("TestERC1155", "") {} // solhint-disable-line no-empty-blocks
}
