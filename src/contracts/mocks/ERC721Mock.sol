// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * This is a test ERC721 contract with unlimited free minting.
 */
contract ERC721Mock is ERC721 {
    uint256 public minted;

    constructor() ERC721("ERC721Mock", "") {} // solhint-disable-line no-empty-blocks

    /**
     * Public and unlimited mint function
     */
    function mintMock(address to, uint256 amount) external {
        for (uint256 i; i < amount; i++) {
            _safeMint(to, minted + i);
        }
        minted += amount;
    }
}
