// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC1155FloorWrapper, InvalidERC1155Received} from "src/contracts/utils/ERC1155FloorWrapper.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {TestHelperBase} from "./utils/TestHelperBase.test.sol";

import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

contract ERC1155FloorWrapperTest is TestHelperBase {
    // Redeclare events
    event TokensDeposited(address tokenAddr, uint256[] tokenIds, uint256[] tokenAmounts);
    event TokensWithdrawn(address tokenAddr, uint256[] tokenIds, uint256[] tokenAmounts);

    ERC1155FloorWrapper private wrapper;
    address private wrapperAddr;
    ERC1155Mock private erc1155;
    address private erc1155Addr;
    uint256 private erc1155Uint256; // The Uint256 value of erc1155Addr

    function setUp() external {
        wrapper = new ERC1155FloorWrapper();
        wrapperAddr = address(wrapper);
        erc1155 = new ERC1155Mock();
        erc1155Addr = address(erc1155);
        erc1155Uint256 = wrapper.convertAddressToUint256(erc1155Addr);

        // Give tokens
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        tokenIds[2] = 2;
        uint256[] memory tokenAmounts = new uint256[](3);
        tokenAmounts[0] = 5;
        tokenAmounts[1] = 5;
        tokenAmounts[2] = 5;
        erc1155.batchMintMock(USER, tokenIds, tokenAmounts, "");
        erc1155.batchMintMock(OPERATOR, tokenIds, tokenAmounts, "");

        // Approvals
        vm.prank(USER);
        erc1155.setApprovalForAll(wrapperAddr, true);
        vm.prank(OPERATOR);
        erc1155.setApprovalForAll(wrapperAddr, true);
    }

    //
    // Deposit
    //
    function test_deposit_happyPath() public {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal + 1, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal + 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 1, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_toRecipient() public {
        uint256 beforeWrapperOperatorBal = wrapper.balanceOf(OPERATOR, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, OPERATOR);

        assertEq(beforeWrapperOperatorBal + 1, wrapper.balanceOf(OPERATOR, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal + 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 1, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_twice() external {
        test_deposit_happyPath();
        test_deposit_happyPath();
    }

    function test_deposit_two() external {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 2;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal + 2, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal + 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 2, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_twoDiffTokens() external {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal0 = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal0 = erc1155.balanceOf(USER, 0);
        uint256 beforeERC1155WrapperBal1 = erc1155.balanceOf(wrapperAddr, 1);
        uint256 beforeERC1155UserBal1 = erc1155.balanceOf(USER, 1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 1;
        tokenAmounts[1] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal + 2, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal0 + 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal0 - 1, erc1155.balanceOf(USER, 0));
        assertEq(beforeERC1155WrapperBal1 + 1, erc1155.balanceOf(wrapperAddr, 1));
        assertEq(beforeERC1155UserBal1 - 1, erc1155.balanceOf(USER, 1));
    }

    function test_deposit_wrongOwner() external {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 5;
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 1;
        tokenAmounts[1] = 1;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, USER);
    }

    function test_deposit_invalidTokenAddr() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectRevert();
        wrapper.deposit(address(1), tokenIds, tokenAmounts, USER);
    }

    //
    // Withdraw
    //
    function test_withdraw_happyPath() public withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal + 1, erc1155.balanceOf(USER, 0));
    }

    function test_withdraw_toRecipient() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155OperatorBal = erc1155.balanceOf(OPERATOR, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, OPERATOR);

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155OperatorBal + 1, erc1155.balanceOf(OPERATOR, 0));
    }

    function test_withdraw_undepositedToken() external withDeposit {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 2;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, USER);
    }

    function test_withdraw_twice() external {
        test_withdraw_happyPath();

        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155OperatorBal = erc1155.balanceOf(OPERATOR, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, OPERATOR);

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155OperatorBal + 1, erc1155.balanceOf(OPERATOR, 0));
    }

    function test_withdraw_two() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 2;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal - 2, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal - 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal + 2, erc1155.balanceOf(USER, 0));
    }

    function test_withdraw_twoDiffTokens() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, erc1155Uint256);
        uint256 beforeERC1155WrapperBal0 = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155WrapperBal1 = erc1155.balanceOf(wrapperAddr, 1);
        uint256 beforeERC1155UserBal0 = erc1155.balanceOf(USER, 0);
        uint256 beforeERC1155UserBal1 = erc1155.balanceOf(USER, 1);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 1;
        tokenAmounts[1] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(erc1155Addr, tokenIds, tokenAmounts);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, USER);

        assertEq(beforeWrapperUserBal - 2, wrapper.balanceOf(USER, erc1155Uint256));
        assertEq(beforeERC1155WrapperBal0 - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155WrapperBal1 - 1, erc1155.balanceOf(wrapperAddr, 1));
        assertEq(beforeERC1155UserBal0 + 1, erc1155.balanceOf(USER, 0));
        assertEq(beforeERC1155UserBal1 + 1, erc1155.balanceOf(USER, 1));
    }

    function test_withdraw_invalidTokenAddr() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectRevert();
        wrapper.withdraw(address(1), tokenIds, tokenAmounts, USER);
    }

    function test_withdraw_insufficientBalance() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        wrapper.withdraw(erc1155Addr, tokenIds, tokenAmounts, USER);
    }

    //
    // Transfers
    //
    function test_transfers_invalidTransfer() external {
        vm.prank(USER);
        vm.expectRevert(InvalidERC1155Received.selector);
        erc1155.safeTransferFrom(USER, wrapperAddr, 0, 1, "");
    }

    //
    // Helpers
    //
    modifier withDeposit() {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 2;
        tokenAmounts[1] = 2;

        vm.prank(USER);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, USER);
        vm.prank(OPERATOR);
        wrapper.deposit(erc1155Addr, tokenIds, tokenAmounts, OPERATOR);

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
