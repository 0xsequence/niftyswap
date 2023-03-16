// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

contract NiftyswapFactoryTest is Test {
    // Events can't be imported
    event NewExchange(address indexed token, address indexed currency, uint256 indexed currencyID, address exchange);

    uint256 private constant BASE_TOKEN_ID = 42069;

    NiftyswapFactory private factory;
    address private erc1155A;
    address private erc1155B;

    function setUp() external {
        factory = new NiftyswapFactory();
        erc1155A = address(new ERC1155Mock());
        erc1155B = address(new ERC1155Mock());
    }

    function test_createExchange() external {
        // Happy path
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155B, BASE_TOKEN_ID, address(0));
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID);

        address ex = factory.tokensToExchange(erc1155A, erc1155B, BASE_TOKEN_ID);
        assertFalse(ex == address(0));

        // Already created
        vm.expectRevert("NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED");
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID);

        // Revert on 0x0
        vm.expectRevert('NiftyswapExchange#constructor:INVALID_INPUT');
        factory.createExchange(address(0), erc1155B, BASE_TOKEN_ID);
        vm.expectRevert('NiftyswapExchange#constructor:INVALID_INPUT');
        factory.createExchange(erc1155A, address(0), BASE_TOKEN_ID);

        // New base token id
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1, address(0));
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1);

        ex = factory.tokensToExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1);
        assertFalse(ex == address(0));

        // Same contracts
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155A, BASE_TOKEN_ID, address(0));
        factory.createExchange(erc1155A, erc1155A, BASE_TOKEN_ID);

        ex = factory.tokensToExchange(erc1155A, erc1155A, BASE_TOKEN_ID);
        assertFalse(ex == address(0));
    }

}
