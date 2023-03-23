// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC721FloorWrapper} from "src/contracts/utils/ERC721FloorWrapper.sol";
import {ERC721Mock} from "src/contracts/mocks/ERC721Mock.sol";

import {TestHelperBase} from "./utils/TestHelperBase.test.sol";

import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

contract ERC721FloorWrapperTest is TestHelperBase {
    // Redeclare events
    event TokensDeposited(address indexed tokenAddr, uint256[] tokenIds);
    event TokensWithdrawn(address indexed tokenAddr, uint256[] tokenIds);

    ERC721FloorWrapper private wrapper;
    address private wrapperAddr;
    ERC721Mock private erc721;
    address private erc721Addr;
    uint256 private erc721Uint256; // The Uint256 value of erc721Addr

    function setUp() external {
        wrapper = new ERC721FloorWrapper();
        wrapperAddr = address(wrapper);
        erc721 = new ERC721Mock();
        erc721Addr = address(erc721);
        erc721Uint256 = wrapper.convertAddressToUint256(erc721Addr);

        // Give tokens
        erc721.mintMock(USER, 5);
        erc721.mintMock(OPERATOR, 5);

        // Approvals
        vm.prank(USER);
        erc721.setApprovalForAll(wrapperAddr, true);
        vm.prank(OPERATOR);
        erc721.setApprovalForAll(wrapperAddr, true);
    }

    //
    // Deposit
    //
    function test_deposit_happyPath() public {
        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721UserBal = erc721.balanceOf(USER);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = erc721.ownerOf(0) == USER ? 0 : 1; // Use 0 or 1

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc721Addr, tokenIds);
        wrapper.deposit(erc721Addr, tokenIds, USER);

        assertEq(beforeERC1155UserBal + 1, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal + 1, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721UserBal - 1, erc721.balanceOf(USER));
    }

    function test_deposit_toRecipient() public {
        uint256 beforeERC1155OperatorBal = wrapper.balanceOf(OPERATOR, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721UserBal = erc721.balanceOf(USER);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc721Addr, tokenIds);
        wrapper.deposit(erc721Addr, tokenIds, OPERATOR);

        assertEq(beforeERC1155OperatorBal + 1, wrapper.balanceOf(OPERATOR, erc721Uint256));
        assertEq(beforeERC721WrapperBal + 1, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721UserBal - 1, erc721.balanceOf(USER));
    }

    function test_deposit_twice() external {
        test_deposit_happyPath();
        test_deposit_happyPath();
    }

    function test_deposit_two() external {
        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721UserBal = erc721.balanceOf(USER);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc721Addr, tokenIds);
        wrapper.deposit(erc721Addr, tokenIds, USER);

        assertEq(beforeERC1155UserBal + 2, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal + 2, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721UserBal - 2, erc721.balanceOf(USER));
    }

    function test_deposit_duplicateFails() external {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 0;

        vm.prank(USER);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        wrapper.deposit(erc721Addr, tokenIds, USER);
    }

    function test_deposit_wrongOwner() external {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 5;

        vm.prank(USER);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        wrapper.deposit(erc721Addr, tokenIds, USER);
    }

    function test_deposit_invalidTokenAddr() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectRevert();
        wrapper.deposit(address(1), tokenIds, USER);
    }

    //
    // Withdraw
    //
    function test_withdraw_happyPath() public withDeposit {
        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721UserBal = erc721.balanceOf(USER);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc721Addr, tokenIds);
        wrapper.withdraw(erc721Addr, tokenIds, USER);

        assertEq(beforeERC1155UserBal - 1, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal - 1, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721UserBal + 1, erc721.balanceOf(USER));
    }

    function test_withdraw_toRecipient() external withDeposit {
        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721OperatorBal = erc721.balanceOf(OPERATOR);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc721Addr, tokenIds);
        wrapper.withdraw(erc721Addr, tokenIds, OPERATOR);

        assertEq(beforeERC1155UserBal - 1, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal - 1, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721OperatorBal + 1, erc721.balanceOf(OPERATOR));
    }

    function test_withdraw_undepositedToken() external withDeposit {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 4;

        vm.prank(USER);
        vm.expectRevert("ERC721: transfer from incorrect owner");
        wrapper.withdraw(erc721Addr, tokenIds, USER);
    }

    function test_withdraw_twice() external {
        test_withdraw_happyPath();

        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721OperatorBal = erc721.balanceOf(OPERATOR);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc721Addr, tokenIds);
        wrapper.withdraw(erc721Addr, tokenIds, OPERATOR);

        assertEq(beforeERC1155UserBal - 1, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal - 1, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721OperatorBal + 1, erc721.balanceOf(OPERATOR));
    }

    function test_withdraw_two() external withDeposit {
        uint256 beforeERC1155UserBal = wrapper.balanceOf(USER, erc721Uint256);
        uint256 beforeERC721WrapperBal = erc721.balanceOf(wrapperAddr);
        uint256 beforeERC721UserBal = erc721.balanceOf(USER);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc721Addr, tokenIds);
        wrapper.withdraw(erc721Addr, tokenIds, USER);

        assertEq(beforeERC1155UserBal - 2, wrapper.balanceOf(USER, erc721Uint256));
        assertEq(beforeERC721WrapperBal - 2, erc721.balanceOf(wrapperAddr));
        assertEq(beforeERC721UserBal + 2, erc721.balanceOf(USER));
    }

    function test_withdraw_invalidTokenAddr() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectRevert();
        wrapper.withdraw(address(1), tokenIds, USER);
    }

    function test_withdraw_insufficientBalance() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        wrapper.withdraw(erc721Addr, tokenIds, USER);
    }

    //
    // Helpers
    //
    modifier withDeposit() {
        uint256[] memory tokenIds = new uint256[](2);

        tokenIds[0] = 0;
        tokenIds[1] = 1;
        vm.prank(USER);
        wrapper.deposit(erc721Addr, tokenIds, USER);

        tokenIds[0] = 5;
        tokenIds[1] = 6;
        vm.prank(OPERATOR);
        wrapper.deposit(erc721Addr, tokenIds, OPERATOR);
        _;
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
