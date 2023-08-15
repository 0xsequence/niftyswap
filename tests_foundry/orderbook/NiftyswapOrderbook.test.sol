// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapOrderbook} from "src/contracts/orderbook/NiftyswapOrderbook.sol";
import {
    INiftyswapOrderbookSignals, INiftyswapOrderbookStorage
} from "src/contracts/interfaces/INiftyswapOrderbook.sol";
import {ERC1155Mock} from "src/contracts/mocks/ERC1155Mock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {ERC721Mock} from "src/contracts/mocks/ERC721Mock.sol";

import {Test, console} from "forge-std/Test.sol";

// solhint-disable not-rely-on-time

contract NiftyswapOrderbookTest is INiftyswapOrderbookSignals, INiftyswapOrderbookStorage, Test {
    NiftyswapOrderbook private orderbook;
    ERC1155Mock private erc1155;
    ERC721Mock private erc721;
    ERC20TokenMock private erc20;

    uint256 private constant TOKEN_ID = 1;
    uint256 private constant TOKEN_QUANTITY = 100;
    uint256 private constant CURRENCY_QUANTITY = 10 ether;

    address private constant USER = address(uint160(uint256(keccak256("user"))));
    address private constant PURCHASER = address(uint160(uint256(keccak256("purchaser"))));

    function setUp() external {
        orderbook = new NiftyswapOrderbook();
        erc1155 = new ERC1155Mock();
        erc721 = new ERC721Mock();
        erc20 = new ERC20TokenMock();

        vm.label(USER, "user");
        vm.label(PURCHASER, "purchaser");

        // Mint tokens
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        uint256[] memory quantities = new uint256[](1);
        quantities[0] = TOKEN_QUANTITY;
        erc1155.batchMintMock(USER, tokenIds, quantities, "");

        erc721.mintMock(USER, TOKEN_QUANTITY);

        erc20.mockMint(PURCHASER, CURRENCY_QUANTITY);

        vm.deal(PURCHASER, CURRENCY_QUANTITY * TOKEN_QUANTITY);

        // Approvals
        vm.startPrank(USER);
        erc1155.setApprovalForAll(address(orderbook), true);
        erc721.setApprovalForAll(address(orderbook), true);
        vm.stopPrank();
        vm.prank(PURCHASER);
        erc20.approve(address(orderbook), CURRENCY_QUANTITY);
    }

    //
    // Create
    //

    // This is tested and fuzzed through internal calls
    function test_createListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry) internal {
        vm.assume(pricePerToken != 0);
        vm.assume(expiry > block.timestamp);
        if (isERC1155) {
            vm.assume(quantity > 0 && quantity <= erc1155.balanceOf(USER, TOKEN_ID));
        } else {
            vm.assume(quantity == 1);
        }
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCreated(0, address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);
        vm.prank(USER);
        uint256 listingId =
            orderbook.createListing(address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);

        Listing memory listing = orderbook.getListing(listingId);
        assertEq(listing.creator, USER);
        assertEq(listing.tokenContract, address(tokenContract));
        assertEq(listing.tokenId, TOKEN_ID);
        assertEq(listing.quantity, quantity);
        assertEq(listing.currency, address(erc20));
        assertEq(listing.pricePerToken, pricePerToken);
        assertEq(listing.expiresAt, expiry);
    }

    function test_createListing_invalidToken(address badContract) internal {
        vm.assume(badContract != address(erc1155) && badContract != address(erc721));

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidTokenContract.selector, badContract));
        orderbook.createListing(badContract, TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidExpiry(uint256 expiry) external {
        vm.assume(expiry <= block.timestamp);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListing.selector, "Invalid expiration"));
        orderbook.createListing(address(erc1155), TOKEN_ID, 1, address(erc20), 1, expiry);
    }

    function test_createListing_invalidQuantity() external {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc1155), TOKEN_ID, 0, USER));
        orderbook.createListing(address(erc1155), TOKEN_ID, 0, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidPrice() external {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListing.selector, "Invalid price"));
        orderbook.createListing(address(erc1155), TOKEN_ID, 1, address(erc20), 0, block.timestamp + 1);
    }

    function test_createListing_erc1155_invalidQuantity(uint256 quantity) external {
        vm.assume(quantity > TOKEN_QUANTITY || quantity == 0);

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc1155), TOKEN_ID, quantity, USER)
        );
        orderbook.createListing(address(erc1155), TOKEN_ID, quantity, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_erc1155_invalidApproval(uint256 quantity) external {
        vm.assume(quantity <= TOKEN_QUANTITY);

        vm.prank(USER);
        erc1155.setApprovalForAll(address(orderbook), false);

        vm.prank(USER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc1155), TOKEN_ID, quantity, USER)
        );
        orderbook.createListing(address(erc1155), TOKEN_ID, quantity, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_erc721_noToken(uint256 tokenId) external {
        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc721), tokenId, 1, PURCHASER));
        orderbook.createListing(address(erc721), tokenId, 1, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_erc721_invalidApproval() external {
        vm.prank(USER);
        erc721.setApprovalForAll(address(orderbook), false);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc721), TOKEN_ID, 1, USER));
        orderbook.createListing(address(erc721), TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
    }

    //
    // Accept
    //
    function test_acceptListing_erc1155(uint256 quantity, uint256 pricePerToken, uint256 expiry) public {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);

        test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(0, PURCHASER, quantity);
        vm.prank(PURCHASER);
        orderbook.acceptListing(0, quantity);

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice);
    }

    function test_acceptListing_erc721(uint256 pricePerToken, uint256 expiry) public {
        vm.assume(pricePerToken <= TOKEN_QUANTITY);

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);

        test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(0, PURCHASER, 1);
        vm.prank(PURCHASER);
        orderbook.acceptListing(0, 1);

        assertEq(erc721.ownerOf(TOKEN_ID), PURCHASER);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - pricePerToken);
        assertEq(erc20.balanceOf(USER), erc20BalUser + pricePerToken);
    }

    function test_acceptListing_invalidQuantity_zero(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        test_createListing(isERC1155, isERC1155 ? quantity : 1, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(0, 0);
    }

    function test_acceptListing_invalidQuantity_tooHigh(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        quantity = isERC1155 ? quantity : 1;
        test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(0, quantity + 1);
    }

    function test_acceptListing_twice(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        quantity = (quantity / 2) * 2; // Cater for rounding error
        vm.assume(pricePerToken <= 1 ether && quantity > 1 && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);

        test_createListing(true, quantity, pricePerToken, expiry);

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
        test_acceptListing_erc1155(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, 0));
        orderbook.acceptListing(0, 1);
    }

    function test_acceptListing_noFunds(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        quantity = isERC1155 ? quantity : 1;
        vm.assume(pricePerToken <= (type(uint256).max / TOKEN_QUANTITY) && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice > erc20BalPurchaser);

        test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        orderbook.acceptListing(0, quantity);
    }

    function test_acceptListing_invalidERC721Owner(uint256 pricePerToken, uint256 expiry) external {
        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);

        test_createListing(false, 1, pricePerToken, expiry);

        vm.prank(USER);
        erc721.transferFrom(USER, PURCHASER, TOKEN_ID);

        vm.prank(PURCHASER);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        orderbook.acceptListing(0, 1);
    }

    //
    // Cancel
    //
    function test_cancelListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        test_createListing(isERC1155, quantity, pricePerToken, expiry);

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
