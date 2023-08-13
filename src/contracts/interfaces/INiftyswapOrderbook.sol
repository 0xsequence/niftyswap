// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

interface INiftyswapOrderbookStorage {
    struct Listing {
        address creator;
        address tokenContract;
        uint256 tokenId;
        uint256 quantity;
        address currency;
        uint256 pricePerToken;
        uint256 expiresAt;
    }
}

interface INiftyswapOrderbookFunctions is INiftyswapOrderbookStorage {
    /**
     * Lists a token for sale.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token.
     * @param expiresAt The timestamp at which the listing expires.
     * @return listingId The ID of the listing.
     */
    function createListing(
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiresAt
    ) external returns (uint256 listingId);

    /**
     * Purchases a token.
     * @param listingId The ID of the listing.
     * @param quantity The quantity of tokens to purchase.
     */
    function acceptListing(uint256 listingId, uint256 quantity) external;

    /**
     * Cancels a listing.
     * @param listingId The ID of the listing.
     */
    function cancelListing(uint256 listingId) external;

    /**
     * Gets a listing.
     * @param listingId The ID of the listing.
     * @return listing The listing.
     */
    function getListing(uint256 listingId) external view returns (Listing memory listing);
}

interface INiftyswapOrderbookSignals {
    //
    // Events
    //

    // See INiftyswapOrderbookFunctions.createListing
    event ListingCreated(
        uint256 indexed listingId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiresAt
    );

    // See INiftyswapOrderbookFunctions.acceptListing
    event ListingAccepted(uint256 indexed listingId, address indexed buyer, uint256 quantity);

    // See INiftyswapOrderbookFunctions.cancelListing
    event ListingCancelled(uint256 indexed listingId);

    //
    // Errors
    //

    // Thrown when the token contract is invalid.
    error InvalidTokenContract(address tokenContract);

    // Thrown when the token approval fails.
    error InvalidTokenApproval(address tokenContract, uint256 tokenId, uint256 quantity, address owner);

    // Thrown when listing creation fails.
    error InvalidListing(string reason);

    // Thrown when listing id is invalid.
    error InvalidListingId(uint256 listingId);

    // Thrown when quantity supplied is invalid.
    error InvalidQuantity();
}

// solhint-disable-next-line no-empty-blocks
interface INiftyswapOrderbook is INiftyswapOrderbookFunctions, INiftyswapOrderbookSignals {}
