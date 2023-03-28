// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {Test, Vm, console} from "forge-std/Test.sol";

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

    function test_createExchange_happyPath() external {
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155B, BASE_TOKEN_ID, address(0));
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID);

        address ex = factory.tokensToExchange(erc1155A, erc1155B, BASE_TOKEN_ID);
        assertFalse(ex == address(0));
    }

    function test_createExchange_alreadyCreated() external {
        createExchange();

        vm.expectRevert("NiftyswapFactory#createExchange: EXCHANGE_ALREADY_CREATED");
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID);
    }

    function test_createExchange_revertOnZeroAddr() external {
        vm.expectRevert("NE#01");
        factory.createExchange(address(0), erc1155B, BASE_TOKEN_ID);
        vm.expectRevert("NE#01");
        factory.createExchange(erc1155A, address(0), BASE_TOKEN_ID);
    }

    function test_createExchange_newBaseTokenId() external {
        createExchange();

        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1, address(0));
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1);

        address ex = factory.tokensToExchange(erc1155A, erc1155B, BASE_TOKEN_ID + 1);
        assertFalse(ex == address(0));
    }

    function test_createExchange_sameContract() external {
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155A, erc1155A, BASE_TOKEN_ID, address(0));
        factory.createExchange(erc1155A, erc1155A, BASE_TOKEN_ID);

        address ex = factory.tokensToExchange(erc1155A, erc1155A, BASE_TOKEN_ID);
        assertFalse(ex == address(0));
    }

    //
    // Helpers
    //
    function createExchange() private {
        factory.createExchange(erc1155A, erc1155B, BASE_TOKEN_ID);
    }

    /**
     * Skip a test.
     */
    modifier skipTest() {
        // solhint-disable-next-line no-console
        console.log("Test skipped");
        if (false) {
            // Required for compiler
            _;
        }
    }
}
