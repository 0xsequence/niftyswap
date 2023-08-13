// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapOrderbook} from "../interfaces/INiftyswapOrderbook.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC20} from "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
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
        if (pricePerToken == 0) {
            revert InvalidListing("Invalid price");
        }
        // solhint-disable-next-line not-rely-on-time
        if (expiresAt <= block.timestamp) {
            revert InvalidListing("Invalid expiration");
        }

        // Check currency is ERC20
        _requireERC20(currency);

        // Check valid token for listing
        if (!_hasApprovedTokens(tokenContract, tokenId, quantity, msg.sender)) {
            revert InvalidTokenApproval(tokenContract, tokenId, quantity, msg.sender);
        }

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
        if (_isERC1155(listing.tokenContract)) {
            IERC1155(listing.tokenContract).safeTransferFrom(listing.creator, msg.sender, listing.tokenId, quantity, "");
        } else {
            IERC721(listing.tokenContract).transferFrom(listing.creator, msg.sender, listing.tokenId);
        }
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

    /**
     * Checks if a token contract is ERC1155 or ERC721.
     * @param tokenContract The address of the token contract.
     * @return isERC1155 True if the token contract is ERC1155, false if ERC721.
     * @dev Throws if the token contract is not ERC1155 or ERC721.
     */
    function _isERC1155(address tokenContract) internal view returns (bool isERC1155) {
        try IERC165(tokenContract).supportsInterface(type(IERC1155).interfaceId) returns (bool supported) {
            if (supported) {
                return true;
            }
        } catch {}
        try IERC165(tokenContract).supportsInterface(type(IERC721).interfaceId) returns (bool supported) {
            if (supported) {
                return false;
            }
        } catch {}
        // Fail out
        revert InvalidTokenContract(tokenContract);
    }

    /**
     * Checks if a token contract is ERC20.
     * @param tokenContract The address of the token contract.
     * @dev Throws if the token contract is not ERC20.
     */
    function _requireERC20(address tokenContract) internal view {
        try IERC165(tokenContract).supportsInterface(type(IERC20).interfaceId) returns (bool supported) {
            if (supported) {
                return;
            }
        } catch {}
        // Fail out
        revert InvalidTokenContract(tokenContract);
    }

    function _hasApprovedTokens(address tokenContract, uint256 tokenId, uint256 quantity, address owner)
        internal
        view
        returns (bool isValid)
    {
        address orderbook = address(this);

        if (_isERC1155(tokenContract)) {
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
            } catch {}
        } catch {}

        return quantity == 1 && owner == tokenOwner
            && (operator == orderbook || IERC721(tokenContract).isApprovedForAll(owner, orderbook));
    }
}
