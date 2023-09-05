// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface INiftyswapOrderbookStorage {
    struct Order {
        bool isListing; // True if the order is a listing, false if it is an offer.
        bool isERC1155; // True if the token is an ERC1155 token, false if it is an ERC721 token.
        address creator;
        address tokenContract;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 pricePerToken;
        uint256 expiry;
    }

    enum TokenType {
        UNKNOWN,
        ERC1155,
        ERC721
    }
}

interface INiftyswapOrderbookFunctions is INiftyswapOrderbookStorage {
    /**
     * Lists a token for sale.
     * @param isERC1155 True if the token is an ERC1155 token, false if it is an ERC721 token.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token.
     * @param expiry The timestamp at which the listing expires.
     * @return listingId The ID of the listing.
     */
    function createListing(
        bool isERC1155,
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 listingId);

    /**
     * Offer a price for a token.
     * @param isERC1155 True if the token is an ERC1155 token, false if it is an ERC721 token.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to buy.
     * @param currency The address of the currency to offer for the token.
     * @param pricePerToken The price per token.
     * @param expiry The timestamp at which the offer expires.
     * @return offerId The ID of the offer.
     */
    function createOffer(
        bool isERC1155,
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 offerId);

    /**
     * Purchases a token.
     * @param listingId The ID of the listing.
     * @param quantity The quantity of tokens to purchase.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeReceivers The addresses to send the additional fees to.
     */
    function acceptListing(
        bytes32 listingId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeReceivers
    ) external;

    /**
     * Sells a token.
     * @param offerId The ID of the listing.
     * @param quantity The quantity of tokens to sell.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeReceivers The addresses to send the additional fees to.
     */
    function acceptOffer(
        bytes32 offerId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeReceivers
    ) external;

    /**
     * Cancels a listing.
     * @param listingId The ID of the listing.
     */
    function cancelListing(bytes32 listingId) external;

    /**
     * Cancels an offer.
     * @param offerId The ID of the offer.
     */
    function cancelOffer(bytes32 offerId) external;

    /**
     * Gets an order.
     * @param orderId The ID of the listing or offer.
     * @return order The order.
     */
    function getOrder(bytes32 orderId) external view returns (Order memory order);

    /**
     * Checks if orders are valid.
     * @param orderIds The IDs of the orders.
     * @return valid The validities of the orders.
     * @notice An order is valid if it is active, has not expired and tokens (currency for offers, tokens for listings) are transferrable.
     */
    function isOrderValid(bytes32[] memory orderIds) external view returns (bool[] memory valid);
}

interface INiftyswapOrderbookSignals {
    //
    // Events
    //

    // See INiftyswapOrderbookFunctions.createListing
    event ListingCreated(
        bytes32 indexed listingId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    );

    // See INiftyswapOrderbookFunctions.createOffer
    event OfferCreated(
        bytes32 indexed offerId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    );

    // See INiftyswapOrderbookFunctions.acceptListing
    event ListingAccepted(
        bytes32 indexed listingId, address indexed buyer, address indexed tokenContract, uint256 quantity
    );

    // See INiftyswapOrderbookFunctions.acceptOffer
    event OfferAccepted(
        bytes32 indexed offerId, address indexed buyer, address indexed tokenContract, uint256 quantity
    );

    // See INiftyswapOrderbookFunctions.cancelListing
    event ListingCancelled(bytes32 indexed listingId, address indexed tokenContract);

    // See INiftyswapOrderbookFunctions.cancelOffer
    event OfferCancelled(bytes32 indexed offerId, address indexed tokenContract);

    //
    // Errors
    //

    // Thrown when the token contract is invalid.
    error InvalidTokenContract(address tokenContract);

    // Thrown when the token approval is invalid.
    error InvalidTokenApproval(address tokenContract, uint256 tokenId, uint256 quantity, address owner);

    // Thrown when the token approval is invalid.
    error InvalidCurrencyApproval(address currency, uint256 quantity, address owner);

    // Thrown when order id is invalid for a listing.
    error InvalidListingId(bytes32 listingId);

    // Thrown when order id is invalid for an offer.
    error InvalidOfferId(bytes32 offerId);

    // Thrown when order id is invalid.
    error InvalidOrderId(bytes32 orderId);

    // Thrown when quantity is invalid.
    error InvalidQuantity();

    // Thrown when price is invalid.
    error InvalidPrice();

    // Thrown when expiry is invalid.
    error InvalidExpiry();

    // Thrown when the additional fees are invalid.
    error InvalidAdditionalFees();
}

// solhint-disable-next-line no-empty-blocks
interface INiftyswapOrderbook is INiftyswapOrderbookFunctions, INiftyswapOrderbookSignals {}
