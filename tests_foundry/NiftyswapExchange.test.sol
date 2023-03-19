// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {TestHelper} from "./utils/TestHelper.test.sol";
import {console} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";

contract NiftyswapExchangeTest is TestHelper {
    // Events can't be imported
    // IERC1155
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );
    // INiftyswapExchange
    event LiquidityAdded(
        address indexed provider, uint256[] tokenIds, uint256[] tokenAmounts, uint256[] currencyAmounts
    );

    uint256 private constant CURRENCY_ID = 42069;

    uint256[] private TOKEN_TYPES = [1, 2, 3];
    uint256[] private TOKENS_PER_TYPE = [500000, 500000, 500000];

    // Liquidity
    uint256[] private CURRENCIES_PER_TYPE = [299 * 10e18, 299 * 10e18, 299 * 10e18];
    uint256[] private TOKEN_AMTSToAdd = [300, 300, 300];
    uint256 private constant CURRENCY_AMT = 10000000 * 10e18;

    NiftyswapFactory private factory;
    INiftyswapExchange private exchange;
    address private exchangeAddr;
    ERC1155Mock private erc1155AMock; // Token
    ERC1155Mock private erc1155BMock; // Currency
    address private erc1155A;
    address private erc1155B;

    function setUp() external {
        factory = new NiftyswapFactory();
        erc1155AMock = new ERC1155Mock();
        erc1155A = address(erc1155AMock);
        erc1155BMock = new ERC1155Mock();
        erc1155B = address(erc1155BMock);

        factory.createExchange(erc1155A, erc1155B, CURRENCY_ID);
        exchangeAddr = factory.tokensToExchange(erc1155A, erc1155B, CURRENCY_ID);
        exchange = INiftyswapExchange(exchangeAddr);

        // Mint tokens
        erc1155AMock.batchMintMock(OPERATOR, TOKEN_TYPES, CURRENCIES_PER_TYPE, "");
        erc1155AMock.batchMintMock(USER, TOKEN_TYPES, CURRENCIES_PER_TYPE, "");
        erc1155BMock.mintMock(OPERATOR, CURRENCY_ID, CURRENCY_AMT, "");
        erc1155BMock.mintMock(USER, CURRENCY_ID, CURRENCY_AMT, "");

        // Approvals
        vm.startPrank(OPERATOR);
        erc1155AMock.setApprovalForAll(exchangeAddr, true);
        erc1155BMock.setApprovalForAll(exchangeAddr, true);
        vm.stopPrank();
        vm.startPrank(USER);
        erc1155AMock.setApprovalForAll(exchangeAddr, true);
        erc1155BMock.setApprovalForAll(exchangeAddr, true);
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
        uint256 numerator = 1500;
        uint256 denominator = 751;
        uint256 price = exchange.getBuyPrice(boughtAmount, numerator, denominator);
        assertEq(uint256(232), price); // instead of 231.5726095917375
    }

    function test_getSellPrice_roundsDown() external {
        uint256 boughtAmount = 100;
        uint256 numerator = 1500;
        uint256 denominator = 751;
        uint256 price = exchange.getSellPrice(boughtAmount, denominator, numerator);
        assertEq(uint256(175), price); // instead of 175.48500881834215
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
        uint256 exchangeCurrBefore = erc1155BMock.balanceOf(exchangeAddr, CURRENCY_ID);
        uint256 operCurrBefore = erc1155BMock.balanceOf(OPERATOR, CURRENCY_ID);
        uint256[] memory exchangeBalBefore = getBalances(exchangeAddr, types, erc1155A);
        uint256[] memory operBalBefore = getBalances(OPERATOR, types, erc1155A);
        uint256[] memory operLiquidityBefore = getBalances(OPERATOR, types, exchangeAddr);

        // Send it
        vm.expectEmit(true, true, true, true, exchangeAddr);
        emit TransferBatch(erc1155A, address(0), OPERATOR, types, currencyToAdd);
        vm.expectEmit(true, true, true, true);
        emit TransferSingle(exchangeAddr, OPERATOR, exchangeAddr, CURRENCY_ID, currAmount);
        vm.expectEmit(true, true, true, true, exchangeAddr);
        emit LiquidityAdded(OPERATOR, types, tokensToAdd, currencyToAdd);
        vm.prank(OPERATOR);
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );

        // Check balances
        uint256 currAfter = erc1155BMock.balanceOf(exchangeAddr, CURRENCY_ID);
        assertEq(currAfter, exchangeCurrBefore + currAmount);
        currAfter = erc1155BMock.balanceOf(OPERATOR, CURRENCY_ID);
        assertEq(currAfter, operCurrBefore - currAmount);
        uint256[] memory balAfter = getBalances(exchangeAddr, types, erc1155A);
        assertBeforeAfterDiff(exchangeBalBefore, balAfter, tokensToAdd, true);
        balAfter = getBalances(OPERATOR, types, erc1155A);
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
        erc1155AMock.safeBatchTransferFrom(
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

    function test_addLiquidity_wrongContract() external {
        factory.createExchange(erc1155B, erc1155B, 1);
        address excAddr = factory.tokensToExchange(erc1155B, erc1155B, 1);

        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 1;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 1;

        vm.prank(OPERATOR);
        vm.expectRevert("NiftyswapExchange#onERC1155BatchReceived: INVALID_TOKEN_TRANSFERRED");
        // Using contract A instead of B
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR, excAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    function test_addLiquidity_noCurrencyCurrencyPool() external {
        // Create exchange across same contract
        factory.createExchange(erc1155B, erc1155B, CURRENCY_ID);
        address excAddr = factory.tokensToExchange(erc1155B, erc1155B, CURRENCY_ID);

        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 300;
        uint256[] memory types = new uint256[](1);
        types[0] = CURRENCY_ID;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 300;

        // Provide liq for currency / currency
        vm.prank(OPERATOR);
        vm.expectRevert("NiftyswapExchange#_addLiquidity: CURRENCY_POOL_FORBIDDEN");
        erc1155BMock.safeBatchTransferFrom(
            OPERATOR, excAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    function test_addLiquidity_deadlinePassed() external {
        uint256[] memory currencyToAdd = new uint256[](1);
        currencyToAdd[0] = 1000000001;
        uint256[] memory types = new uint256[](1);
        types[0] = 1;
        uint256[] memory tokensToAdd = new uint256[](1);
        tokensToAdd[0] = 2;

        vm.prank(OPERATOR);
        vm.expectRevert("NiftyswapExchange#_addLiquidity: DEADLINE_EXCEEDED");
        erc1155AMock.safeBatchTransferFrom(
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
        vm.expectRevert("NiftyswapExchange#_addLiquidity: NULL_MAX_CURRENCY");
        erc1155AMock.safeBatchTransferFrom(
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
        vm.expectRevert("NiftyswapExchange#_addLiquidity: NULL_TOKENS_AMOUNT");
        erc1155AMock.safeBatchTransferFrom(
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
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types1, tokens2, encodeAddLiquidity(currencies2, block.timestamp)
        );
        vm.expectRevert("ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types2, tokens1, encodeAddLiquidity(currencies2, block.timestamp)
        );
        vm.expectRevert(stdError.indexOOBError);
        erc1155AMock.safeBatchTransferFrom(
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
        vm.expectRevert("NiftyswapExchange#_getTokenReserves: UNSORTED_OR_DUPLICATE_TOKEN_IDS");
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR, exchangeAddr, types, tokensToAdd, encodeAddLiquidity(currencyToAdd, block.timestamp)
        );
    }

    //TODO Max currency exceeded

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
