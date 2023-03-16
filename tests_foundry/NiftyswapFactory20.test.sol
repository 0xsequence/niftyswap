// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {Test, Vm, console} from "forge-std/Test.sol";

contract NiftyswapFactory20Test is Test {
    // Events can't be imported
    event NewExchange(address indexed token, address indexed currency, uint256 indexed salt, uint256 lpFee, address exchange);

    uint256 private constant LP_FEE = 420;
    uint256 private constant INSTANCE_ID = 69;

    NiftyswapFactory20 private factory;
    address private erc20;
    address private erc1155;

    function setUp() external {
        factory = new NiftyswapFactory20(address(this));
        erc20 = address(new ERC20TokenMock());
        erc1155 = address(new ERC1155Mock());
    }

    //
    // createExchange
    //

    function test_createExchange_happyPath() external {
        // Happy path
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155, erc20, INSTANCE_ID, LP_FEE, address(0));
        factory.createExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);

        address ex = factory.tokensToExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);
        assertFalse(ex == address(0));
    }

    function test_createExchange_alreadyCreated() external {
        createExchange();

        vm.expectRevert("NF20#1");
        factory.createExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);
    }

    function test_createExchange_revertOnZeroAddr() external {
        vm.expectRevert('NE20#1');
        factory.createExchange(address(0), erc1155, LP_FEE, INSTANCE_ID);
        vm.expectRevert('NE20#1');
        factory.createExchange(erc20, address(0), LP_FEE, INSTANCE_ID);
    }

    function test_createExchange_newBaseTokenId() external {
        createExchange();

        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc1155, erc20, INSTANCE_ID + 1, LP_FEE, address(0));
        factory.createExchange(erc1155, erc20, LP_FEE, INSTANCE_ID + 1);

        address ex = factory.tokensToExchange(erc1155, erc20, LP_FEE, INSTANCE_ID + 1);
        assertFalse(ex == address(0));
    }

    function test_createExchange_invalidERCTypes() external skipTest {
        //TODO Should we handle invalid ERC types like this?
        vm.expectRevert();
        factory.createExchange(erc20, erc20, LP_FEE, INSTANCE_ID);
        vm.expectRevert();
        factory.createExchange(erc1155, erc1155, LP_FEE, INSTANCE_ID);
    }

    function test_createExchange_invalidLpFee() external {
        vm.expectRevert('NE20#2');
        factory.createExchange(erc1155, erc20, 1001, INSTANCE_ID);
    }

    //
    // getPairExchanges
    //

    function test_getPairExchanges_returnsArray() external {
        factory.createExchange(erc1155, erc20, 200, 1);
        factory.createExchange(erc1155, erc20, 50, 99);
        factory.createExchange(erc1155, erc20, 10, 0);

        address ex1 = factory.tokensToExchange(erc1155, erc20, 200, 1);
        address ex2 = factory.tokensToExchange(erc1155, erc20, 50, 99);
        address ex3 = factory.tokensToExchange(erc1155, erc20, 10, 0);

        address[] memory result = factory.getPairExchanges(erc1155, erc20);

        assertEq(result[0], ex1);
        assertEq(result[1], ex2);
        assertEq(result[2], ex3);
    }

    //
    // Helpers
    //

    function createExchange() private {
        factory.createExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);
    }

    /**
     * Skip a test.
     */
    modifier skipTest() {
        console.log("Test skipped");
        if (false) {
            // Required for compiler
            _;
        }
    }

}
