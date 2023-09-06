// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {NiftyswapOrderbook} from "src/contracts/orderbook/NiftyswapOrderbook.sol";
import {
    INiftyswapOrderbookSignals, INiftyswapOrderbookStorage
} from "src/contracts/interfaces/INiftyswapOrderbook.sol";
import {ERC1155RoyaltyMock} from "src/contracts/mocks/ERC1155RoyaltyMock.sol";
import {ERC721RoyaltyMock} from "src/contracts/mocks/ERC721RoyaltyMock.sol";
import {ERC20TokenMock} from "src/contracts/mocks/ERC20TokenMock.sol";
import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {Test, console} from "forge-std/Test.sol";

// solhint-disable not-rely-on-time

contract ERC1155ReentryAttacker is IERC1155TokenReceiver {
    address private immutable _orderbook;

    bytes32 private _orderId;
    uint256 private _quantity;
    bool private _hasAttacked;

    constructor(address orderbook) {
        _orderbook = orderbook;
    }

    function acceptListing(bytes32 orderId, uint256 quantity) external {
        _orderId = orderId;
        _quantity = quantity;
        NiftyswapOrderbook(_orderbook).acceptListing(_orderId, _quantity, new uint256[](0), new address[](0));
    }

    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _amount, bytes calldata _data)
        external
        returns (bytes4)
    {
        if (_hasAttacked) {
            // Done
            _hasAttacked = false;
            return IERC1155TokenReceiver.onERC1155Received.selector;
        }
        // Attack the orderbook
        _hasAttacked = true;
        NiftyswapOrderbook(_orderbook).acceptListing(_orderId, _quantity, new uint256[](0), new address[](0));
        return IERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _amounts,
        bytes calldata _data
    ) external returns (bytes4) {
        return IERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}

