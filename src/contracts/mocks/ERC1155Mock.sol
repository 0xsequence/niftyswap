// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;
import "@0xsequence/erc-1155/contracts/mocks/ERC1155MintBurnMock.sol";


contract ERC1155Mock is ERC1155MintBurnMock {
  constructor() ERC1155MintBurnMock("TestERC1155", "") {}
}
