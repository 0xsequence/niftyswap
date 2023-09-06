// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {INiftyswapOrderbook} from "../interfaces/INiftyswapOrderbook.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC2981} from "../interfaces/IERC2981.sol";
import {IERC20} from "@0xsequence/erc-1155/contracts/interfaces/IERC20.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {TransferHelper} from "@uniswap/lib/contracts/libraries/TransferHelper.sol";

contract NiftyswapOrderbook is INiftyswapOrderbook {
    mapping(bytes32 => Order) internal _orders;

    /**
     * Creates an order.
     * @param isListing True if the token is a listing, false if it is an offer.
     * @param isERC1155 True if the token is an ERC1155 token, false if it is an ERC721 token.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param currency The address of the currency to list.
     * @param pricePerToken The price per token.
     * @param expiry The timestamp at which the order expires.
     * @return orderId The ID of the order.
     * @notice A listing is when the maker is selling tokens for currency.
     * @notice An offer is when the maker is buying tokens with currency.
     */
    function createOrder(
        bool isListing,
        bool isERC1155,
        address tokenContract,
        uint256 tokenId,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    ) external returns (bytes32 orderId) {
        if (isListing) {
            // Check valid token for listing
            if (isListing && !_hasApprovedTokens(isERC1155, tokenContract, tokenId, quantity, msg.sender)) {
                revert InvalidTokenApproval(tokenContract, tokenId, quantity, msg.sender);
            }
        } else {
            // Check approved currency for offer
            uint256 total = quantity * pricePerToken;
            if (!_hasApprovedCurrency(currency, total, msg.sender)) {
                revert InvalidCurrencyApproval(currency, total, msg.sender);
            }
            // Check quantity. Covered by _hasApprovedTokens for listings
            if ((isERC1155 && quantity == 0) || (!isERC1155 && quantity != 1)) {
                revert InvalidQuantity();
            }
        }

        if (pricePerToken == 0) {
            revert InvalidPrice();
        }
        // solhint-disable-next-line not-rely-on-time
        if (expiry <= block.timestamp) {
            revert InvalidExpiry();
        }

        Order memory order = Order({
            isListing: isListing,
            isERC1155: isERC1155,
            creator: msg.sender,
            tokenContract: tokenContract,
            tokenId: tokenId,
            quantity: quantity,
            currency: currency,
            pricePerToken: pricePerToken,
            expiry: expiry
        });
        orderId = hashOrder(order);

        if (_orders[orderId].creator != address(0)) {
            // Collision
            revert InvalidOrderId(orderId);
        }
        _orders[orderId] = order;

        emit OrderCreated(orderId, tokenContract, tokenId, isListing, quantity, currency, pricePerToken, expiry);

        return orderId;
    }

    /**
     * Accepts an order.
     * @param orderId The ID of the order.
     * @param quantity The quantity of tokens to purchase.
     * @param additionalFees The additional fees to pay.
     * @param additionalFeeReceivers The addresses to send the additional fees to.
     */
    function acceptOrder(
        bytes32 orderId,
        uint256 quantity,
        uint256[] memory additionalFees,
        address[] memory additionalFeeReceivers
    ) external {
        Order memory order = _orders[orderId];
        if (order.creator == address(0)) {
            // Order cancelled, completed or never existed
            revert InvalidOrderId(orderId);
        }
        if (quantity == 0 || quantity > order.quantity) {
            revert InvalidQuantity();
        }
        if (_isExpired(order)) {
            revert InvalidExpiry();
        }
        if (additionalFees.length != additionalFeeReceivers.length) {
            revert InvalidAdditionalFees();
        }

        // Update order state
        if (order.quantity == quantity) {
            // Refund some gas
            delete _orders[orderId];
        } else {
            _orders[orderId].quantity -= quantity;
        }
        address tokenContract = order.tokenContract;

        // Calculate payables
        uint256 remainingCost = order.pricePerToken * quantity;
        (address royaltyRecipient, uint256 royaltyAmount) = getRoyaltyInfo(tokenContract, order.tokenId, remainingCost);

        address currencyReceiver = order.isListing ? order.creator : msg.sender;
        address tokenReceiver = order.isListing ? msg.sender : order.creator;

        if (royaltyAmount > 0) {
            // Transfer royalties
            TransferHelper.safeTransferFrom(order.currency, tokenReceiver, royaltyRecipient, royaltyAmount);
            if (order.isListing) {
                // Royalties are paid by the maker. This reduces the cost for listings.
                remainingCost -= royaltyAmount;
            }
        }

        // Transfer additional fees
        for (uint256 i; i < additionalFees.length; i++) {
            uint256 fee = additionalFees[i];
            address feeReceiver = additionalFeeReceivers[i];
            if (feeReceiver == address(0) || fee == 0) {
                revert InvalidAdditionalFees();
            }
            TransferHelper.safeTransferFrom(order.currency, tokenReceiver, feeReceiver, fee);
            if (!order.isListing) {
                // Fees are paid by the taker. This reduces the cost for offers.
                remainingCost -= fee;
            }
        }

        // Transfer currency
        TransferHelper.safeTransferFrom(order.currency, tokenReceiver, currencyReceiver, remainingCost);

        // Transfer token
        if (order.isERC1155) {
            IERC1155(tokenContract).safeTransferFrom(currencyReceiver, tokenReceiver, order.tokenId, quantity, "");
        } else {
            IERC721(tokenContract).transferFrom(currencyReceiver, tokenReceiver, order.tokenId);
        }

        emit OrderAccepted(orderId, msg.sender, tokenContract, quantity);
    }

    /**
     * Cancels an order.
     * @param orderId The ID of the order.
     */
    function cancelOrder(bytes32 orderId) external {
        Order storage order = _orders[orderId];
        if (order.creator != msg.sender) {
            revert InvalidOrderId(orderId);
        }
        address tokenContract = order.tokenContract;

        // Refund some gas
        delete _orders[orderId];

        emit OrderCancelled(orderId, tokenContract);
    }

    /**
     * Deterministically create the orderId for the given order.
     * @param order The order.
     * @return orderId The ID of the order.
     */
    function hashOrder(Order memory order) public pure returns (bytes32 orderId) {
        return keccak256(
            abi.encodePacked(
                order.isListing,
                order.isERC1155,
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
     * @param orderId The ID of the order.
     * @return order The order.
     */
    function getOrder(bytes32 orderId) external view returns (Order memory order) {
        return _orders[orderId];
    }

    /**
     * Gets orders.
     * @param orderIds The IDs of the orders.
     * @return orders The orders.
     */
    function getOrderBatch(bytes32[] memory orderIds) external view returns (Order[] memory orders) {
        orders = new Order[](orderIds.length);
        for (uint256 i; i < orderIds.length; i++) {
            orders[i] = _orders[orderIds[i]];
        }
        return orders;
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
            Order memory order = _orders[orderIds[i]];
            bool isValid = order.creator != address(0) && !_isExpired(order);
            if (isValid) {
                if (order.isListing) {
                    isValid = _hasApprovedTokens(
                        order.isERC1155, order.tokenContract, order.tokenId, order.quantity, order.creator
                    );
                } else {
                    isValid = _hasApprovedCurrency(order.currency, order.pricePerToken * order.quantity, order.creator);
                }
            }
            valid[i] = isValid;
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
     * @return isValid True if the amount of currency is sufficient and approved for transfer.
     */
    function _hasApprovedCurrency(address currency, uint256 amount, address owner)
        internal
        view
        returns (bool isValid)
    {
        return IERC20(currency).balanceOf(owner) >= amount && IERC20(currency).allowance(owner, address(this)) >= amount;
    }

    /**
     * Checks if a token contract is ERC1155 or ERC721 and if the token is owned and approved for transfer.
     * @param isERC1155 True if the token is an ERC1155 token, false if it is an ERC721 token.
     * @param tokenContract The address of the token contract.
     * @param tokenId The ID of the token.
     * @param quantity The quantity of tokens to list.
     * @param owner The address of the owner of the token.
     * @return isValid True if the token is owned and approved for transfer.
     * @dev Returns false if the token contract is not ERC1155 or ERC721.
     */
    function _hasApprovedTokens(bool isERC1155, address tokenContract, uint256 tokenId, uint256 quantity, address owner)
        internal
        view
        returns (bool isValid)
    {
        address orderbook = address(this);

        if (isERC1155) {
            // ERC1155
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
