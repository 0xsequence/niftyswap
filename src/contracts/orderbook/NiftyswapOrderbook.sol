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
    // Maximum royalties capped to 25%
    uint256 internal constant MAX_ROYALTY_DIVISOR = 4;

    uint256 public totalListings = 0;
    mapping(uint256 => Listing) internal listings;

    /**
     * Lists a token for sale.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list the token for.
     * @param pricePerToken The price per token. Note this includes royalties.
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
     * @dev Royalties are taken from the listing cost.
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

        // Calculate payables
        uint256 totalCost = listing.pricePerToken * quantity;
        (address royaltyRecipient, uint256 royaltyAmount) =
            getRoyaltyInfo(listing.tokenContract, listing.tokenId, totalCost);
        if (royaltyAmount > 0) {
            // Transfer royalties
            TransferHelper.safeTransferFrom(listing.currency, msg.sender, royaltyRecipient, royaltyAmount);
        }

        // Transfer currency
        TransferHelper.safeTransferFrom(listing.currency, msg.sender, listing.creator, totalCost - royaltyAmount);

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
     * Will return how much of currency need to be paid for the royalty.
     * @notice Royalty is capped at 25% of the total amount of currency
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
            // Cap royalty amount
            uint256 max = cost / MAX_ROYALTY_DIVISOR;
            return (_r, _c > max ? max : _c);
        } catch {}
        return (address(0), 0);
    }

    /**
     * Checks if a token contract supports ERC1155 or ERC721.
     * @param tokenContract The address of the token contract.
     * @dev Throws if the token contract is not ERC20.
     */
    function _getTokenType(address tokenContract) internal view returns (TokenType tokenType) {
        if (_safelyCall165(tokenContract, type(IERC1155).interfaceId)) {
            return TokenType.ERC1155;
        }
        if (_safelyCall165(tokenContract, type(IERC721).interfaceId)) {
            return TokenType.ERC721;
        }
        // Note we can't check for ERC20 this way as most do not support ERC165
        return TokenType.UNKNOWN;
    }

    /**
     * Checks if a token contract supports an interface.
     * @param tokenContract The address of the token contract.
     * @param interfaceId The interface ID.
     * @return supported True if the token contract supports the interface.
     */
    function _safelyCall165(address tokenContract, bytes4 interfaceId) private view returns (bool supported) {
        bytes memory data = abi.encodeWithSelector(IERC165.supportsInterface.selector, interfaceId);
        (bool success, bytes memory returnData) = tokenContract.staticcall(data);
        return success && returnData.length == 32 && abi.decode(returnData, (bool));
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
