// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC1155MintBurnMock} from "@0xsequence/erc-1155/contracts/mocks/ERC1155MintBurnMock.sol";

contract ERC1155Mock is ERC1155MintBurnMock {
    constructor() ERC1155MintBurnMock("TestERC1155", "") {} // solhint-disable-line no-empty-blocks
}
