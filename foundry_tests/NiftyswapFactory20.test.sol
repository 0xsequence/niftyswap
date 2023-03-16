// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

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

    function test_createExchange() external {
        // Happy path
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc20, erc1155, INSTANCE_ID, LP_FEE, address(0));
        factory.createExchange(erc20, erc1155, LP_FEE, INSTANCE_ID);

        address ex = factory.tokensToExchange(erc20, erc1155, LP_FEE, INSTANCE_ID);
        assertFalse(ex == address(0));

        // Already created
        vm.expectRevert("NF20#1");
        factory.createExchange(erc20, erc1155, LP_FEE, INSTANCE_ID);

        // Revert on 0x0
        vm.expectRevert('NE20#1');
        factory.createExchange(address(0), erc1155, LP_FEE, INSTANCE_ID);
        vm.expectRevert('NE20#1');
        factory.createExchange(erc20, address(0), LP_FEE, INSTANCE_ID);

        // New base token id
        vm.expectEmit(true, true, true, false);
        emit NewExchange(erc20, erc1155, INSTANCE_ID + 1, LP_FEE, address(0));
        factory.createExchange(erc20, erc1155, LP_FEE, INSTANCE_ID + 1);

        ex = factory.tokensToExchange(erc20, erc1155, LP_FEE, INSTANCE_ID + 1);
        assertFalse(ex == address(0));

        //TODO Should we handle invalid ERC types?
        // vm.expectRevert();
        // factory.createExchange(erc20, erc20, LP_FEE, INSTANCE_ID);
        // vm.expectRevert();
        // factory.createExchange(erc1155, erc1155, LP_FEE, INSTANCE_ID);

        // Invalid lp fee
        vm.expectRevert('NE20#2');
        factory.createExchange(erc20, erc1155, 1001, INSTANCE_ID);
    }

}
