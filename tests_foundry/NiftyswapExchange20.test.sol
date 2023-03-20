// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {INiftyswapExchange20} from "src/contracts/interfaces/INiftyswapExchange20.sol";
import {NiftyswapFactory20} from "src/contracts/exchange/NiftyswapFactory20.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";

import {Niftyswap20TestHelper} from "./utils/Niftyswap20TestHelper.test.sol";
import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

interface IERC1155Exchange is INiftyswapExchange20, IERC1155 {}

contract NiftyswapExchange20Test is Niftyswap20TestHelper {
    // Events can't be imported
    // INiftyswapExchange20
    event LiquidityAdded(
        address indexed provider, uint256[] tokenIds, uint256[] tokenAmounts, uint256[] currencyAmounts
    );

    uint256 private constant LP_FEE = 100;
    uint256 private constant INSTANCE_ID = 69;

    uint256[] private TOKEN_TYPES = [1, 2, 3];
    uint256[] private TOKENS_PER_TYPE = [500000, 500000, 500000];

    // Liquidity
    uint256[] private CURRENCIES_PER_TYPE = [299 * 10e18, 299 * 10e18, 299 * 10e18];
    uint256 private constant CURRENCY_AMT = 10000000 * 10e18;
    uint256[] private TOKEN_AMTS_TO_ADD = [300, 300, 300];

    // Fees
    address[] private NO_ADDRESSES;
    uint256[] private NO_FEES;

    NiftyswapFactory20 private factory;
    IERC1155Exchange private exchange;
    address private exchangeAddr;
    ERC1155Mock private erc1155Mock; // Token
    ERC20TokenMock private erc20Mock; // Currency
    address private erc1155;
    address private erc20;

    function setUp() external {
        factory = new NiftyswapFactory20(address(this));
        erc1155Mock = new ERC1155Mock();
        erc1155 = address(erc1155Mock);
        erc20Mock = new ERC20TokenMock();
        erc20 = address(erc20Mock);

        factory.createExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);
        exchangeAddr = factory.tokensToExchange(erc1155, erc20, LP_FEE, INSTANCE_ID);
        exchange = IERC1155Exchange(exchangeAddr);

        // Mint tokens
        erc1155Mock.batchMintMock(OPERATOR, TOKEN_TYPES, TOKENS_PER_TYPE, "");
        erc1155Mock.batchMintMock(USER, TOKEN_TYPES, TOKENS_PER_TYPE, "");
        erc20Mock.mockMint(OPERATOR, CURRENCY_AMT);
        erc20Mock.mockMint(USER, CURRENCY_AMT);

        // Approvals
        vm.startPrank(OPERATOR);
        erc1155Mock.setApprovalForAll(exchangeAddr, true);
        erc20Mock.approve(exchangeAddr, CURRENCY_AMT);
        vm.stopPrank();
        vm.startPrank(USER);
        erc1155Mock.setApprovalForAll(exchangeAddr, true);
        erc20Mock.approve(exchangeAddr, CURRENCY_AMT);
        vm.stopPrank();
    }

    //
    // View
    //
    function test_getFactoryAddress() external {
        assertEq(address(factory), exchange.getFactoryAddress());
    }

    function test_supportsInterface() external {
        IERC165 exc = IERC165(exchangeAddr);
        assertTrue(exc.supportsInterface(type(IERC165).interfaceId), "IERC165 support");
        assertTrue(exc.supportsInterface(type(IERC1155).interfaceId), "IERC1155 support");
        assertTrue(exc.supportsInterface(type(IERC1155TokenReceiver).interfaceId), "IERC1155Receiver support");
    }

    //
    // Pricing
    //
    function test_getBuyPrice_roundsUp() external {
        uint256 boughtAmount = 100;
        uint256 sellReserve = 1500;
        uint256 buyReserve = 751;

        // (boughtAmount * sellReserves * 1000) / ((buyReserve - boughtAmount) * (1000 - 100))

        uint256 price = exchange.getBuyPrice(boughtAmount, sellReserve, buyReserve);
        assertEq(uint256(257), price); // instead of 256.0163850486431
    }

    function test_getSellPrice_roundsDown() external {
        uint256 soldAmount = 100;
        uint256 buyReserve = 1500;
        uint256 sellReserve = 751;

        // (soldAmount * (1000 - 100) * buyReserve) / ((sellReserve * 1000) + (soldAmount * (1000 - 100)))

        uint256 price = exchange.getSellPrice(soldAmount, sellReserve, buyReserve);
        assertEq(uint256(160), price); // instead of 160.52318668252082
    }

    //
    // Add liquidity
    //
    function test_addLiquidity_happyPath() public {
        // Data
        uint256 currAmount = 1000000001;
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = currAmount;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 2;

        // Before bals
        uint256 exchangeCurrBefore = erc20Mock.balanceOf(exchangeAddr);
        uint256 operCurrBefore = erc20Mock.balanceOf(OPERATOR);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, types, erc1155);
        uint256[] memory operBalBefore = getBalances(OPERATOR, types, erc1155);
        uint256[] memory operLiquidityBefore = getBalances(OPERATOR, types, exchangeAddr);

        // Send it
        vm.expectEmit(true, true, true, true, exchangeAddr);
        emit LiquidityAdded(OPERATOR, types, tokensToAdd, currencyToAdd);
        vm.prank(OPERATOR);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );

        // Check balances
        uint256 currAfter = erc20Mock.balanceOf(exchangeAddr);
        assertEq(currAfter, exchangeCurrBefore + currAmount);
        currAfter = erc20Mock.balanceOf(OPERATOR);
        assertEq(currAfter, operCurrBefore - currAmount);
        uint256[] memory balAfter = getBalances(exchangeAddr, types, erc1155);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, tokensToAdd, true);
        balAfter = getBalances(OPERATOR, types, erc1155);
        assertBeforeAfterDiff(operBalBefore, balAfter, tokensToAdd, false);
        balAfter = getBalances(OPERATOR, types, exchangeAddr);
        assertBeforeAfterDiff(operLiquidityBefore, balAfter, currencyToAdd, true);
    }

    function test_addLiquidity_secondDepRounding() external {
        test_addLiquidity_happyPath();

        // Data
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 1000000001;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 1;

        uint256[] memory ones = new uint256[](1);
        ones[0] = 1;

        // Before data
        uint256[] memory buyBefore = exchange.getPrice_currencyToToken(types, ones);
        uint256[] memory sellBefore = exchange.getPrice_tokenToCurrency(types, ones);

        // Add liq
        vm.prank(OPERATOR);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );

        // Reserves rounds up
        uint256[] memory actual = exchange.getCurrencyReserves(types);
        assertEq(uint256(1500000002), actual[0]); // Should be 1500000001.5
        // Liquidity rounds down
        actual = exchange.getTotalSupply(types);
        assertEq(uint256(1500000001), actual[0]); // Should be 1500000001.5
        // Buy price decreases
        actual = exchange.getPrice_currencyToToken(types, ones);
        assertLt(actual[0], buyBefore[0]);
        // Sell price increases
        actual = exchange.getPrice_tokenToCurrency(types, ones);
        assertGt(actual[0], sellBefore[0]);
    }

    function test_addLiquidity_deadlinePassed() external {
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 1000000001;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 2;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#10");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp - 1)
        );
    }

    function test_addLiquidity_zeroMaxCurrency() external {
        uint256[] memory currencyToAdd = new uint256[](2);
        currencyToAdd[0] = 1000000001;
        // Implicit: currencyToAdd[1] = 0;
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 2;
        uint256[] memory tokensToAdd = new uint256[](2);
        tokensToAdd[0] = 2;
        tokensToAdd[1] = 2;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#11");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    function test_addLiquidity_zeroTokenAmount() external {
        uint256[] memory currencyToAdd = new uint256[](2);
        currencyToAdd[0] = 1000000001;
        currencyToAdd[1] = 1000000001;
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 2;
        uint256[] memory tokensToAdd = new uint256[](2);
        tokensToAdd[0] = 2;
        // Implicit: tokensToAdd[1] = 0;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#12");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    function test_addLiquidity_badArrayLengths() external {
        uint256[] memory currencies1 = new uint256[](1);
        currencies1[0] = 1000000001;
        uint256[] memory currencies2 = new uint256[](2);
        currencies2[0] = 1000000001;
        currencies2[1] = 1000000001;
        uint256[] memory types1 = new uint256[](1);
        types1[0] = 1;
        uint256[] memory types2 = new uint256[](2);
        types2[0] = 1;
        types2[1] = 2;
        uint256[] memory tokens1 = new uint256[](1);
        tokens1[0] = 2;
        uint256[] memory tokens2 = new uint256[](2);
        tokens2[0] = 2;
        tokens2[1] = 2;

        vm.startPrank(OPERATOR);
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types1, tokens2, encodeAddLiquidity(currencies2, block.timestamp)
        );
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types2, tokens1, encodeAddLiquidity(currencies2, block.timestamp)
        );
        vm.expectRevert(stdError.indexOOBError);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types2, tokens2, encodeAddLiquidity(currencies1, block.timestamp)
        );
        vm.stopPrank();
    }

    function test_addLiquidity_duplicateTokens() external {
        uint256[] memory currencyToAdd = new uint256[](2);
        currencyToAdd[0] = 1000000001;
        currencyToAdd[1] = 1000000001;
        uint256[] memory types = new uint256[](2);
        types[0] = 2;
        types[1] = 2; // Same type id
        uint256[] memory tokensToAdd = new uint256[](2);
        tokensToAdd[0] = 2;
        tokensToAdd[1] = 2;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#32");
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    //TODO Max currency exceeded

    //
    // Remove liquidity
    //
    function test_removeLiquidity_noLiquidity() external {
        uint256[] memory currencies = new uint256[](1);
        currencies[0] = 1000000001;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 2;

        vm.prank(OPERATOR);
        vm.expectRevert(stdError.arithmeticError);
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokens, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );
    }

    function test_removeLiquidity_zeroRemoveLiquidity() external {
        uint256[] memory currencies = new uint256[](1);
        currencies[0] = 1000000001;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory liquidity = new uint256[](1);
        //Implicit: liquidity[0] = 0;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 1;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#16");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, liquidity, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );
    }

    function test_removeLiquidity_happyPath() external withLiquidity {
        uint256 typeId = 1;
        uint256[] memory currencies = new uint256[](1);
        currencies[0] = 1;
        uint256[] memory types = new uint256[](1);
        types[0] = typeId;
        uint256[] memory liquidity = new uint256[](1);
        liquidity[0] = exchange.balanceOf(OPERATOR, typeId);
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 1;

        vm.prank(OPERATOR);
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, liquidity, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );

        //TODO Check balances
    }

    function test_removeLiquidity_insufficientCurrency() external withLiquidity {
        uint256[] memory currencies = new uint256[](1);
        currencies[0] = 1000000002; // Too much
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 75;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#17");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokens, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );
    }

    function test_removeLiquidity_insufficientTokens() external withLiquidity {
        uint256[] memory currencies = new uint256[](1);
        currencies[0] = 10;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 3000; // Too much

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#18");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokens, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );
    }

    function test_removeLiquidity_duplicateIds() external withLiquidity {
        uint256[] memory currencies = new uint256[](2);
        currencies[0] = 10;
        currencies[1] = 10;
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1; // Same
        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 10;
        tokens[0] = 10;

        vm.prank(OPERATOR);
        vm.expectRevert("NE20#32");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokens, encodeRemoveLiquidity(currencies, tokens, block.timestamp)
        );
    }

    function test_removeLiquidity_badLengths() external withLiquidity {
        uint256[] memory currencies1 = new uint256[](1);
        currencies1[0] = 1000000001;
        uint256[] memory currencies2 = new uint256[](2);
        currencies2[0] = 1000000001;
        currencies2[1] = 1000000001;
        uint256[] memory types1 = new uint256[](1);
        types1[0] = 1;
        uint256[] memory types2 = new uint256[](2);
        types2[0] = 1;
        types2[1] = 2;
        uint256[] memory tokens1 = new uint256[](1);
        tokens1[0] = 2;
        uint256[] memory tokens2 = new uint256[](2);
        tokens2[0] = 2;
        tokens2[1] = 2;

        vm.startPrank(OPERATOR);
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types1, tokens2, encodeRemoveLiquidity(currencies2, tokens2, block.timestamp)
        );
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        exchange.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types2, tokens1, encodeRemoveLiquidity(currencies2, tokens2, block.timestamp)
        );
        vm.stopPrank();
    }

    //
    // Sell
    //
    function test_tokenToCurrency_happyPath() external withLiquidity {
        // Data
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 10;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);

        // Before bals
        uint256 exchangeCurrBefore = erc20Mock.balanceOf(exchangeAddr);
        uint256 userCurrBefore = erc20Mock.balanceOf(USER);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, types, erc1155);
        uint256[] memory userBalBefore = getBalances(USER, types, erc1155);

        // Run it
        vm.prank(USER);
        //TODO Check emit
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp)
        );

        // Check balances
        uint256 currAfter = erc20Mock.balanceOf(exchangeAddr);
        assertEq(currAfter, exchangeCurrBefore - prices[0]);
        currAfter = erc20Mock.balanceOf(USER);
        assertEq(currAfter, userCurrBefore + prices[0]);
        uint256[] memory balAfter = getBalances(exchangeAddr, types, erc1155);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, sellAmounts, true);
        balAfter = getBalances(USER, types, erc1155);
        assertBeforeAfterDiff(userBalBefore, balAfter, sellAmounts, false);
    }

    function test_tokenToCurrency_zeroTokens() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 0;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);

        vm.prank(USER);
        vm.expectRevert("NE20#7");
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp)
        );
    }

    function test_tokenToCurrency_notEnoughTokens() external withLiquidity {
        uint256 typeId = 1;
        uint256 bal = erc1155Mock.balanceOf(USER, typeId);
        uint256[] memory types = new uint256[](1);
        types[0] = typeId;
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = bal + 1;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp)
        );
    }

    function test_tokenToCurrency_pastDeadline() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 10;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);

        vm.prank(USER);
        vm.expectRevert("NE20#6");
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp - 1)
        );
    }

    function test_tokenToCurrency_costTooHigh() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory sellAmounts = new uint256[](1);
        sellAmounts[0] = 10;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);
        prices[0] += 1; // Too high

        vm.prank(USER);
        vm.expectRevert("NE20#8");
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp)
        );
    }

    function test_tokenToCurrency_duplicateIds() external withLiquidity {
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1; //Same
        uint256[] memory sellAmounts = new uint256[](2);
        sellAmounts[0] = 10;
        sellAmounts[1] = 10;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types, sellAmounts);

        vm.prank(USER);
        vm.expectRevert("NE20#32");
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types,
            sellAmounts,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp)
        );
    }

    function test_tokenToCurrency_badArrayLengths() external withLiquidity {
        uint256[] memory sellAmounts1 = new uint256[](1);
        sellAmounts1[0] = 10;
        uint256[] memory sellAmounts2 = new uint256[](2);
        sellAmounts2[0] = 10;
        sellAmounts2[1] = 10;
        uint256[] memory types1 = new uint256[](1);
        types1[0] = 1;
        uint256[] memory prices = exchange.getPrice_tokenToCurrency(types1, sellAmounts1);

        vm.startPrank(USER);
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        erc1155Mock.safeBatchTransferFrom(
            USER,
            exchangeAddr,
            types1,
            sellAmounts2,
            encodeSellTokens(USER, prices[0], NO_ADDRESSES, NO_FEES, block.timestamp - 1)
        );
        vm.stopPrank();
    }

    //TODO Royalties

    //
    // Buy
    //
    function test_currencyToToken_happyPath() external withLiquidity {
        // Data
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 10;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);

        // Before bals
        uint256 exchangeCurrBefore = erc20Mock.balanceOf(exchangeAddr);
        uint256 userCurrBefore = erc20Mock.balanceOf(USER);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, types, erc1155);
        uint256[] memory userBalBefore = getBalances(USER, types, erc1155);

        // Run it
        vm.prank(USER);
        //TODO Check emit
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp, USER, NO_ADDRESSES, NO_FEES);

        // Check balances
        uint256 currAfter = erc20Mock.balanceOf(exchangeAddr);
        assertEq(currAfter, exchangeCurrBefore + prices[0]);
        currAfter = erc20Mock.balanceOf(USER);
        assertEq(currAfter, userCurrBefore - prices[0]);
        uint256[] memory balAfter = getBalances(exchangeAddr, types, erc1155);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, tokens, false);
        balAfter = getBalances(USER, types, erc1155);
        assertBeforeAfterDiff(userBalBefore, balAfter, tokens, true);
    }

    function test_currencyToToken_zeroTokens() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 0;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);

        vm.prank(USER);
        vm.expectRevert("NE20#4");
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp, USER, NO_ADDRESSES, NO_FEES);
    }

    function test_currencyToToken_notEnoughTokens() external withLiquidity {
        uint256 typeId = 1;
        uint256 bal = erc20Mock.balanceOf(USER);
        uint256[] memory types = new uint256[](1);
        types[0] = typeId;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 10;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);
        tokens[0] = bal + 1;

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp, USER, NO_ADDRESSES, NO_FEES);
    }

    function test_currencyToToken_pastDeadline() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 10;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);

        vm.prank(USER);
        vm.expectRevert("NE20#19");
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp - 1, USER, NO_ADDRESSES, NO_FEES);
    }

    function test_currencyToToken_costTooLow() external withLiquidity {
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokens = new uint256[](1);
        tokens[0] = 10;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);
        prices[0] -= 1; // Too low

        vm.prank(USER);
        vm.expectRevert(stdError.arithmeticError);
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp, USER, NO_ADDRESSES, NO_FEES);
    }

    function test_currencyToToken_duplicateIds() external withLiquidity {
        uint256[] memory types = new uint256[](2);
        types[0] = 1;
        types[1] = 1; //Same
        uint256[] memory tokens = new uint256[](2);
        tokens[0] = 10;
        tokens[1] = 10;
        uint256[] memory prices = exchange.getPrice_currencyToToken(types, tokens);

        vm.prank(USER);
        vm.expectRevert("NE20#32");
        exchange.buyTokens(types, tokens, getTotal(prices), block.timestamp, USER, NO_ADDRESSES, NO_FEES);
    }

    //TODO Bad lengths

    //TODO Edge cases

    //
    // Helpers
    //
    modifier withLiquidity() {
        vm.prank(OPERATOR);
        erc1155Mock.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            TOKEN_TYPES,
            TOKEN_AMTS_TO_ADD,
            encodeAddLiquidity(CURRENCIES_PER_TYPE, block.timestamp)
        );
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
