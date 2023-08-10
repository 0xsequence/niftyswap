// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapOrderbook} from "src/contracts/orderbook/NiftyswapOrderbook.sol";
import {
    INiftyswapOrderbookSignals, INiftyswapOrderbookStorage
} from "src/contracts/interfaces/INiftyswapOrderbook.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";

import {Test, console} from "forge-std/Test.sol";

// solhint-disable not-rely-on-time

contract NiftyswapOrderbookTest is INiftyswapOrderbookSignals, INiftyswapOrderbookStorage, Test {
    NiftyswapOrderbook private orderbook;
    ERC1155Mock private erc1155;
    ERC20TokenMock private erc20;

    uint256 private constant TOKEN_ID = 1;
    uint256 private constant TOKEN_QUANTITY = 100;
    uint256 private constant CURRENCY_QUANTITY = 10 ether;

    address private constant USER = address(uint160(uint256(keccak256("user"))));
    address private constant PURCHASER = address(uint160(uint256(keccak256("purchaser"))));

    function setUp() external {
        orderbook = new NiftyswapOrderbook();
        erc1155 = new ERC1155Mock();
        erc20 = new ERC20TokenMock();

        vm.label(USER, "user");
        vm.label(PURCHASER, "purchaser");

        // Mint tokens
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        uint256[] memory quantities = new uint256[](1);
        quantities[0] = TOKEN_QUANTITY;
        erc1155.batchMintMock(USER, tokenIds, quantities, "");

        erc20.mockMint(PURCHASER, CURRENCY_QUANTITY);

        vm.deal(PURCHASER, CURRENCY_QUANTITY * TOKEN_QUANTITY);

        // Approvals
        vm.prank(USER);
        erc1155.setApprovalForAll(address(orderbook), true);
        vm.prank(PURCHASER);
        erc20.approve(address(orderbook), CURRENCY_QUANTITY);
    }

    //
    // Create
    //

    // This is tested and fuzzed through internal calls
    function test_createListing(uint256 quantity, uint256 pricePerToken, uint256 expiry) internal {
        vm.assume(quantity > 0 && quantity <= erc1155.balanceOf(USER, TOKEN_ID));
        vm.assume(expiry > block.timestamp);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCreated(0, address(erc1155), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);
        vm.prank(USER);
        uint256 listingId =
            orderbook.createListing(address(erc1155), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);

        Listing memory listing = orderbook.getListing(listingId);
        assertEq(listing.creator, USER);
        assertEq(listing.tokenContract, address(erc1155));
        assertEq(listing.tokenId, TOKEN_ID);
        assertEq(listing.quantity, quantity);
        assertEq(listing.currency, address(erc20));
        assertEq(listing.pricePerToken, pricePerToken);
        assertEq(listing.expiresAt, expiry);
    }

    //
    // Accept
    //
    function test_acceptListing(uint256 quantity, uint256 pricePerToken, uint256 expiry) public {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);

        test_createListing(quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(0, PURCHASER, quantity);
        vm.prank(PURCHASER);
        orderbook.acceptListing(0, quantity);

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice);
    }

    function test_acceptListing_invalidQuantity_zero(uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        test_createListing(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(0, 0);
    }

    function test_acceptListing_invalidQuantity_tooHigh(uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        test_createListing(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(0, quantity + 1);
    }

    function test_acceptListing_twice(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        quantity = quantity / 2 * 2; // Cater for rounding error
        vm.assume(pricePerToken <= 1 ether && quantity > 1 && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);

        test_createListing(quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(0, PURCHASER, quantity / 2);
        vm.startPrank(PURCHASER);
        orderbook.acceptListing(0, quantity / 2);
        orderbook.acceptListing(0, quantity / 2);
        vm.stopPrank();

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice);
    }

    function test_acceptListing_twice_overQuantity(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        test_acceptListing(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, 0));
        orderbook.acceptListing(0, 1);
    }

    function test_acceptListing_noFunds(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        vm.assume(pricePerToken <= (type(uint256).max / TOKEN_QUANTITY) && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice > erc20BalPurchaser);

        test_createListing(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        orderbook.acceptListing(0, quantity);
    }

    //
    // Cancel
    //
    function test_cancelListing(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        test_createListing(quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCancelled(0);
        vm.prank(USER);
        orderbook.cancelListing(0);

        Listing memory listing = orderbook.getListing(0);
        // Zero'd
        assertEq(listing.creator, address(0));
        assertEq(listing.tokenContract, address(0));
        assertEq(listing.tokenId, 0);
        assertEq(listing.quantity, 0);
        assertEq(listing.currency, address(0));
        assertEq(listing.pricePerToken, 0);
        assertEq(listing.expiresAt, 0);

        // Accept fails
        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, 0));
        orderbook.acceptListing(0, 1);
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
