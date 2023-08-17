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
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token.
     * @param expiry The timestamp at which the listing expires.
     * @return listingId The ID of the listing.
     */
    function createListing(
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 listingId);

    /**
     * Purchases a token.
     * @param listingId The ID of the listing.
     * @param quantity The quantity of tokens to purchase.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeRecievers The addresses to send the additional fees to.
     */
    function acceptListing(
        bytes32 listingId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeRecievers
    ) external;

    /**
     * Cancels a listing.
     * @param listingId The ID of the listing.
     */
    function cancelListing(bytes32 listingId) external;

    /**
     * Gets a listing.
     * @param listingId The ID of the listing.
     * @return listing The listing.
     */
    function getListing(bytes32 listingId) external view returns (Listing memory listing);

    /**
     * Checks if a listing is valid.
     * @param listingIds The IDs of the listings.
     * @return valid The validities of the listings.
     * @notice A listing is valid if it is active, has not expired and tokens are available for transfer.
     */
    function isListingValid(bytes32[] memory listingIds) external view returns (bool[] memory valid);
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

    // See INiftyswapOrderbookFunctions.acceptListing
    event ListingAccepted(bytes32 indexed listingId, address indexed buyer, uint256 quantity);

    // See INiftyswapOrderbookFunctions.cancelListing
    event ListingCancelled(bytes32 indexed listingId);

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
    error InvalidListingId(bytes32 listingId);

    // Thrown when quantity supplied is invalid.
    error InvalidQuantity();

    // Thrown when the additional fees supplied are invalid.
    error InvalidAdditionalFees();
}

// solhint-disable-next-line no-empty-blocks
interface INiftyswapOrderbook is INiftyswapOrderbookFunctions, INiftyswapOrderbookSignals {}
