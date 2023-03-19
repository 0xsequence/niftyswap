// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {INiftyswapExchange} from "src/contracts/interfaces/INiftyswapExchange.sol";
import {NiftyswapFactory} from "src/contracts/exchange/NiftyswapFactory.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";

import {TestHelper} from "./utils/TestHelper.test.sol";
import {Vm, console} from "forge-std/Test.sol";

contract NiftyswapExchangeTest is TestHelper {
    // Events can't be imported
    event NewExchange(address indexed token, address indexed currency, uint256 indexed currencyID, address exchange);

    uint256 private constant CURRENCY_ID = 42069;

    uint256[] private TOKEN_TYPES = [1, 2, 3];
    uint256[] private TOKENS_PER_TYPE = [500000, 500000, 500000];

    // Liquidity
    uint256[] private CURRENCIES_PER_TYPE = [299 * 10e18, 299 * 10e18, 299 * 10e18];
    uint256[] private TOKEN_AMTS_TO_ADD = [300, 300, 300];
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
    // Liquidity
    //
    function test_addLiquidity_happyPath() public {
        vm.prank(OPERATOR);
        erc1155AMock.safeBatchTransferFrom(
            OPERATOR,
            exchangeAddr,
            TOKEN_TYPES,
            TOKEN_AMTS_TO_ADD,
            encodeAddLiquidity(CURRENCIES_PER_TYPE, block.timestamp)
        );

        // FIXME Balance checks
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