contract NiftyswapOrderbookTest is INiftyswapOrderbookSignals, INiftyswapOrderbookStorage, Test {
    NiftyswapOrderbook private orderbook;
    ERC1155RoyaltyMock private erc1155;
    ERC721RoyaltyMock private erc721;
    ERC20TokenMock private erc20;

    uint256 private constant TOKEN_ID = 1;
    uint256 private constant TOKEN_QUANTITY = 100;
    uint256 private constant CURRENCY_QUANTITY = 10 ether;

    uint256 private constant ROYALTY_FEE = 200; // 2%

    address private constant TOKEN_OWNER = address(uint160(uint256(keccak256("token_owner"))));
    address private constant CURRENCY_OWNER = address(uint160(uint256(keccak256("currency_owner"))));
    address private constant ROYALTY_RECEIVER = address(uint160(uint256(keccak256("royalty_receiver"))));
    address private constant FEE_RECEIVER = address(uint160(uint256(keccak256("fee_receiver"))));

    uint256[] private emptyFees;
    address[] private emptyFeeReceivers;

    function setUp() external {
        orderbook = new NiftyswapOrderbook();
        erc1155 = new ERC1155RoyaltyMock();
        erc721 = new ERC721RoyaltyMock();
        erc20 = new ERC20TokenMock();

        vm.label(TOKEN_OWNER, "token_owner");
        vm.label(CURRENCY_OWNER, "currency_owner");

        // Mint tokens
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = TOKEN_ID;
        uint256[] memory quantities = new uint256[](1);
        quantities[0] = TOKEN_QUANTITY;
        erc1155.batchMintMock(TOKEN_OWNER, tokenIds, quantities, "");

        erc721.mintMock(TOKEN_OWNER, TOKEN_QUANTITY);

        erc20.mockMint(CURRENCY_OWNER, CURRENCY_QUANTITY);

        // Approvals
        vm.startPrank(TOKEN_OWNER);
        erc1155.setApprovalForAll(address(orderbook), true);
        erc721.setApprovalForAll(address(orderbook), true);
        vm.stopPrank();
        vm.prank(CURRENCY_OWNER);
        erc20.approve(address(orderbook), CURRENCY_QUANTITY);

        // Royalty
        erc1155.setFee(ROYALTY_FEE);
        erc1155.setFeeRecipient(ROYALTY_RECEIVER);
        erc721.setFee(ROYALTY_FEE);
        erc721.setFeeRecipient(ROYALTY_RECEIVER);
    }

    //
    // Create Listing
    //

    // This is tested and fuzzed through internal calls
    function test_createListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        internal
        returns (bytes32 listingId)
    {
        vm.assume(pricePerToken != 0);
        vm.assume(expiry > block.timestamp);
        if (isERC1155) {
            vm.assume(quantity > 0 && quantity <= erc1155.balanceOf(TOKEN_OWNER, TOKEN_ID));
        } else {
            vm.assume(quantity == 1);
        }
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);

        Order memory expected = Order({
            isListing: true,
            isERC1155: isERC1155,
            creator: TOKEN_OWNER,
            tokenContract: tokenContract,
            tokenId: TOKEN_ID,
            quantity: quantity,
            currency: address(erc20),
            pricePerToken: pricePerToken,
            expiry: expiry
        });

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCreated(
            orderbook.hashOrder(expected),
            expected.tokenContract,
            expected.tokenId,
            expected.quantity,
            expected.currency,
            expected.pricePerToken,
            expected.expiry
        );
        vm.prank(TOKEN_OWNER);
        listingId = orderbook.createListing(
            isERC1155, address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry
        );

        Order memory listing = orderbook.getOrder(listingId);
        assertEq(listing.creator, expected.creator);
        assertEq(listing.tokenContract, expected.tokenContract);
        assertEq(listing.tokenId, expected.tokenId);
        assertEq(listing.quantity, expected.quantity);
        assertEq(listing.currency, expected.currency);
        assertEq(listing.pricePerToken, expected.pricePerToken);
        assertEq(listing.expiry, expected.expiry);

        return listingId;
    }

    function test_createListing_collision(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidOrderId.selector, listingId));
        orderbook.createListing(
            isERC1155, address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry
        );
    }

    function test_createListing_invalidToken(bool isERC1155, address badContract) external {
        vm.assume(badContract != address(erc1155) && badContract != address(erc721));

        vm.prank(TOKEN_OWNER);
        vm.expectRevert();
        orderbook.createListing(isERC1155, badContract, TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidExpiry(bool isERC1155, uint256 expiry) external {
        vm.assume(expiry <= block.timestamp);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidExpiry.selector);
        orderbook.createListing(
            isERC1155, isERC1155 ? address(erc1155) : address(erc721), TOKEN_ID, 1, address(erc20), 1, expiry
        );
    }

    function test_createListing_invalidQuantity_erc721(uint256 quantity) external {
        vm.assume(quantity != 1);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc721), TOKEN_ID, quantity, TOKEN_OWNER)
        );
        orderbook.createListing(false, address(erc721), TOKEN_ID, quantity, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidQuantity_erc1155(uint256 quantity) external {
        vm.assume(quantity > TOKEN_QUANTITY || quantity == 0);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc1155), TOKEN_ID, quantity, TOKEN_OWNER)
        );
        orderbook.createListing(true, address(erc1155), TOKEN_ID, quantity, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_invalidPrice(bool isERC1155) external {
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidPrice.selector);
        orderbook.createListing(isERC1155, tokenContract, TOKEN_ID, 1, address(erc20), 0, block.timestamp + 1);
    }

    function test_createListing_erc1155_invalidApproval(uint256 quantity) external {
        vm.assume(quantity <= TOKEN_QUANTITY);

        vm.prank(TOKEN_OWNER);
        erc1155.setApprovalForAll(address(orderbook), false);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc1155), TOKEN_ID, quantity, TOKEN_OWNER)
        );
        orderbook.createListing(true, address(erc1155), TOKEN_ID, quantity, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_erc721_noToken(uint256 tokenId) external {
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc721), tokenId, 1, CURRENCY_OWNER)
        );
        orderbook.createListing(false, address(erc721), tokenId, 1, address(erc20), 1, block.timestamp + 1);
    }

    function test_createListing_erc721_invalidApproval() external {
        vm.prank(TOKEN_OWNER);
        erc721.setApprovalForAll(address(orderbook), false);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(InvalidTokenApproval.selector, address(erc721), TOKEN_ID, 1, TOKEN_OWNER)
        );
        orderbook.createListing(false, address(erc721), TOKEN_ID, 1, address(erc20), 1, block.timestamp + 1);
    }

    //
    // Accept Listing
    //
    function test_acceptListing_erc1155(uint256 quantity, uint256 pricePerToken, uint256 expiry)
        public
        returns (bytes32 listingId)
    {
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, CURRENCY_OWNER, address(erc1155), quantity);
        vm.prank(CURRENCY_OWNER);
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return listingId;
    }

    function test_acceptListing_erc721(uint256 pricePerToken, uint256 expiry) public returns (bytes32 listingId) {
        vm.assume(pricePerToken <= TOKEN_QUANTITY);
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, CURRENCY_OWNER, address(erc721), 1);
        vm.prank(CURRENCY_OWNER);
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), CURRENCY_OWNER);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - pricePerToken);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + pricePerToken - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return listingId;
    }

    function test_acceptListing_erc1155_additionalFees(
        uint256 quantity,
        uint256 expiry,
        uint256[] memory additionalFees
    ) public {
        uint256 pricePerToken = 1 ether;
        vm.assume(quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeReceivers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeReceivers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 0.25 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, CURRENCY_OWNER, address(erc1155), quantity);
        vm.prank(CURRENCY_OWNER);
        orderbook.acceptListing(listingId, quantity, additionalFees, additionalFeeReceivers);

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        // Fees paid by taker
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice - totalFees);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_erc721_additionalFees(uint256 expiry, uint256[] memory additionalFees) public {
        uint256 pricePerToken = 1 ether;
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeReceivers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeReceivers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 0.25 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, CURRENCY_OWNER, address(erc721), 1);
        vm.prank(CURRENCY_OWNER);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), CURRENCY_OWNER);
        // Fees paid by taker
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - pricePerToken - totalFees);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + pricePerToken - royalty);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_invalidAdditionalFees(bool isERC1155) public {
        bytes32 listingId = test_createListing(isERC1155, 1, 1 ether, block.timestamp + 1);

        // Zero fee
        uint256[] memory additionalFees = new uint256[](1);
        address[] memory additionalFeeReceivers = new address[](1);
        additionalFeeReceivers[0] = FEE_RECEIVER;
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeReceivers);

        // Zero address
        additionalFees[0] = 1 ether;
        additionalFeeReceivers[0] = address(0);
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeReceivers);

        // Invalid length (larger receivers)
        additionalFeeReceivers = new address[](2);
        additionalFeeReceivers[0] = FEE_RECEIVER;
        additionalFeeReceivers[1] = FEE_RECEIVER;
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeReceivers);

        // Invalid length (larger fees)
        additionalFees = new uint256[](3);
        additionalFees[0] = 1;
        additionalFees[1] = 2;
        additionalFees[2] = 3;
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptListing(listingId, 1, additionalFees, additionalFeeReceivers);
    }

    function test_acceptListing_invalidQuantity_zero(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        bytes32 listingId = test_createListing(isERC1155, isERC1155 ? quantity : 1, pricePerToken, expiry);

        vm.prank(CURRENCY_OWNER);
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

        vm.prank(CURRENCY_OWNER);
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

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidExpiry.selector);
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_twice(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        // Cater for rounding error with / 2 * 2
        quantity = (quantity / 2) * 2;
        vm.assume(pricePerToken <= 1 ether && quantity > 1 && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity / 2 * 2;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000 / 2 * 2;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 listingId = test_createListing(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingAccepted(listingId, CURRENCY_OWNER, address(erc1155), quantity / 2);
        vm.startPrank(CURRENCY_OWNER);
        orderbook.acceptListing(listingId, quantity / 2, emptyFees, emptyFeeReceivers);
        orderbook.acceptListing(listingId, quantity / 2, emptyFees, emptyFeeReceivers);
        vm.stopPrank();

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice - royalty);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptListing_twice_overQuantity(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 listingId = test_acceptListing_erc1155(quantity, pricePerToken, expiry);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_noFunds(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        quantity = isERC1155 ? quantity : 1;
        vm.assume(pricePerToken <= (type(uint256).max / TOKEN_QUANTITY) && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice > erc20BalCurrency);

        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        orderbook.acceptListing(listingId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_invalidERC721Owner(uint256 pricePerToken, uint256 expiry) external {
        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);

        bytes32 listingId = test_createListing(false, 1, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        erc721.transferFrom(TOKEN_OWNER, CURRENCY_OWNER, TOKEN_ID);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptListing_reentry() external {
        ERC1155ReentryAttacker attacker = new ERC1155ReentryAttacker(address(orderbook));
        erc20.mockMint(address(attacker), CURRENCY_QUANTITY);
        vm.prank(address(attacker));
        erc20.approve(address(orderbook), CURRENCY_QUANTITY);

        bytes32 listingId = test_createListing(true, 1, 1 ether, block.timestamp + 1);

        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        attacker.acceptListing(listingId, 1);
    }

    //
    // Cancel Listing
    //
    function test_cancelListing(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 listingId = test_createListing(isERC1155, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit ListingCancelled(listingId, isERC1155 ? address(erc1155) : address(erc721));
        vm.prank(TOKEN_OWNER);
        orderbook.cancelListing(listingId);

        Order memory listing = orderbook.getOrder(listingId);
        // Zero'd
        assertEq(listing.creator, address(0));
        assertEq(listing.tokenContract, address(0));
        assertEq(listing.tokenId, 0);
        assertEq(listing.quantity, 0);
        assertEq(listing.currency, address(0));
        assertEq(listing.pricePerToken, 0);
        assertEq(listing.expiry, 0);

        // Accept fails
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidListingId.selector, listingId));
        orderbook.acceptListing(listingId, 1, emptyFees, emptyFeeReceivers);
    }

    //
    // Create Offer
    //

    // This is tested and fuzzed through internal calls
    function test_createOffer(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        internal
        returns (bytes32 offerId)
    {
        vm.assume(expiry > block.timestamp);
        vm.assume(pricePerToken != 0 && pricePerToken <= 1 ether);
        vm.assume(quantity < 1 ether);
        uint256 totalPrice = pricePerToken * quantity;
        vm.assume(totalPrice <= erc20.balanceOf(CURRENCY_OWNER));
        if (isERC1155) {
            vm.assume(quantity > 0 && quantity <= erc1155.balanceOf(TOKEN_OWNER, TOKEN_ID));
        } else {
            vm.assume(quantity == 1);
        }
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);

        Order memory expected = Order({
            isListing: false,
            isERC1155: isERC1155,
            creator: CURRENCY_OWNER,
            tokenContract: tokenContract,
            tokenId: TOKEN_ID,
            quantity: quantity,
            currency: address(erc20),
            pricePerToken: pricePerToken,
            expiry: expiry
        });

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferCreated(
            orderbook.hashOrder(expected),
            expected.tokenContract,
            expected.tokenId,
            expected.quantity,
            expected.currency,
            expected.pricePerToken,
            expected.expiry
        );
        vm.prank(CURRENCY_OWNER);
        offerId = orderbook.createOffer(
            isERC1155, address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry
        );

        Order memory offer = orderbook.getOrder(offerId);
        assertEq(offer.isListing, expected.isListing);
        assertEq(offer.isERC1155, expected.isERC1155);
        assertEq(offer.creator, expected.creator);
        assertEq(offer.tokenContract, expected.tokenContract);
        assertEq(offer.tokenId, expected.tokenId);
        assertEq(offer.quantity, expected.quantity);
        assertEq(offer.currency, expected.currency);
        assertEq(offer.pricePerToken, expected.pricePerToken);
        assertEq(offer.expiry, expected.expiry);

        return offerId;
    }

    function test_createOffer_collision(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        address tokenContract = isERC1155 ? address(erc1155) : address(erc721);
        bytes32 offerId = test_createOffer(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidOrderId.selector, offerId));
        orderbook.createOffer(
            isERC1155, address(tokenContract), TOKEN_ID, quantity, address(erc20), pricePerToken, expiry
        );
    }

    function test_createOffer_invalidExpiry(bool isERC1155, uint256 expiry) external {
        vm.assume(expiry <= block.timestamp);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidExpiry.selector);
        orderbook.createOffer(
            isERC1155, isERC1155 ? address(erc1155) : address(erc721), TOKEN_ID, 1, address(erc20), 1, expiry
        );
    }

    function test_createOffer_invalidQuantity(bool isERC1155) external {
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.createOffer(
            isERC1155,
            isERC1155 ? address(erc1155) : address(erc721),
            TOKEN_ID,
            0,
            address(erc20),
            1,
            block.timestamp + 1
        );
    }

    function test_createOffer_invalidPrice(bool isERC1155) external {
        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(InvalidPrice.selector);
        orderbook.createOffer(
            isERC1155,
            isERC1155 ? address(erc1155) : address(erc721),
            TOKEN_ID,
            1,
            address(erc20),
            0,
            block.timestamp + 1
        );
    }

    function test_createOffer_invalidApproval(bool isERC1155) external {
        vm.prank(CURRENCY_OWNER);
        erc20.approve(address(orderbook), 0);

        vm.prank(CURRENCY_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidCurrencyApproval.selector, address(erc20), 1, CURRENCY_OWNER));
        orderbook.createOffer(
            isERC1155,
            isERC1155 ? address(erc1155) : address(erc721),
            TOKEN_ID,
            1,
            address(erc20),
            1,
            block.timestamp + 1
        );
    }

    //
    // Accept Offer
    //
    function test_acceptOffer_erc1155(uint256 quantity, uint256 pricePerToken, uint256 expiry)
        public
        returns (bytes32 offerId)
    {
        vm.assume(quantity > 0);
        vm.assume(pricePerToken <= 1 ether && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        offerId = test_createOffer(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferAccepted(offerId, TOKEN_OWNER, address(erc1155), quantity);
        vm.prank(TOKEN_OWNER);
        orderbook.acceptOffer(offerId, quantity, emptyFees, emptyFeeReceivers);

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice - royalty);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return offerId;
    }

    function test_acceptOffer_erc721(uint256 pricePerToken, uint256 expiry) public returns (bytes32 offerId) {
        vm.assume(pricePerToken <= TOKEN_QUANTITY);
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        offerId = test_createOffer(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferAccepted(offerId, TOKEN_OWNER, address(erc721), 1);
        vm.prank(TOKEN_OWNER);
        orderbook.acceptOffer(offerId, 1, emptyFees, emptyFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), CURRENCY_OWNER);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - pricePerToken - royalty);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + pricePerToken);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);

        return offerId;
    }

    function test_acceptOffer_erc1155_additionalFees(uint256 quantity, uint256 expiry, uint256[] memory additionalFees)
        public
    {
        uint256 pricePerToken = 1 ether;
        vm.assume(quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeReceivers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeReceivers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 0.25 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 offerId = test_createOffer(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferAccepted(offerId, TOKEN_OWNER, address(erc1155), quantity);
        vm.prank(TOKEN_OWNER);
        orderbook.acceptOffer(offerId, quantity, additionalFees, additionalFeeReceivers);

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice - royalty);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        // Fees paid by taker
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice - totalFees);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptOffer_erc721_additionalFees(uint256 expiry, uint256[] memory additionalFees) public {
        uint256 pricePerToken = 1 ether;
        uint256 royalty = (pricePerToken * ROYALTY_FEE) / 10000;

        if (additionalFees.length > 2) {
            // Cap at 2 fees
            assembly {
                mstore(additionalFees, 2)
            }
        }
        address[] memory additionalFeeReceivers = new address[](additionalFees.length);
        uint256 totalFees;
        for (uint256 i; i < additionalFees.length; i++) {
            additionalFeeReceivers[i] = FEE_RECEIVER;
            additionalFees[i] = bound(additionalFees[i], 1, 0.25 ether);
            totalFees += additionalFees[i];
        }

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 offerId = test_createOffer(false, 1, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferAccepted(offerId, TOKEN_OWNER, address(erc721), 1);
        vm.prank(TOKEN_OWNER);
        orderbook.acceptOffer(offerId, 1, additionalFees, additionalFeeReceivers);

        assertEq(erc721.ownerOf(TOKEN_ID), CURRENCY_OWNER);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - pricePerToken - royalty);
        // Fees paid by taker
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + pricePerToken - totalFees);
        assertEq(erc20.balanceOf(FEE_RECEIVER), totalFees); // Assume no starting value
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptOffer_invalidAdditionalFees(bool isERC1155) public {
        bytes32 offerId = test_createOffer(isERC1155, 1, 1 ether, block.timestamp + 1);

        // Zero fee
        uint256[] memory additionalFees = new uint256[](1);
        address[] memory additionalFeeReceivers = new address[](1);
        additionalFeeReceivers[0] = FEE_RECEIVER;
        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptOffer(offerId, 1, additionalFees, additionalFeeReceivers);

        // Zero address
        additionalFees[0] = 1 ether;
        additionalFeeReceivers[0] = address(0);
        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptOffer(offerId, 1, additionalFees, additionalFeeReceivers);

        // Invalid length (larger receivers)
        additionalFeeReceivers = new address[](2);
        additionalFeeReceivers[0] = FEE_RECEIVER;
        additionalFeeReceivers[1] = FEE_RECEIVER;
        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptOffer(offerId, 1, additionalFees, additionalFeeReceivers);

        // Invalid length (larger fees)
        additionalFees = new uint256[](3);
        additionalFees[0] = 1;
        additionalFees[1] = 2;
        additionalFees[2] = 3;
        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidAdditionalFees.selector);
        orderbook.acceptOffer(offerId, 1, additionalFees, additionalFeeReceivers);
    }

    function test_acceptOffer_invalidQuantity_zero(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        bytes32 offerId = test_createOffer(isERC1155, isERC1155 ? quantity : 1, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptOffer(offerId, 0, emptyFees, emptyFeeReceivers);
    }

    function test_acceptOffer_invalidQuantity_tooHigh(
        bool isERC1155,
        uint256 quantity,
        uint256 pricePerToken,
        uint256 expiry
    ) external {
        quantity = isERC1155 ? quantity : 1;
        bytes32 offerId = test_createOffer(isERC1155, quantity, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidQuantity.selector);
        orderbook.acceptOffer(offerId, quantity + 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptOffer_invalidExpiry(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        if (expiry > type(uint256).max / 2) {
            // Prevent overflow
            expiry = type(uint256).max / 2;
        }
        quantity = isERC1155 ? quantity : 1;
        bytes32 offerId = test_createOffer(isERC1155, quantity, pricePerToken, expiry);

        vm.warp(expiry + 1);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(InvalidExpiry.selector);
        orderbook.acceptOffer(offerId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptOffer_twice(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        // Cater for rounding error with / 2 * 2
        quantity = (quantity / 2) * 2;
        vm.assume(pricePerToken <= 1 ether && quantity > 1 && quantity <= TOKEN_QUANTITY); // Prevent overflow
        uint256 totalPrice = pricePerToken * quantity / 2 * 2;
        uint256 royalty = (totalPrice * ROYALTY_FEE) / 10000 / 2 * 2;

        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(totalPrice < erc20BalCurrency);
        uint256 erc20BalTokenOwner = erc20.balanceOf(TOKEN_OWNER);
        uint256 erc20BalRoyal = erc20.balanceOf(ROYALTY_RECEIVER);

        bytes32 offerId = test_createOffer(true, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferAccepted(offerId, TOKEN_OWNER, address(erc1155), quantity / 2);
        vm.startPrank(TOKEN_OWNER);
        orderbook.acceptOffer(offerId, quantity / 2, emptyFees, emptyFeeReceivers);
        orderbook.acceptOffer(offerId, quantity / 2, emptyFees, emptyFeeReceivers);
        vm.stopPrank();

        assertEq(erc1155.balanceOf(CURRENCY_OWNER, TOKEN_ID), quantity);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), erc20BalCurrency - totalPrice - royalty);
        assertEq(erc20.balanceOf(TOKEN_OWNER), erc20BalTokenOwner + totalPrice);
        assertEq(erc20.balanceOf(ROYALTY_RECEIVER), erc20BalRoyal + royalty);
    }

    function test_acceptOffer_twice_overQuantity(uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 offerId = test_acceptOffer_erc1155(quantity, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidOfferId.selector, offerId));
        orderbook.acceptOffer(offerId, 1, emptyFees, emptyFeeReceivers);
    }

    function test_acceptOffer_noFunds(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry)
        external
    {
        quantity = isERC1155 ? quantity : 1;

        bytes32 offerId = test_createOffer(isERC1155, quantity, pricePerToken, expiry);

        uint256 bal = erc20.balanceOf(CURRENCY_OWNER);
        vm.prank(CURRENCY_OWNER);
        erc20.transfer(TOKEN_OWNER, bal); // Send all funds away

        vm.prank(TOKEN_OWNER);
        vm.expectRevert("TransferHelper::transferFrom: transferFrom failed");
        orderbook.acceptOffer(offerId, quantity, emptyFees, emptyFeeReceivers);
    }

    function test_acceptOffer_invalidERC721Owner(uint256 pricePerToken, uint256 expiry) external {
        uint256 erc20BalCurrency = erc20.balanceOf(CURRENCY_OWNER);
        vm.assume(pricePerToken <= erc20BalCurrency);

        bytes32 offerId = test_createOffer(false, 1, pricePerToken, expiry);

        vm.prank(TOKEN_OWNER);
        erc721.transferFrom(TOKEN_OWNER, CURRENCY_OWNER, TOKEN_ID);

        vm.prank(TOKEN_OWNER);
        vm.expectRevert("ERC721: caller is not token owner or approved");
        orderbook.acceptOffer(offerId, 1, emptyFees, emptyFeeReceivers);
    }

    //
    // Cancel Offer
    //
    function test_cancelOffer(bool isERC1155, uint256 quantity, uint256 pricePerToken, uint256 expiry) external {
        bytes32 offerId = test_createOffer(isERC1155, quantity, pricePerToken, expiry);

        vm.expectEmit(true, true, true, true, address(orderbook));
        emit OfferCancelled(offerId, isERC1155 ? address(erc1155) : address(erc721));
        vm.prank(CURRENCY_OWNER);
        orderbook.cancelOffer(offerId);

        Order memory offer = orderbook.getOrder(offerId);
        // Zero'd
        assertEq(offer.creator, address(0));
        assertEq(offer.tokenContract, address(0));
        assertEq(offer.tokenId, 0);
        assertEq(offer.quantity, 0);
        assertEq(offer.currency, address(0));
        assertEq(offer.pricePerToken, 0);
        assertEq(offer.expiry, 0);

        // Accept fails
        vm.prank(TOKEN_OWNER);
        vm.expectRevert(abi.encodeWithSelector(InvalidOfferId.selector, offerId));
        orderbook.acceptOffer(offerId, 1, emptyFees, emptyFeeReceivers);
    }

    //
    // isValid
    //
    function test_isOrderValid_expired() external {
        bytes32[] memory orderIds = new bytes32[](4);
        orderIds[0] = test_createListing(true, 1, 1 ether, block.timestamp + 1);
        orderIds[1] = test_createListing(false, 1, 1 ether, block.timestamp + 2);
        orderIds[2] = test_createOffer(true, 1, 1 ether, block.timestamp + 3);
        orderIds[3] = test_createOffer(false, 1, 1 ether, block.timestamp + 4);

        vm.warp(block.timestamp + 5);

        bool[] memory valid = orderbook.isOrderValid(orderIds);
        for (uint256 i; i < 4; i++) {
            assertEq(valid[i], false);
        }
    }

    function test_isOrderValid_invalidApproval() external {
        bytes32[] memory orderIds = new bytes32[](4);
        orderIds[0] = test_createListing(true, 1, 1 ether, block.timestamp + 1);
        orderIds[1] = test_createListing(false, 1, 1 ether, block.timestamp + 1);
        orderIds[2] = test_createOffer(true, 1, 1 ether, block.timestamp + 1);
        orderIds[3] = test_createOffer(false, 1, 1 ether, block.timestamp + 1);

        vm.startPrank(TOKEN_OWNER);
        erc1155.setApprovalForAll(address(orderbook), false);
        erc721.setApprovalForAll(address(orderbook), false);
        vm.stopPrank();
        vm.prank(CURRENCY_OWNER);
        erc20.approve(address(orderbook), 0);

        bool[] memory valid = orderbook.isOrderValid(orderIds);
        for (uint256 i; i < 4; i++) {
            assertEq(valid[i], false);
        }
    }

    function test_isOrderValid_invalidBalance() external {
        bytes32[] memory orderIds = new bytes32[](4);
        orderIds[0] = test_createListing(true, 1, 1 ether, block.timestamp + 1);
        orderIds[1] = test_createListing(false, 1, 1 ether, block.timestamp + 1);
        orderIds[2] = test_createOffer(true, 1, 1 ether, block.timestamp + 1);
        orderIds[3] = test_createOffer(false, 1, 1 ether, block.timestamp + 1);

        // Use fee receiver as a "random" address
        vm.startPrank(TOKEN_OWNER);
        erc1155.safeTransferFrom(TOKEN_OWNER, FEE_RECEIVER, TOKEN_ID, erc1155.balanceOf(TOKEN_OWNER, TOKEN_ID), "");
        assertEq(erc1155.balanceOf(TOKEN_OWNER, TOKEN_ID), 0);
        erc721.transferFrom(TOKEN_OWNER, FEE_RECEIVER, TOKEN_ID);
        vm.stopPrank();
        vm.startPrank(CURRENCY_OWNER);
        erc20.transfer(FEE_RECEIVER, CURRENCY_QUANTITY);
        assertEq(erc20.balanceOf(CURRENCY_OWNER), 0);
        vm.stopPrank();

        bool[] memory valid = orderbook.isOrderValid(orderIds);
        for (uint256 i; i < 4; i++) {
            assertEq(valid[i], false);
        }
    }

    function test_isOrderValid_bulk(uint8 count, bool[] memory expectValid, bool[] memory isListing) external {
        // Bound sizes (default to false when smaller)
        assembly {
            mstore(expectValid, count)
            mstore(isListing, count)
        }

        bytes32[] memory orderIds = new bytes32[](count);
        for (uint256 i; i < count; i++) {
            if (isListing[i]) {
                orderIds[i] = test_createListing(true, 1, 1 ether, block.timestamp + 1 + i); // Add index to prevent collisions
                if (!expectValid[i]) {
                    // Cancel it
                    vm.prank(TOKEN_OWNER);
                    orderbook.cancelListing(orderIds[i]);
                }
            } else {
                orderIds[i] = test_createOffer(true, 1, 1 ether, block.timestamp + 1 + i); // Add index to prevent collisions
                if (!expectValid[i]) {
                    // Cancel it
                    vm.prank(CURRENCY_OWNER);
                    orderbook.cancelOffer(orderIds[i]);
                }
            }
        }

        bool[] memory valid = orderbook.isOrderValid(orderIds);
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
