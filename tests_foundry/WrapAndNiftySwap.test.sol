// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {WrapAndNiftyswap} from "src/contracts/utils/WrapAndNiftyswap.sol";
import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {ERC20WrapperMock} from "src/contracts/mocks/ERC20WrapperMock.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {NiftyswapTestHelper} from "./utils/NiftyswapTestHelper.test.sol";
import {console} from "forge-std/Test.sol";

// solhint-disable not-rely-on-time

contract WrapAndNiftySwapTest is NiftyswapTestHelper {
    // Events can't be imported
    event NewExchange(
        address indexed token, address indexed currency, uint256 indexed salt, uint256 lpFee, address exchange
    );

    uint256 private constant LP_FEE = 420;
    uint256 private constant CURRENCY_ID = 2;

    uint256[] private TOKEN_TYPES = [1, 2, 3];
    uint256[] private TOKENS_PER_TYPE = [500000, 500000, 500000];
    uint256[] private TOKENS_TO_SWAP = [50, 50, 50];

    // Liquidity
    uint256[] private CURRENCIES_PER_TYPE = [299 * 10e18, 299 * 10e18, 299 * 10e18];
    uint256[] private TOKEN_AMTS_TO_ADD = [300, 300, 300];

    uint256 private constant CURRENCY_AMT = 10000000 * 10e18;

    NiftyswapFactory private factory;
    WrapAndNiftyswap private swapper;
    INiftyswapExchange private exchange;
    address private exchangeAddr;
    address private erc20;
    ERC1155Mock private erc1155Mock;
    address private erc1155;
    address private erc20Wrapper;
    ERC20WrapperMock private erc20WrapperMock;

    function setUp() external {
        factory = new NiftyswapFactory();
        ERC20TokenMock erc20Mock = new ERC20TokenMock();
        erc20 = address(erc20Mock);
        erc1155Mock = new ERC1155Mock();
        erc1155 = address(erc1155Mock);
        erc20WrapperMock = new ERC20WrapperMock();
        erc20Wrapper = address(erc20WrapperMock);

        // Mint tokens
        erc20Mock.mockMint(OPERATOR, getTotal(CURRENCIES_PER_TYPE));
        erc20Mock.mockMint(USER, CURRENCY_AMT);
        erc1155Mock.batchMintMock(OPERATOR, TOKEN_TYPES, TOKENS_PER_TYPE, "");
        erc1155Mock.batchMintMock(USER, TOKEN_TYPES, TOKENS_PER_TYPE, "");

        // Wrap some
        vm.startPrank(OPERATOR);
        erc20Mock.approve(erc20Wrapper, type(uint256).max);
        erc20WrapperMock.deposit(erc20, OPERATOR, getTotal(CURRENCIES_PER_TYPE));
        vm.stopPrank();

        // Exchange and swapper
        factory.createExchange(erc1155, erc20Wrapper, CURRENCY_ID);
        exchangeAddr = factory.tokensToExchange(erc1155, erc20Wrapper, CURRENCY_ID);
        exchange = INiftyswapExchange(exchangeAddr);
        swapper = new WrapAndNiftyswap(payable(erc20Wrapper), exchangeAddr, erc20, erc1155);

        // Approvals
        vm.startPrank(OPERATOR);
        erc20WrapperMock.setApprovalForAll(exchangeAddr, true);
        erc1155Mock.setApprovalForAll(exchangeAddr, true);
        vm.stopPrank();
        vm.prank(USER);
        erc20Mock.approve(address(swapper), type(uint256).max);

        // Liquidity
        vm.prank(OPERATOR);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            TOKEN_TYPES,
            TOKEN_AMTS_TO_ADD,
            encodeAddLiquidity(CURRENCIES_PER_TYPE, block.timestamp)
        );
    }

    //
    // wrapAndSwap
    //
    function test_wrapAndSwap_happyPath() public {
        // Get balances
        uint256 exchangeCurrBefore = erc20WrapperMock.balanceOf(exchangeAddr, CURRENCY_ID);
        uint256 userCurrBefore = ERC20TokenMock(erc20).balanceOf(USER);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
        uint256[] memory userBalBefore = getBalances(USER, TOKEN_TYPES, erc1155);

        // Encode request
        bytes memory data = encodeBuyTokens(address(0), TOKEN_TYPES, TOKENS_TO_SWAP, block.timestamp);
        uint256[] memory costs = exchange.getPrice_currencyToToken(TOKEN_TYPES, TOKENS_TO_SWAP);
        uint256 total = getTotal(costs);

        // Make request
        vm.prank(USER);
        swapper.wrapAndSwap(total, USER, data);

        // Check balances
        uint256 currAfter = erc20WrapperMock.balanceOf(exchangeAddr, CURRENCY_ID);
        assertEq(currAfter, exchangeCurrBefore + total);
        currAfter = ERC20TokenMock(erc20).balanceOf(USER);
        assertEq(currAfter, userCurrBefore - total);
        uint256[] memory balAfter = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, TOKENS_TO_SWAP, false);
        balAfter = getBalances(USER, TOKEN_TYPES, erc1155);
        assertBeforeAfterDiff(userBalBefore, balAfter, TOKENS_TO_SWAP, true);
    }

    function test_wrapAndSwap_happyPathX2() external {
        test_wrapAndSwap_happyPath();
        test_wrapAndSwap_happyPath();
    }

    function test_wrapAndSwap_badRecipient() external {
        bytes memory data = encodeBuyTokens(USER, TOKEN_TYPES, TOKENS_TO_SWAP, block.timestamp);
        uint256[] memory costs = exchange.getPrice_currencyToToken(TOKEN_TYPES, TOKENS_TO_SWAP);
        uint256 total = getTotal(costs);

        vm.expectRevert("WrapAndNiftyswap#wrapAndSwap: ORDER RECIPIENT MUST BE THIS CONTRACT");
        swapper.wrapAndSwap(total, USER, data);
    }

    //
    // swapAndUnwrap
    //
    function test_swapAndUnwrap_happyPath() public {
        // Get balances
        uint256 exchangeCurrBefore = erc20WrapperMock.balanceOf(exchangeAddr, CURRENCY_ID);
        uint256 userCurrBefore = ERC20TokenMock(erc20).balanceOf(USER);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
        uint256[] memory userBalBefore = getBalances(USER, TOKEN_TYPES, erc1155);

        // Encode request
        uint256[] memory costs = exchange.getPrice_tokenToCurrency(TOKEN_TYPES, TOKENS_TO_SWAP);
        uint256 total = getTotal(costs);
        bytes memory data = encodeSellTokens(address(0), total, block.timestamp);

        // Make request
        vm.prank(USER);
        erc1155Mock.safeBatchTransferFrom(USER, address(swapper), TOKEN_TYPES, TOKENS_TO_SWAP, data);

        // Check balances
        uint256 currAfter = erc20WrapperMock.balanceOf(exchangeAddr, CURRENCY_ID);
        assertEq(currAfter, exchangeCurrBefore - total);
        currAfter = ERC20TokenMock(erc20).balanceOf(USER);
        assertEq(currAfter, userCurrBefore + total);
        uint256[] memory balAfter = getBalances(exchangeAddr, TOKEN_TYPES, erc1155);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, TOKENS_TO_SWAP, true);
        balAfter = getBalances(USER, TOKEN_TYPES, erc1155);
        assertBeforeAfterDiff(userBalBefore, balAfter, TOKENS_TO_SWAP, false);
    }

    function test_swapAndUnwrap_happyPathX2() external {
        test_swapAndUnwrap_happyPath();
        test_swapAndUnwrap_happyPath();
    }

    function test_swapAndUnwrap_badRecipient() external {
        uint256[] memory costs = exchange.getPrice_tokenToCurrency(TOKEN_TYPES, TOKENS_TO_SWAP);
        uint256 total = getTotal(costs);
        bytes memory data = encodeSellTokens(USER, total, block.timestamp);

        // Make request
        vm.prank(USER);
        vm.expectRevert("WrapAndNiftyswap#onERC1155BatchReceived: ORDER RECIPIENT MUST BE THIS CONTRACT");
        erc1155Mock.safeBatchTransferFrom(USER, address(swapper), TOKEN_TYPES, TOKENS_TO_SWAP, data);
    }

    //
    // Helpers
    //

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
