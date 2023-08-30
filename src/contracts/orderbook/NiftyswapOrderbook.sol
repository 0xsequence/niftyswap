// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapOrderbook} from "../interfaces/INiftyswapOrderbook.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC2981} from "../interfaces/IERC2981.sol";
import {IERC20} from "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract NiftyswapOrderbook is INiftyswapOrderbook {
    mapping(bytes32 => Order) internal orders;

    /**
     * Lists a token for sale.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token. Note this includes royalties.
     * @param expiry The timestamp at which the listing expires.
     * @return listingId The ID of the listing.
     * @notice Listings cannot be created for unowned or unapproved tokens.
     */
    function createListing(
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 listingId) {
        // Check valid token for listing
        if (!_hasApprovedTokens(tokenContract, tokenId, quantity, msg.sender)) {
            revert InvalidTokenApproval(tokenContract, tokenId, quantity, msg.sender);
        }

        listingId = _createOrder(true, tokenContract, tokenId, quantity, currency, pricePerToken, expiry);

        emit ListingCreated(listingId, tokenContract, tokenId, quantity, currency, pricePerToken, expiry);

        return listingId;
    }

    /**
     * Offer a price for a token.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to buy.
     * @param currency The address of the currency to offer for the token.
     * @param pricePerToken The price per token.
     * @param expiry The timestamp at which the offer expires.
     * @return offerId The ID of the offer.
     */
    function createOffer(
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 offerId) {
        // Check approved currency for offer
        uint256 total = quantity * pricePerToken;
        if (!_hasApprovedCurrency(currency, total, msg.sender)) {
            revert InvalidCurrencyApproval(currency, total, msg.sender);
        }
        // Check quantity
        bool isERC1155 = _tokenIsERC1155(tokenContract);
        if ((isERC1155 && quantity == 0) || (!isERC1155 && quantity != 1)) {
            revert InvalidQuantity();
        }

        offerId = _createOrder(false, tokenContract, tokenId, quantity, currency, pricePerToken, expiry);

        emit OfferCreated(offerId, tokenContract, tokenId, quantity, currency, pricePerToken, expiry);

        return offerId;
    }

    /**
     * Create an order, either listing or offer.
     * @param isListing True if the order is a listing, false if it is an offer.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token. Note this includes royalties.
     * @param expiry The timestamp at which the listing expires.
     * @return orderId The ID of the order.
     */
    function _createOrder(
        bool isListing,
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) internal returns (bytes32 orderId) {
        if (pricePerToken == 0) {
            revert InvalidPrice();
        }
        // solhint-disable-next-line not-rely-on-time
        if (expiry <= block.timestamp) {
            revert InvalidExpiry();
        }

        Order memory order = Order({
            isListing: isListing,
            creator: msg.sender,
            tokenContract: tokenContract,
            tokenId: tokenId,
            quantity: quantity,
            currency: currency,
            pricePerToken: pricePerToken,
            expiry: expiry
        });
        orderId = hashOrder(order);

        if (orders[orderId].creator != address(0)) {
            // Collision
            revert InvalidOrderId(orderId);
        }
        orders[orderId] = order;

        return orderId;
    }

    /**
     * Purchases a token.
     * @param listingId The ID of the listing.
     * @param quantity The quantity of tokens to purchase.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeRecievers The addresses to send the additional fees to.
     * @dev Royalties are taken from the listing cost.
     */
    function acceptListing(
        bytes32 listingId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeRecievers
    ) external {
        Order memory listing = orders[listingId];
        if (!listing.isListing || listing.creator == address(0)) {
            // Is a listing, cancelled, completed or never existed
            revert InvalidListingId(listingId);
        }

        _acceptOrder(listingId, listing, quantity, additionalFees, additionalFeeRecievers);

        emit ListingAccepted(listingId, msg.sender, listing.tokenContract, quantity);
    }

    /**
     * Sells a token.
     * @param offerId The ID of the listing.
     * @param quantity The quantity of tokens to sell.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeRecievers The addresses to send the additional fees to.
     */
    function acceptOffer(
        bytes32 offerId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeRecievers
    ) external {
        Order memory offer = orders[offerId];
        if (offer.isListing || offer.creator == address(0)) {
            // Is a listing, cancelled, completed or never existed
            revert InvalidOfferId(offerId);
        }

        _acceptOrder(offerId, offer, quantity, additionalFees, additionalFeeRecievers);

        emit OfferAccepted(offerId, msg.sender, offer.tokenContract, quantity);
    }

    function _acceptOrder(
        bytes32 orderId,
        Order memory order,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeRecievers
    ) internal {
        if (quantity == 0 || quantity > order.quantity) {
            revert InvalidQuantity();
        }
        if (_isExpired(order)) {
            revert InvalidExpiry();
        }
        if (additionalFees.length != additionalFeeRecievers.length) {
            revert InvalidAdditionalFees();
        }

        // Update order state
        if (order.quantity == quantity) {
            // Refund some gas
            delete orders[orderId];
        } else {
            orders[orderId].quantity -= quantity;
        }

        // Calculate payables
        uint256 totalCost = order.pricePerToken * quantity;
        (address royaltyRecipient, uint256 royaltyAmount) =
            getRoyaltyInfo(order.tokenContract, order.tokenId, totalCost);

        address currencyReceiver = order.isListing ? order.creator : msg.sender;
        address tokenReceiver = order.isListing ? msg.sender : order.creator;

        if (royaltyAmount > 0) {
            // Transfer royalties
            TransferHelper.safeTransferFrom(order.currency, tokenReceiver, royaltyRecipient, royaltyAmount);
        }

        // Transfer currency
        TransferHelper.safeTransferFrom(order.currency, tokenReceiver, currencyReceiver, totalCost - royaltyAmount);

        // Transfer additional fees
        for (uint256 i; i < additionalFees.length; i++) {
            if (additionalFeeRecievers[i] == address(0) || additionalFees[i] == 0) {
                revert InvalidAdditionalFees();
            }
            TransferHelper.safeTransferFrom(order.currency, tokenReceiver, additionalFeeRecievers[i], additionalFees[i]);
        }

        // Transfer token
        address tokenContract = order.tokenContract;
        if (_tokenIsERC1155(tokenContract)) {
            IERC1155(tokenContract).safeTransferFrom(currencyReceiver, tokenReceiver, order.tokenId, quantity, "");
        } else {
            IERC721(tokenContract).transferFrom(currencyReceiver, tokenReceiver, order.tokenId);
        }
    }

    /**
     * Cancels a listing.
     * @param listingId The ID of the listing.
     */
    function cancelListing(bytes32 listingId) external {
        Order storage listing = orders[listingId];
        if (listing.creator != msg.sender) {
            revert InvalidListingId(listingId);
        }
        address tokenContract = listing.tokenContract;

        // Refund some gas
        delete orders[listingId];

        emit ListingCancelled(listingId, tokenContract);
    }

    /**
     * Cancels an offer.
     * @param offerId The ID of the offer.
     */
    function cancelOffer(bytes32 offerId) external {
        Order storage offer = orders[offerId];
        if (offer.creator != msg.sender) {
            revert InvalidOfferId(offerId);
        }
        address tokenContract = offer.tokenContract;

        // Refund some gas
        delete orders[offerId];

        emit OfferCancelled(offerId, tokenContract);
    }

    /**
     * Deterministically create the orderId for the given order.
     * @param order The order.
     * @return orderId The ID of the order.
     */
    function hashOrder(Order memory order) public pure returns (bytes32 orderId) {
        return keccak256(
            abi.encodePacked(
                order.creator,
                order.tokenContract,
                order.tokenId,
                order.quantity,
                order.currency,
                order.pricePerToken,
                order.expiry
            )
        );
    }

    /**
     * Gets an order.
     * @param orderId The ID of the listing or offer.
     * @return order The order.
     */
    function getOrder(bytes32 orderId) external view returns (Order memory order) {
        return orders[orderId];
    }

    /**
     * Checks if orders are valid.
     * @param orderIds The IDs of the orders.
     * @return valid The validities of the orders.
     * @notice An order is valid if it is active, has not expired and tokens (currency for offers, tokens for listings) are transferrable.
     */
    function isOrderValid(bytes32[] memory orderIds) external view returns (bool[] memory valid) {
        valid = new bool[](orderIds.length);
        for (uint256 i; i < orderIds.length; i++) {
            Order memory order = orders[orderIds[i]];
            valid[i] = order.creator != address(0) && !_isExpired(order)
                && _hasApprovedTokens(order.tokenContract, order.tokenId, order.quantity, order.creator);
        }
    }

    /**
     * Checks if a order has expired.
     * @param order The order to check.
     * @return isExpired True if the order has expired.
     */
    function _isExpired(Order memory order) internal view returns (bool isExpired) {
        // solhint-disable-next-line not-rely-on-time
        return order.expiry <= block.timestamp;
    }

    /**
     * Checks if a token contract is ERC1155 or ERC721.
     * @param tokenContract The address of the token contract.
     * @return isERC1155 True if the token contract is ERC1155, false if ERC721.
     * @dev Throws if the token contract is not ERC1155 or ERC721.
     */
    function _tokenIsERC1155(address tokenContract) internal view returns (bool isERC1155) {
        try IERC165(tokenContract).supportsInterface(type(IERC1155).interfaceId) returns (bool supported) {
            if (supported) {
                return true;
            }
        } catch {} // solhint-disable-line no-empty-blocks
        try IERC165(tokenContract).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            if (supported) {
                return false;
            }
        } catch {} // solhint-disable-line no-empty-blocks
        // Fail out
        revert InvalidTokenContract(tokenContract);
    }

    /**
     * Will return how much of currency need to be paid for the royalty.
     * @param tokenContract Address of the erc-1155 token being traded
     * @param tokenId ID of the erc-1155 token being traded
     * @param cost Amount of currency sent/received for the trade
     * @return recipient Address that will be able to claim the royalty
     * @return royalty Amount of currency that will be sent to royalty recipient
     */
    function getRoyaltyInfo(address tokenContract, uint256 tokenId, uint256 cost)
        public
        view
        returns (address recipient, uint256 royalty)
    {
        try IERC2981(address(tokenContract)).royaltyInfo(tokenId, cost) returns (address _r, uint256 _c) {
            return (_r, _c);
        } catch {} // solhint-disable-line no-empty-blocks
        return (address(0), 0);
    }

    /**
     * Checks if the amount of currency is approved for transfer exceeds the given amount.
     * @param currency The address of the currency.
     * @param amount The amount of currency.
     * @param owner The address of the owner of the currency.
     * @return isValid True if the amount of currency is approved for transfer.
     */
    function _hasApprovedCurrency(address currency, uint256 amount, address owner)
        internal
        view
        returns (bool isValid)
    {
        return IERC20(currency).allowance(owner, address(this)) >= amount;
    }

    /**
     * Checks if a token contract is ERC1155 or ERC721 and if the token is owned and approved for transfer.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param owner The address of the owner of the token.
     * @return isValid True if the token is owned and approved for transfer.
     * @dev Returns false if the token contract is not ERC1155 or ERC721.
     */
    function _hasApprovedTokens(address tokenContract, uint256 tokenId, uint256 quantity, address owner)
        internal
        view
        returns (bool isValid)
    {
        address orderbook = address(this);

        if (_tokenIsERC1155(tokenContract)) {
            return quantity > 0 && IERC1155(tokenContract).balanceOf(owner, tokenId) >= quantity
                && IERC1155(tokenContract).isApprovedForAll(owner, orderbook);
        }
        // ERC721
        address tokenOwner;
        address operator;

        try IERC721(tokenContract).ownerOf(tokenId) returns (address _tokenOwner) {
            tokenOwner = _tokenOwner;

            try IERC721(tokenContract).getApproved(tokenId) returns (address _operator) {
                operator = _operator;
            } catch {} // solhint-disable-line no-empty-blocks
        } catch {} // solhint-disable-line no-empty-blocks

        return quantity == 1 && owner == tokenOwner
            && (operator == orderbook || IERC721(tokenContract).isApprovedForAll(owner, orderbook));
    }
}
