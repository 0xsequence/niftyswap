// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {INiftyswapExchange20} from "src/contracts/interfaces/INiftyswapExchange20.sol";
import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {
    NiftyswapExchange20Wrapper,
    INiftyswapExchange20Wrapper,
    InvalidRecipient
} from "src/contracts/wrapper/NiftyswapExchange20Wrapper.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";

import {Niftyswap20TestHelper} from "./utils/Niftyswap20TestHelper.test.sol";
import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

interface IERC1155Exchange is INiftyswapExchange20, IERC1155 {}

contract NiftyswapExchange20WrapperTest is Niftyswap20TestHelper {
    uint256[] private TOKEN_TYPES = [1, 2, 3];
    uint256[] private TOKENS_PER_TYPE = [500000, 500000, 500000];

    // Liquidity
    uint256[] private CURRENCIES_PER_TYPE = [299 * 10e18, 299 * 10e18, 299 * 10e18];

    // Fees
    address[] private NO_ADDRESSES;
    uint256[] private NO_FEES;

    NiftyswapExchange20Wrapper private wrapper;
    address private wrapperAddr;
    address private exchangeAddr;
    address private erc1155;
    ERC20TokenMock private erc20Mock;
    address private erc20;

    function setUp() external {
        wrapper = new NiftyswapExchange20Wrapper();
        wrapperAddr = address(wrapper);

        NiftyswapFactory20 factory = new NiftyswapFactory20(address(this));
        ERC1155Mock erc1155Mock = new ERC1155Mock();
        erc1155 = address(erc1155Mock);
        erc20Mock = new ERC20TokenMock();
        erc20 = address(erc20Mock);

        factory.createExchange(erc1155, erc20, 100, 0);
        exchangeAddr = factory.tokensToExchange(erc1155, erc20, 100, 0);
        IERC1155Exchange exchange = IERC1155Exchange(exchangeAddr);

        // Add liquidity
        erc1155Mock.batchMintMock(OPERATOR, TOKEN_TYPES, TOKENS_PER_TYPE, "");
        erc20Mock.mockMint(OPERATOR, 100000 ether);
        vm.startPrank(OPERATOR);
        erc20Mock.approve(exchangeAddr, 100000 ether);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            TOKEN_TYPES,
            TOKENS_PER_TYPE,
            encodeAddLiquidity(CURRENCIES_PER_TYPE, block.timestamp)
        );
        vm.stopPrank();
    }

    //
    // View
    //

    function test_supportsInterface() external {
        IERC165 exc = IERC165(wrapperAddr);
        assertTrue(
            exc.supportsInterface(type(INiftyswapExchange20Wrapper).interfaceId), "INiftyswapExchange20Wrapper support"
        );
        assertTrue(exc.supportsInterface(type(IERC1155TokenReceiver).interfaceId), "IERC1155Receiver support");
        assertTrue(exc.supportsInterface(type(IERC165).interfaceId), "IERC165 support");
    }

    //
    // Buy
    //

    function test_buyTokens_happyPath(uint256[] memory tokens, uint256 refundAmount) public {
        vm.assume(tokens.length > 2);
        // Data
        assembly {
            // Set tokens to size 3
            mstore(tokens, 3)
        }
        for (uint256 i; i < 3; i++) {
            tokens[i] = _bound(tokens[i], 10, 1000);
        }
        uint256[] memory prices = IERC1155Exchange(exchangeAddr).getPrice_currencyToToken(TOKEN_TYPES, tokens);
        uint256 totalPrice = getTotal(prices);
        refundAmount = _bound(refundAmount, 0, 1 ether);

        // ERC-20
        withERC20(USER, totalPrice + refundAmount);

        // Before bals
        uint256 wrapperCurrBefore = erc20Mock.balanceOf(wrapperAddr);
        uint256 exchangeCurrBefore = erc20Mock.balanceOf(exchangeAddr);
        uint256 userCurrBefore = erc20Mock.balanceOf(USER);
        uint256 recip2CurrBefore = erc20Mock.balanceOf(RECIPIENT_2);
        uint256[] memory wrapperBalBefore = getBalances(wrapperAddr, TOKEN_TYPES, erc1155);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
        uint256[] memory recip1BalBefore = getBalances(RECIPIENT_1, TOKEN_TYPES, erc1155);

        // Run it
        vm.prank(USER);
        wrapper.buyTokens(
            exchangeAddr,
            TOKEN_TYPES,
            tokens,
            totalPrice + refundAmount,
            block.timestamp,
            RECIPIENT_1, // token recipient
            RECIPIENT_2, // currency recipient
            NO_ADDRESSES,
            NO_FEES
        );

        // Check bals
        {
            uint256 wrapperCurrAfter = erc20Mock.balanceOf(wrapperAddr);
            uint256[] memory wrapperBalAfter = getBalances(wrapperAddr, TOKEN_TYPES, erc1155);
            assertEq(wrapperCurrAfter, wrapperCurrBefore);
            assertSame(wrapperBalBefore, wrapperBalAfter);
        }
        {
            uint256 exchangeCurrAfter = erc20Mock.balanceOf(exchangeAddr);
            uint256[] memory exchangeBalAfter = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
            assertEq(exchangeCurrAfter, exchangeCurrBefore + totalPrice); // Exchange currency rises
            assertBeforeAfterDiff(exchangeBalBefore, exchangeBalAfter, tokens, false); // Exchange tokens drops
        }
        {
            uint256 userCurrAfter = erc20Mock.balanceOf(USER);
            assertEq(userCurrAfter, userCurrBefore - totalPrice - refundAmount); // User currency drops
        }
        {
            uint256[] memory recip1BalAfter = getBalances(RECIPIENT_1, TOKEN_TYPES, erc1155);
            assertBeforeAfterDiff(recip1BalBefore, recip1BalAfter, tokens, true); // Recipient 1 gets tokens
        }
        {
            uint256 recip2CurrAfter = erc20Mock.balanceOf(RECIPIENT_2);
            assertEq(recip2CurrAfter, recip2CurrBefore + refundAmount); // Recipient 2 gets refund
        }
    }

    function test_buyTokens_happyPathRepeat(uint256 runs, uint256[] memory tokens, uint256 refundAmount) external {
        runs = _bound(runs, 1, 10);
        for (uint256 i; i < runs; i++) {
            test_buyTokens_happyPath(tokens, refundAmount);
        }
    }

    function test_buyTokens_invalidTokenRecipient(uint256[] memory tokens, uint256 refundAmount) external {
        vm.assume(tokens.length > 2);
        // Data
        assembly {
            // Set tokens to size 3
            mstore(tokens, 3)
        }
        for (uint256 i; i < 3; i++) {
            tokens[i] = _bound(tokens[i], 10, 1000);
        }
        uint256[] memory prices = IERC1155Exchange(exchangeAddr).getPrice_currencyToToken(TOKEN_TYPES, tokens);
        uint256 totalPrice = getTotal(prices);
        refundAmount = _bound(refundAmount, 0, 1 ether);

        // ERC-20
        withERC20(USER, totalPrice + refundAmount);

        // Run it
        vm.expectRevert(InvalidRecipient.selector);
        vm.prank(USER);
        wrapper.buyTokens(
            exchangeAddr,
            TOKEN_TYPES,
            tokens,
            totalPrice + refundAmount,
            block.timestamp,
            address(0), // token recipient
            RECIPIENT_2, // currency recipient
            NO_ADDRESSES,
            NO_FEES
        );
    }

    function test_buyTokens_invalidCurrencyRecipient(uint256[] memory tokens, uint256 refundAmount) external {
        vm.assume(tokens.length > 2);
        // Data
        assembly {
            // Set tokens to size 3
            mstore(tokens, 3)
        }
        for (uint256 i; i < 3; i++) {
            tokens[i] = _bound(tokens[i], 10, 1000);
        }
        uint256[] memory prices = IERC1155Exchange(exchangeAddr).getPrice_currencyToToken(TOKEN_TYPES, tokens);
        uint256 totalPrice = getTotal(prices);
        refundAmount = _bound(refundAmount, 0, 1 ether);

        // ERC-20
        withERC20(USER, totalPrice + refundAmount);

        // Run it
        vm.expectRevert(InvalidRecipient.selector);
        vm.prank(USER);
        wrapper.buyTokens(
            exchangeAddr,
            TOKEN_TYPES,
            tokens,
            totalPrice + refundAmount,
            block.timestamp,
            RECIPIENT_1, // token recipient
            address(0), // currency recipient
            NO_ADDRESSES,
            NO_FEES
        );
    }

    function test_buyTokens_invalidNiftyswapAddr(uint256[] memory tokens, uint256 refundAmount, address broken)
        external
    {
        vm.assume(broken != exchangeAddr);
        vm.assume(tokens.length > 2);
        // Data
        assembly {
            // Set tokens to size 3
            mstore(tokens, 3)
        }
        for (uint256 i; i < 3; i++) {
            tokens[i] = _bound(tokens[i], 10, 1000);
        }
        uint256[] memory prices = IERC1155Exchange(exchangeAddr).getPrice_currencyToToken(TOKEN_TYPES, tokens);
        uint256 totalPrice = getTotal(prices);
        refundAmount = _bound(refundAmount, 0, 1 ether);

        // ERC-20
        withERC20(USER, totalPrice + refundAmount);

        // Run it
        vm.expectRevert();
        vm.prank(USER);
        wrapper.buyTokens(
            broken,
            TOKEN_TYPES,
            tokens,
            totalPrice + refundAmount,
            block.timestamp,
            RECIPIENT_1, // token recipient
            RECIPIENT_2, // currency recipient
            NO_ADDRESSES,
            NO_FEES
        );
    }

    //
    // Helpers
    //

    function withERC20(address who, uint256 amount) internal {
        erc20Mock.mockMint(who, amount);
        vm.prank(who);
        erc20Mock.approve(wrapperAddr, amount);
    }
}
