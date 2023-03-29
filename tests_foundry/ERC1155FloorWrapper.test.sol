// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC1155FloorWrapper} from "src/contracts/wrappers/ERC1155FloorWrapper.sol";
import {ERC1155FloorFactory} from "src/contracts/wrappers/ERC1155FloorFactory.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {INiftyswapExchange20} from "src/contracts/interfaces/INiftyswapExchange20.sol";
import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {WrapperErrors} from "src/contracts/utils/WrapperErrors.sol";

import {NiftyswapTestHelper} from "./utils/NiftyswapTestHelper.test.sol";
import {Niftyswap20TestHelper} from "./utils/Niftyswap20TestHelper.test.sol";
import {TestHelperBase} from "./utils/TestHelperBase.test.sol";
import {USER, OPERATOR} from "./utils/Constants.test.sol";

import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

contract ERC1155FloorWrapperTest is TestHelperBase, WrapperErrors {
    // Redeclare events
    event TokensDeposited(uint256[] tokenIds, uint256[] tokenAmounts);
    event TokensWithdrawn(uint256[] tokenIds, uint256[] tokenAmounts);

    ERC1155FloorWrapper private wrapper;
    address private wrapperAddr;
    ERC1155Mock private erc1155;
    address private erc1155Addr;
    uint256 private wrapperTokenId;

    function setUp() external {
        erc1155 = new ERC1155Mock();
        erc1155Addr = address(erc1155);

        wrapper = new ERC1155FloorWrapper();
        wrapper.initialize(erc1155Addr);
        wrapperAddr = address(wrapper);
        wrapperTokenId = wrapper.TOKEN_ID();

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
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(tokenIds, tokenAmounts);
        wrapper.deposit(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal + 1, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal + 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 1, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_happyPathWithFactory() public withFactoryCreatedWrapper {
        test_deposit_happyPath();
    }

    function test_deposit_toRecipient() public {
        uint256 beforeWrapperOperatorBal = wrapper.balanceOf(OPERATOR, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(tokenIds, tokenAmounts);
        wrapper.deposit(tokenIds, tokenAmounts, OPERATOR, "");

        assertEq(beforeWrapperOperatorBal + 1, wrapper.balanceOf(OPERATOR, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal + 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 1, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_twice() external {
        test_deposit_happyPath();
        test_deposit_happyPath();
    }

    function test_deposit_two() external {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 2;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensDeposited(tokenIds, tokenAmounts);
        wrapper.deposit(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal + 2, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal + 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 2, erc1155.balanceOf(USER, 0));
    }

    function test_deposit_twoDiffTokens() external {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
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
        emit TokensDeposited(tokenIds, tokenAmounts);
        wrapper.deposit(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal + 2, wrapper.balanceOf(USER, wrapperTokenId));
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
        wrapper.deposit(tokenIds, tokenAmounts, USER, "");
    }

    function test_deposit_andSell() public withDeposit {
        // Niftyswap
        ERC1155Mock currency = new ERC1155Mock();
        address currencyAddr = address(currency);
        NiftyswapFactory factory = new NiftyswapFactory();
        // Wrapped tokens are never currency
        factory.createExchange(wrapperAddr, currencyAddr, 0);
        address exchangeAddr = factory.tokensToExchange(wrapperAddr, currencyAddr, 0);
        uint256[] memory types = new uint256[](1);
        types[0] = wrapperTokenId;
        withERC1155Liquidity(currency, exchangeAddr, types);
        // Sell data
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 2;
        uint256[] memory prices = INiftyswapExchange(exchangeAddr).getPrice_tokenToCurrency(types, sellAmounts);

        // Before bals
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);
        uint256 beforeCurrencyUserBal = currency.balanceOf(USER, 0);

        // Deposit and sell
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.prank(USER);
        wrapper.deposit(
            tokenIds, sellAmounts, exchangeAddr, NiftyswapTestHelper.encodeSellTokens(USER, prices[0], block.timestamp)
        );

        // After bals
        assertEq(beforeWrapperUserBal, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal + 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 2, erc1155.balanceOf(USER, 0));
        assertEq(beforeCurrencyUserBal + prices[0], currency.balanceOf(USER, 0));
    }

    function test_deposit_andSell20() public withDeposit {
        // Niftyswap
        ERC20TokenMock currency = new ERC20TokenMock();
        address currencyAddr = address(currency);
        NiftyswapFactory20 factory = new NiftyswapFactory20(address(this));
        // Wrapped tokens are never currency
        factory.createExchange(wrapperAddr, currencyAddr, 0, 0);
        address exchangeAddr = factory.tokensToExchange(wrapperAddr, currencyAddr, 0, 0);
        uint256[] memory types = new uint256[](1);
        types[0] = wrapperTokenId;
        withERC20Liquidity(currency, exchangeAddr, types);
        // Sell data
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 2;
        uint256[] memory prices = INiftyswapExchange(exchangeAddr).getPrice_tokenToCurrency(types, sellAmounts);

        // Before bals
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);
        uint256 beforeCurrencyUserBal = currency.balanceOf(USER);

        // Deposit and sell
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        vm.prank(USER);
        wrapper.deposit(
            tokenIds,
            sellAmounts,
            exchangeAddr,
            Niftyswap20TestHelper.encodeSellTokens(USER, prices[0], new address[](0), new uint256[](0), block.timestamp)
        );

        // After bals
        assertEq(beforeWrapperUserBal, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal + 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal - 2, erc1155.balanceOf(USER, 0));
        assertEq(beforeCurrencyUserBal + prices[0], currency.balanceOf(USER));
    }

    //
    // Withdraw
    //
    function test_withdraw_happyPath() public withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(tokenIds, tokenAmounts);
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal + 1, erc1155.balanceOf(USER, 0));
    }

    function test_withdraw_happyPathWithFactory() public withFactoryCreatedWrapper {
        test_withdraw_happyPath();
    }

    function test_withdraw_toRecipient() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155OperatorBal = erc1155.balanceOf(OPERATOR, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(tokenIds, tokenAmounts);
        wrapper.withdraw(tokenIds, tokenAmounts, OPERATOR, "");

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, wrapperTokenId));
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
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");
    }

    function test_withdraw_twice() external {
        test_withdraw_happyPath();

        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155OperatorBal = erc1155.balanceOf(OPERATOR, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(tokenIds, tokenAmounts);
        wrapper.withdraw(tokenIds, tokenAmounts, OPERATOR, "");

        assertEq(beforeWrapperUserBal - 1, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal - 1, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155OperatorBal + 1, erc1155.balanceOf(OPERATOR, 0));
    }

    function test_withdraw_two() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
        uint256 beforeERC1155WrapperBal = erc1155.balanceOf(wrapperAddr, 0);
        uint256 beforeERC1155UserBal = erc1155.balanceOf(USER, 0);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 2;

        vm.prank(USER);
        vm.expectEmit(true, true, true, true, wrapperAddr);
        emit TokensWithdrawn(tokenIds, tokenAmounts);
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal - 2, wrapper.balanceOf(USER, wrapperTokenId));
        assertEq(beforeERC1155WrapperBal - 2, erc1155.balanceOf(wrapperAddr, 0));
        assertEq(beforeERC1155UserBal + 2, erc1155.balanceOf(USER, 0));
    }

    function test_withdraw_twoDiffTokens() external withDeposit {
        uint256 beforeWrapperUserBal = wrapper.balanceOf(USER, wrapperTokenId);
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
        emit TokensWithdrawn(tokenIds, tokenAmounts);
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");

        assertEq(beforeWrapperUserBal - 2, wrapper.balanceOf(USER, wrapperTokenId));
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
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");
    }

    function test_withdraw_insufficientBalance() external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = 1;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        wrapper.withdraw(tokenIds, tokenAmounts, USER, "");
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
    modifier withFactoryCreatedWrapper() {
        // Recreate wrapper through factory
        ERC1155FloorFactory factory = new ERC1155FloorFactory(address(this));
        wrapper = ERC1155FloorWrapper(factory.createWrapper(address(erc1155)));
        wrapperAddr = address(wrapper);
        wrapperTokenId = wrapper.TOKEN_ID();

        // Approvals
        vm.prank(USER);
        erc1155.setApprovalForAll(wrapperAddr, true);
        vm.prank(OPERATOR);
        erc1155.setApprovalForAll(wrapperAddr, true);

        _;
    }

    modifier withDeposit() {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        uint256[] memory tokenAmounts = new uint256[](2);
        tokenAmounts[0] = 2;
        tokenAmounts[1] = 2;

        vm.prank(USER);
        wrapper.deposit(tokenIds, tokenAmounts, USER, "");
        vm.prank(OPERATOR);
        wrapper.deposit(tokenIds, tokenAmounts, OPERATOR, "");

        _;
    }

    function withERC1155Liquidity(ERC1155Mock erc1155Mock, address exchangeAddr, uint256[] memory types) private {
        // Mint tokens
        erc1155Mock.mintMock(OPERATOR, 0, 1000000001, "");
        erc1155Mock.mintMock(USER, 0, 1000000001, "");

        // Approvals
        vm.prank(OPERATOR);
        erc1155Mock.setApprovalForAll(exchangeAddr, true);
        vm.prank(USER);
        erc1155Mock.setApprovalForAll(exchangeAddr, true);

        // Liquidity
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 1000000001;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 2;
        vm.prank(OPERATOR);
        wrapper.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            types,
            tokensToAdd,
            NiftyswapTestHelper.encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    function withERC20Liquidity(ERC20TokenMock currency, address exchangeAddr, uint256[] memory types) private {
        uint256 tokenAmt = 1000000001;
        // Mint tokens
        currency.mockMint(OPERATOR, tokenAmt);
        currency.mockMint(USER, tokenAmt);

        // Approvals
        vm.prank(OPERATOR);
        currency.approve(exchangeAddr, tokenAmt);
        vm.prank(USER);
        currency.approve(exchangeAddr, tokenAmt);

        // Liquidity
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = tokenAmt;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 2;
        vm.prank(OPERATOR);
        wrapper.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            types,
            tokensToAdd,
            Niftyswap20TestHelper.encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
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
