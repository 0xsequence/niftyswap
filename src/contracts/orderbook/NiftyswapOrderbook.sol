// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapOrderbook} from "../interfaces/INiftyswapOrderbook.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract NiftyswapOrderbook is INiftyswapOrderbook {
    uint256 public totalListings = 0;
    mapping(uint256 => Listing) internal listings;

    /**
     * Lists a token for sale.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token.
     * @param expiresAt The timestamp at which the listing expires.
     * @return listingId The ID of the listing.
     * @notice Listings cannot be created for unowned or unapproved tokens.
     */
    function createListing(
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiresAt
    ) external returns (uint256 listingId) {
        if (quantity == 0) {
            revert InvalidListing("Invalid quantity");
        }
        //FIXME Do we allow free listings?
        // if (pricePerToken == 0) {
        //   revert InvalidListing('Invalid price');
        // }
        // solhint-disable-next-line not-rely-on-time
        if (expiresAt <= block.timestamp) {
            revert InvalidListing("Invalid expiration");
        }
        //TODO Check tokenContract type (or pass it in?)
        //TODO Check currency contract is ERC20.
        //TODO Check ownership and approved status of token.

        listings[totalListings] = Listing({
            creator: msg.sender,
            tokenContract: tokenContract,
            tokenId: tokenId,
            quantity: quantity,
            currency: currency,
            pricePerToken: pricePerToken,
            expiresAt: expiresAt
        });

        emit ListingCreated(totalListings, tokenContract, tokenId, quantity, currency, pricePerToken, expiresAt);

        return totalListings++;
    }

    /**
     * Purchases a token.
     * @param listingId The ID of the listing.
     * @param quantity The quantity of tokens to purchase.
     */
    function acceptListing(uint256 listingId, uint256 quantity) external {
        Listing storage listing = listings[listingId];
        if (listing.creator == address(0)) {
            // Cancelled or completed
            revert InvalidListingId(listingId);
        }
        if (quantity == 0 || quantity > listing.quantity) {
            revert InvalidQuantity();
        }

        // Transfer currency
        TransferHelper.safeTransferFrom(listing.currency, msg.sender, listing.creator, listing.pricePerToken * quantity);

        // Transfer token
        //FIXME Don't assume erc1155
        IERC1155(listing.tokenContract).safeTransferFrom(listing.creator, msg.sender, listing.tokenId, quantity, "");

        // Update listing state
        if (listing.quantity == quantity) {
            // Refund some gas
            //FIXME Or do we keep this to track history?
            delete listings[listingId];
        } else {
            listing.quantity -= quantity;
        }

        emit ListingAccepted(listingId, msg.sender, quantity);
    }

    /**
     * Cancels a listing.
     * @param listingId The ID of the listing.
     */
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        if (listing.creator != msg.sender) {
            //FIXME Bad err
            revert InvalidListing("Only the creator can cancel a listing");
        }

        // Refund some gas
        //FIXME Or do we keep this to track history?
        delete listings[listingId];

        emit ListingCancelled(listingId);
    }

    /**
     * Gets a listing.
     * @param listingId The ID of the listing.
     * @return listing The listing.
     */
    function getListing(uint256 listingId) external view returns (Listing memory listing) {
        return listings[listingId];
    }
}
