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
    ) external returns (bytes32 orderId);

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
    ) external;

    /**
     * Cancels an order.
     * @param orderId The ID of the order.
     */
    function cancelOrder(bytes32 orderId) external;

    /**
     * Gets an order.
     * @param orderId The ID of the order.
     * @return order The order.
     */
    function getOrder(bytes32 orderId) external view returns (Order memory order);

    /**
     * Gets orders.
     * @param orderIds The IDs of the orders.
     * @return orders The orders.
     */
    function getOrderBatch(bytes32[] memory orderIds) external view returns (Order[] memory orders);

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

    // See INiftyswapOrderbookFunctions.createOrder
    event OrderCreated(
        bytes32 indexed orderId,
        address indexed tokenContract,
        uint256 indexed tokenId,
        bool isListing,
        uint256 quantity,
        address currency,
        uint256 pricePerToken,
        uint256 expiry
    );

    // See INiftyswapOrderbookFunctions.acceptOrder
    event OrderAccepted(
        bytes32 indexed orderId, address indexed buyer, address indexed tokenContract, uint256 quantity
    );

    // See INiftyswapOrderbookFunctions.cancelOrder
    event OrderCancelled(bytes32 indexed orderId, address indexed tokenContract);

    //
    // Errors
    //

    // Thrown when the token approval is invalid.
    error InvalidTokenApproval(address tokenContract, uint256 tokenId, uint256 quantity, address owner);

    // Thrown when the currency approval is invalid.
    error InvalidCurrencyApproval(address currency, uint256 quantity, address owner);

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
