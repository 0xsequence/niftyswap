// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapOrderbook} from "src/contracts/orderbook/NiftyswapOrderbook.sol";
import {
    INiftyswapOrderbookSignals, INiftyswapOrderbookStorage
} from "src/contracts/interfaces/INiftyswapOrderbook.sol";
import {ERC1155RoyaltyMock} from "src/contracts/mocks/ERC1155RoyaltyMock.sol";
import {ERC721RoyaltyMock} from "src/contracts/mocks/ERC721RoyaltyMock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";

import {Test, console} from "forge-std/Test.sol";

// solhint-disable not-rely-on-time

contract NiftyswapOrderbookTest is INiftyswapOrderbookSignals, INiftyswapOrderbookStorage, Test {
    NiftyswapOrderbook private orderbook;
    ERC1155RoyaltyMock private erc1155;
    ERC721RoyaltyMock private erc721;
    ERC20TokenMock private erc20;

    uint256 private constant TOKEN_ID = 1;
    uint256 private constant TOKEN_QUANTITY = 100;
    uint256 private constant CURRENCY_QUANTITY = 10 ether;

    uint256 private constant ROYALTY_FEE = 200; // 2%

    address private constant USER = address(uint160(uint256(keccak256("user"))));
    address private constant PURCHASER = address(uint160(uint256(keccak256("purchaser"))));
    address private constant ROYALTY_RECEIVER = address(uint160(uint256(keccak256("royalty_receiver"))));
    address private constant FEE_RECEIVER = address(uint160(uint256(keccak256("fee_receiver"))));

    uint256[] private emptyFees;
    address[] private emptyFeeReceivers;

    function setUp() external {
        orderbook = new NiftyswapOrderbook();
        erc1155 = new ERC1155RoyaltyMock();
        erc721 = new ERC721RoyaltyMock();
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

        // Royalty
        erc1155.setFee(ROYALTY_FEE);
        erc1155.setFeeRecipient(ROYALTY_RECEIVER);
        erc721.setFee(ROYALTY_FEE);
        erc721.setFeeRecipient(ROYALTY_RECEIVER);
    }

    //
    // Create
    //

    // This is tested and fuzzed through internal calls
    function test_createListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        internal
        returns (bytes32 listingId)
    {
        vm.assume(pricePerToken != 0);
        vm.assume(expiry > block.timestamp);
        if (isERC1155) {
            vm.assume(quantity > 0 && quantity <= erc1155.balanceOf(USER, TOKEN_ID));
        } else {
            vm.assume(quantity == 1);
        }
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);

        Listing memory expected = Listing({
            creator: USER,
            tokenContract: tokenContract,
            tokenId: TOKEN_ID,
            quantity: quantity,
            currency: address(erc20),
            pricePerToken: pricePerToken,
            expiresAt: expiry
        });

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCreated(
            orderbook.hashListing(expected),
            expected.tokenContract,
            expected.tokenId,
            expected.quantity,
            expected.currency,
            expected.pricePerToken,
            expected.expiresAt
        );
        vm.prank(USER);
        listingId =
            orderbook.createListing(address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);

        Listing memory listing = orderbook.getListing(listingId);
        assertEq(listing.creator, expected.creator);
        assertEq(listing.tokenContract, expected.tokenContract);
        assertEq(listing.tokenId, expected.tokenId);
        assertEq(listing.quantity, expected.quantity);
        assertEq(listing.currency, expected.currency);
        assertEq(listing.pricePerToken, expected.pricePerToken);
        assertEq(listing.expiresAt, listing.expiresAt);

        return listingId;
    }

    function test_createListing_collision(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        orderbook.createListing(address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry);
    }

    function test_createListing_invalidToken(address badContract) external {
        vm.assume(badContract != address(erc1155) && badContract != address(erc721));

        vm.prank(USER);
        vm.expectRevert();
        orderbook.createListing(badContract, TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidToken_noSupport() external {
        vm.prank(USER);
        vm.expectRevert(abi.encodeWithSelector(InvalidTokenContract.selector, address(erc20)));
        orderbook.createListing(address(erc20), TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
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
    function test_acceptListing_erc1155(uint256 quantity, uint256 pricePerToken, uint256 expiry)
        public
        returns (bytes32 listingId)
    {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, quantity);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return listingId;
    }

    function test_acceptListing_erc721(uint256 pricePerToken, uint256 expiry) public returns (bytes32 listingId) {
        vm.assume(pricePerToken <= TOKEN_QUANTITY);
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, 1);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), PURCHASER);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - pricePerToken);
        assertEq(erc20.balanceOf(USER), erc20BalUser + pricePerToken - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return listingId;
    }

    function test_acceptListing_erc1155_additionalFees(
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry,
        uint256[] memory additionalFees
    ) public {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeRecievers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeRecievers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 1 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, quantity);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, quantity, additionalFees, additionalFeeRecievers);

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice - totalFees);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_erc721_additionalFees(
        uint256 pricePerToken,
        uint256 expiry,
        uint256[] memory additionalFees
    ) public {
        vm.assume(pricePerToken <= TOKEN_QUANTITY);
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeRecievers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeRecievers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 1 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, 1);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeRecievers);

        assertEq(erc721.ownerOf(TOKEN_ID), PURCHASER);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - pricePerToken - totalFees);
        assertEq(erc20.balanceOf(USER), erc20BalUser + pricePerToken - royalty);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_erc1155_cappedRoyalty(
        uint256 royaltyFee,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) public {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        royaltyFee = bound(royaltyFee, 2500, 9999);

        erc1155.setFee(royaltyFee);

        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = totalPrice / 4; // 25%

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, quantity);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_erc721_cappedRoyalty(uint256 royaltyFee, uint256 pricePerToken, uint256 expiry)
        public
    {
        royaltyFee = bound(royaltyFee, 2500, 9999);

        erc721.setFee(royaltyFee);

        uint256 royalty = pricePerToken / 4;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, 1);
        vm.prank(PURCHASER);
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), PURCHASER);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - pricePerToken);
        assertEq(erc20.balanceOf(USER), erc20BalUser + pricePerToken - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_invalidAdditionalFees(bool isERC1155) public {
        bytes32 listingId = test_createListing(isERC1155, 1, 1 ether, block.timestamp + 1);

        // Zero fee
        uint256[] memory additionalFees = new uint256[](1);
        address[] memory additionalFeeRecievers = new address[](1);
        additionalFeeRecievers[0] = FEE_RECEIVER;
        vm.prank(PURCHASER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeRecievers);

        // Zero address
        additionalFees[0] = 1 ether;
        additionalFeeRecievers[0] = address(0);
        vm.prank(PURCHASER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeRecievers);

        // Invalid length (larger receivers)
        additionalFeeRecievers = new address[](2);
        additionalFeeRecievers[0] = FEE_RECEIVER;
        additionalFeeRecievers[1] = FEE_RECEIVER;
        vm.prank(PURCHASER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeRecievers);

        // Invalid length (larger fees)
        additionalFees = new uint256[](3);
        additionalFees[0] = 1;
        additionalFees[1] = 2;
        additionalFees[2] = 3;
        vm.prank(PURCHASER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeRecievers);
    }

    function test_acceptListing_invalidQuantity_zero(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        bytes32 listingId = test_createListing(isERC1155, isERC1155 ? quantity : 1, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(listingId, 0, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_invalidQuantity_tooHigh(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        quantity = isERC1155 ? quantity : 1;
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptListing(listingId, quantity + 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_invalidExpiry(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        if (expiry > type(uint256).max / 2) {
            // Prevent overflow
            expiry = type(uint256).max / 2;
        }
        quantity = isERC1155 ? quantity : 1;
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.warp(expiry + 1);

        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListing.selector, "Listing expired"));
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_twice(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        // Cater for rounding error with / 2 * 2
        quantity = (quantity / 2) * 2;
        vm.assume(pricePerToken <= 1 ether && quantity > 1 && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity / 2 * 2;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000 / 2 * 2;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice < erc20BalPurchaser);
        uint256 erc20BalUser = erc20.balanceOf(USER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, PURCHASER, quantity / 2);
        vm.startPrank(PURCHASER);
        orderbook.acceptListing(listingId, quantity / 2, emptyFees, emptyFeeReceivers);
        orderbook.acceptListing(listingId, quantity / 2, emptyFees, emptyFeeReceivers);
        vm.stopPrank();

        assertEq(erc1155.balanceOf(PURCHASER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(PURCHASER), erc20BalPurchaser - totalPrice);
        assertEq(erc20.balanceOf(USER), erc20BalUser + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_twice_overQuantity(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 listingId = test_acceptListing_erc1155(quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_noFunds(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        quantity = isERC1155 ? quantity : 1;
        vm.assume(pricePerToken <= (type(uint256).max / TOKEN_QUANTITY) && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(totalPrice > erc20BalPurchaser);

        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(PURCHASER);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_invalidERC721Owner(uint256 pricePerToken, uint256 expiry) external {
        uint256 erc20BalPurchaser = erc20.balanceOf(PURCHASER);
        vm.assume(pricePerToken <= erc20BalPurchaser);

        bytes32 listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.prank(USER);
        erc721.transferFrom(USER, PURCHASER, TOKEN_ID);

        vm.prank(PURCHASER);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    //
    // Cancel
    //
    function test_cancelListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCancelled(listingId);
        vm.prank(USER);
        orderbook.cancelListing(listingId);

        Listing memory listing = orderbook.getListing(listingId);
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
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    //
    // isValid
    //
    function test_isListingValid(uint8 count, bool[] memory expectValid) external {
        // Bound valid size
        assembly {
            mstore(expectValid, count)
        }

        bytes32[] memory listingIds = new bytes32[](count);
        for (uint256 i; i < count; i++) {
            listingIds[i] = test_createListing(true, 1, 1 ether, block.timestamp + 1 + i); // Add index to prevent collisions
            if (!expectValid[i]) {
                // Cancel it
                vm.prank(USER);
                orderbook.cancelListing(listingIds[i]);
            }
        }

        bool[] memory valid = orderbook.isListingValid(listingIds);
        assertEq(valid.length, count);
        for (uint256 i; i < count; i++) {
            assertEq(valid[i], expectValid[i]);
        }
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
